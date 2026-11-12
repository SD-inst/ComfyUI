"""Backfill os.memfd_create for CPython builds compiled against an old glibc sysroot.

The image base (pytorch/pytorch, conda CPython) is built on a sysroot whose glibc
predates memfd_create (glibc 2.27), so CPython's configure records HAVE_MEMFD_CREATE=0
and the attribute is not compiled into the os module at all — even though the runtime
glibc of this image (2.35) exports memfd_create and the kernel supports the syscall.

comfy/anonymous_file.py calls os.memfd_create for the DynamicVRAM writable-model
safetensors staging (comfy/utils.py create_safetensors), which fails with
AttributeError: module 'os' has no attribute 'memfd_create'.

Imported automatically at interpreter startup via PYTHONPATH=/app/shims.
"""

import ctypes
import os
import platform
import sys

# linux/memfd.h
MFD_CLOEXEC = 0o0000001
MFD_ALLOW_SEALING = 0o0000002
MFD_HUGETLB = 0o0000004

# asm-generic numbers, used only if the runtime glibc has no memfd_create wrapper.
_SYS_MEMFD_CREATE = {
    "x86_64": 319,
    "aarch64": 279,
    "armv7l": 385,
    "i686": 356,
    "ppc64le": 360,
    "riscv64": 279,
}


def _install():
    for name, value in (
        ("MFD_CLOEXEC", MFD_CLOEXEC),
        ("MFD_ALLOW_SEALING", MFD_ALLOW_SEALING),
        ("MFD_HUGETLB", MFD_HUGETLB),
    ):
        if not hasattr(os, name):
            setattr(os, name, value)

    if hasattr(os, "memfd_create"):
        return

    libc = ctypes.CDLL(None, use_errno=True)

    wrapper = getattr(libc, "memfd_create", None)  # glibc >= 2.27 exports it
    if wrapper is not None:
        libc.memfd_create.restype = ctypes.c_int
        libc.memfd_create.argtypes = (ctypes.c_char_p, ctypes.c_uint)

        def _call(name_bytes, flags):
            return libc.memfd_create(name_bytes, flags)
    else:
        number = _SYS_MEMFD_CREATE.get(platform.machine())
        if number is None:
            return
        libc.syscall.restype = ctypes.c_long

        def _call(name_bytes, flags):
            return libc.syscall(ctypes.c_long(number), name_bytes, ctypes.c_uint(flags))

    def memfd_create(name, flags=0):
        fd = _call(os.fsencode(name), int(flags))
        if fd < 0:
            err = ctypes.get_errno()
            raise OSError(err, os.strerror(err), name)
        return fd

    os.memfd_create = memfd_create


if sys.platform == "linux":
    try:
        _install()
    except Exception as exc:  # never break interpreter startup
        print("shims/sitecustomize: memfd_create backfill failed: %r" % (exc,), file=sys.stderr)
