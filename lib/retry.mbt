/// Generic retry with exponential backoff.
/// Pure logic — the actual delay is provided by the Sleeper trait.

/// Configuration for retry behavior.
pub(all) struct RetryConfig {
  /// Maximum number of retry attempts (0 = no retries).
  max_retries : Int
  /// Initial delay in milliseconds before first retry.
  initial_delay_ms : Int
  /// Maximum delay in milliseconds (caps exponential growth).
  max_delay_ms : Int
} derive(Show, Eq)

/// Default retry config: 3 retries, 1s initial, 10s max.
pub fn RetryConfig::default() -> RetryConfig {
  { max_retries: 3, initial_delay_ms: 1000, max_delay_ms: 10000 }
}

/// No-retry config for testing or when retries aren't desired.
pub fn RetryConfig::none() -> RetryConfig {
  { max_retries: 0, initial_delay_ms: 0, max_delay_ms: 0 }
}

/// Result of a retry operation, including metadata about attempts.
pub struct RetryOutcome[T] {
  value : T
  attempts : Int
} derive(Show)

/// Compute the delay for a given attempt number using exponential backoff.
/// attempt 0 -> initial_delay_ms
/// attempt 1 -> initial_delay_ms * 2
/// attempt n -> min(initial_delay_ms * 2^n, max_delay_ms)
pub fn compute_delay(config : RetryConfig, attempt : Int) -> Int {
  let mut delay = config.initial_delay_ms
  for i = 0; i < attempt; i = i + 1 {
    delay = delay * 2
    if delay > config.max_delay_ms {
      delay = config.max_delay_ms
      break
    }
  }
  if delay > config.max_delay_ms {
    config.max_delay_ms
  } else {
    delay
  }
}

/// Retry a fallible HTTP operation with exponential backoff.
/// Only retries on errors where `is_retryable` returns true.
/// Non-retryable errors are raised immediately.
pub fn[H : HttpClient, S : Sleeper] fetch_with_retry(
  http : H,
  sleeper : S,
  config : RetryConfig,
  github_repo : String
) -> RetryOutcome[ReleaseInfo] raise {
  let mut attempt = 0
  let mut last_error : ChecksumError = ChecksumError("no attempts made")
  while attempt <= config.max_retries {
    let result : Result[ReleaseInfo, _] = try {
      Ok(fetch_latest_release(http, github_repo))
    } catch {
      e => Err(e)
    }
    match result {
      Ok(info) => return { value: info, attempts: attempt + 1 }
      Err(e) => {
        // Only cast to ChecksumError if it matches
        let checksum_err : ChecksumError = ChecksumError("\{e}")
        if not(is_retryable(checksum_err)) || attempt >= config.max_retries {
          last_error = checksum_err
          break
        }
        // Sleep before retry
        let delay = compute_delay(config, attempt)
        sleeper.sleep_ms(delay)
        attempt += 1
      }
    }
  }
  raise last_error
}

/// Retry wrapper for update_tool that handles rate limiting.
pub fn[H : HttpClient, S : Sleeper] update_tool_with_retry(
  http : H,
  sleeper : S,
  retry_config : RetryConfig,
  info : ToolInfo,
  timestamp : String
) -> (ToolInfo, Bool) raise {
  let mut attempt = 0
  let mut last_error : ChecksumError = ChecksumError("no attempts made")
  while attempt <= retry_config.max_retries {
    let result : Result[(ToolInfo, Bool), _] = try {
      Ok(update_tool(http, info, timestamp))
    } catch {
      e => Err(e)
    }
    match result {
      Ok(pair) => return pair
      Err(e) => {
        let checksum_err : ChecksumError = ChecksumError("\{e}")
        if not(is_retryable(checksum_err)) || attempt >= retry_config.max_retries {
          last_error = checksum_err
          break
        }
        let delay = compute_delay(retry_config, attempt)
        sleeper.sleep_ms(delay)
        attempt += 1
      }
    }
  }
  raise last_error
}
