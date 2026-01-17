"""
Property test for retry logic

Task 7.3: Property 9 - Retry Logic Handles Transient Failures
Validates: Requirements 23.2
"""

import pytest
from hypothesis import given, strategies as st, settings
from unittest.mock import Mock, patch, call
import time
from datetime import datetime


class TransientError(Exception):
    """Simulates a transient error"""
    pass


class PermanentError(Exception):
    """Simulates a permanent error"""
    pass


def retry_with_backoff(func, max_retries=3, initial_delay=1, backoff_factor=2):
    """
    Retry a function with exponential backoff
    
    Args:
        func: Function to retry
        max_retries: Maximum number of retry attempts
        initial_delay: Initial delay in seconds
        backoff_factor: Multiplier for delay on each retry
        
    Returns:
        Result of the function
        
    Raises:
        Exception if all retries are exhausted
    """
    attempt = 0
    delay = initial_delay
    
    while attempt < max_retries:
        try:
            return func()
        except TransientError as e:
            attempt += 1
            if attempt >= max_retries:
                raise
            
            # Exponential backoff
            time.sleep(delay)
            delay *= backoff_factor
        except PermanentError:
            # Don't retry permanent errors
            raise


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.integers(min_value=1, max_value=5),  # Number of failures before success
    st.integers(min_value=3, max_value=10)  # Max retries
)
@settings(max_examples=100)
def test_retry_succeeds_after_transient_failures(failures_before_success, max_retries):
    """
    Property: For any operation that encounters transient failures,
    the system must automatically retry and eventually succeed if
    the failure is resolved within the retry limit.
    """
    call_count = [0]
    
    def flaky_operation():
        call_count[0] += 1
        if call_count[0] <= failures_before_success:
            raise TransientError(f"Transient failure {call_count[0]}")
        return "success"
    
    if failures_before_success < max_retries:
        # Should succeed after retries
        result = retry_with_backoff(flaky_operation, max_retries=max_retries, initial_delay=0.001)
        assert result == "success", "Should succeed after transient failures"
        assert call_count[0] == failures_before_success + 1, \
            f"Should have called function {failures_before_success + 1} times"
    else:
        # Should fail after exhausting retries
        with pytest.raises(TransientError):
            retry_with_backoff(flaky_operation, max_retries=max_retries, initial_delay=0.001)
        assert call_count[0] == max_retries, \
            f"Should have attempted {max_retries} times"


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.integers(min_value=1, max_value=5)  # Max retries
)
@settings(max_examples=100)
def test_retry_does_not_retry_permanent_errors(max_retries):
    """
    Property: Permanent errors should not be retried - the system
    should fail immediately without wasting retry attempts.
    """
    call_count = [0]
    
    def operation_with_permanent_error():
        call_count[0] += 1
        raise PermanentError("Permanent failure")
    
    # Should fail immediately without retries
    with pytest.raises(PermanentError):
        retry_with_backoff(operation_with_permanent_error, max_retries=max_retries, initial_delay=0.001)
    
    # Should have been called only once (no retries)
    assert call_count[0] == 1, \
        "Permanent errors should not be retried"


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.integers(min_value=2, max_value=5),  # Max retries
    st.floats(min_value=0.001, max_value=0.1),  # Initial delay
    st.integers(min_value=2, max_value=4)  # Backoff factor
)
@settings(max_examples=100)
def test_retry_uses_exponential_backoff(max_retries, initial_delay, backoff_factor):
    """
    Property: Retry logic must use exponential backoff to avoid
    overwhelming the system during transient failures.
    """
    call_times = []
    
    def failing_operation():
        call_times.append(time.time())
        raise TransientError("Transient failure")
    
    # Should fail after all retries
    with pytest.raises(TransientError):
        retry_with_backoff(
            failing_operation,
            max_retries=max_retries,
            initial_delay=initial_delay,
            backoff_factor=backoff_factor
        )
    
    # Verify exponential backoff between attempts
    if len(call_times) >= 2:
        for i in range(1, len(call_times)):
            delay = call_times[i] - call_times[i-1]
            expected_delay = initial_delay * (backoff_factor ** (i-1))
            
            # Allow 50% tolerance for timing variations
            assert delay >= expected_delay * 0.5, \
                f"Delay between attempts should follow exponential backoff. " \
                f"Expected ~{expected_delay}s, got {delay}s"


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.integers(min_value=1, max_value=10)  # Max retries
)
@settings(max_examples=100)
def test_retry_respects_max_attempts(max_retries):
    """
    Property: Retry logic must respect the maximum retry count and
    not exceed it, even if failures continue.
    """
    call_count = [0]
    
    def always_failing_operation():
        call_count[0] += 1
        raise TransientError("Always fails")
    
    # Should fail after max_retries attempts
    with pytest.raises(TransientError):
        retry_with_backoff(always_failing_operation, max_retries=max_retries, initial_delay=0.001)
    
    # Should have attempted exactly max_retries times
    assert call_count[0] == max_retries, \
        f"Should have attempted exactly {max_retries} times, got {call_count[0]}"


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.integers(min_value=1, max_value=5)  # Max retries
)
@settings(max_examples=100)
def test_retry_returns_result_on_first_success(max_retries):
    """
    Property: If an operation succeeds on the first attempt,
    retry logic should return immediately without any retries.
    """
    call_count = [0]
    
    def successful_operation():
        call_count[0] += 1
        return "success"
    
    result = retry_with_backoff(successful_operation, max_retries=max_retries, initial_delay=0.001)
    
    assert result == "success", "Should return success result"
    assert call_count[0] == 1, "Should have called function only once"


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.lists(
        st.booleans(),  # True = success, False = transient failure
        min_size=1,
        max_size=10
    )
)
@settings(max_examples=100)
def test_retry_handles_intermittent_failures(outcomes):
    """
    Property: Retry logic should handle intermittent failures
    (success, failure, success pattern) correctly.
    """
    call_count = [0]
    
    def intermittent_operation():
        if call_count[0] >= len(outcomes):
            return "success"
        
        outcome = outcomes[call_count[0]]
        call_count[0] += 1
        
        if outcome:
            return "success"
        else:
            raise TransientError("Intermittent failure")
    
    max_retries = len(outcomes) + 1
    
    try:
        result = retry_with_backoff(intermittent_operation, max_retries=max_retries, initial_delay=0.001)
        
        # If we got a result, verify it's success
        assert result == "success", "Should return success when operation succeeds"
        
        # Verify we succeeded at some point in the outcomes
        assert any(outcomes[:call_count[0]]), \
            "Should have succeeded at some point in the outcomes"
    
    except TransientError:
        # If we failed, verify all outcomes were failures
        assert not any(outcomes), \
            "Should only fail if all outcomes were failures"


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.integers(min_value=1, max_value=3),  # Failures before success
    st.integers(min_value=3, max_value=5)   # Max retries
)
@settings(max_examples=100)
def test_retry_preserves_operation_result(failures_before_success, max_retries):
    """
    Property: When an operation succeeds after retries, the result
    must be preserved and returned correctly.
    """
    call_count = [0]
    expected_result = {"status": "success", "data": [1, 2, 3]}
    
    def operation_returning_complex_result():
        call_count[0] += 1
        if call_count[0] <= failures_before_success:
            raise TransientError("Transient failure")
        return expected_result
    
    if failures_before_success < max_retries:
        result = retry_with_backoff(operation_returning_complex_result, max_retries=max_retries, initial_delay=0.001)
        
        # Verify result is preserved correctly
        assert result == expected_result, \
            "Result should be preserved after retries"
        assert result is expected_result, \
            "Result should be the exact same object (not a copy)"


# Feature: ecommerce-ai-platform, Property 9: Retry Logic Handles Transient Failures
@given(
    st.integers(min_value=1, max_value=5)  # Max retries
)
@settings(max_examples=100)
def test_retry_propagates_final_error(max_retries):
    """
    Property: When all retries are exhausted, the final error
    must be propagated to the caller with full context.
    """
    call_count = [0]
    
    def always_failing_operation():
        call_count[0] += 1
        raise TransientError(f"Failure attempt {call_count[0]}")
    
    # Should raise the final error
    with pytest.raises(TransientError) as exc_info:
        retry_with_backoff(always_failing_operation, max_retries=max_retries, initial_delay=0.001)
    
    # Verify error message contains information about the final attempt
    assert f"Failure attempt {max_retries}" in str(exc_info.value), \
        "Final error should contain information about the last attempt"
