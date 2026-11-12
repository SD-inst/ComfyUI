"""Tests for interrupt attribution.

Cancelling a running job raises one process-wide interrupt flag
(``comfy.model_management``). That flag outlives the job it was raised for
whenever the job finishes on its own before any interrupt check consumes it, and
the prompt worker then picks up the next queued item with the flag still set.
The owner recorded next to the flag is what lets the worker tell its own cancel
from that leftover one, through ``interrupt_applies_to``.
"""

import pytest

from comfy.model_management import (
    InterruptProcessingException,
    interrupt_current_processing,
    processing_interrupt_owner,
    processing_interrupted,
    throw_exception_if_processing_interrupted,
)
from comfy_execution.jobs import interrupt_applies_to


@pytest.fixture(autouse=True)
def clear_interrupt_after_test():
    yield
    interrupt_current_processing(False)


# --- the worker's decision -------------------------------------------------

def test_interrupt_of_another_prompt_does_not_apply_to_this_one():
    assert not interrupt_applies_to("bbbbbbbb", "aaaaaaaa")


def test_interrupt_of_this_prompt_applies():
    assert interrupt_applies_to("aaaaaaaa", "aaaaaaaa")


def test_interrupt_without_an_owner_applies_to_whatever_runs():
    # The plain /interrupt endpoint names no prompt; it asks to stop the job
    # that is running, including one parked waiting for the service slot.
    assert interrupt_applies_to("aaaaaaaa", None)


# --- the owner travels with the flag --------------------------------------

def test_owner_is_recorded_with_the_flag():
    interrupt_current_processing(True, prompt_id="aaaaaaaa")
    assert processing_interrupted()
    assert processing_interrupt_owner() == "aaaaaaaa"


def test_clearing_the_flag_clears_the_owner():
    interrupt_current_processing(True, prompt_id="aaaaaaaa")
    interrupt_current_processing(False)
    assert not processing_interrupted()
    assert processing_interrupt_owner() is None


def test_unattributed_interrupt_names_no_owner():
    interrupt_current_processing(True)
    assert processing_interrupted()
    assert processing_interrupt_owner() is None


def test_consuming_the_interrupt_consumes_the_owner():
    interrupt_current_processing(True, prompt_id="aaaaaaaa")
    with pytest.raises(InterruptProcessingException):
        throw_exception_if_processing_interrupted()
    assert not processing_interrupted()
    assert processing_interrupt_owner() is None
