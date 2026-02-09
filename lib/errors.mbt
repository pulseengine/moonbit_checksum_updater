/// Error handling for the checksum updater.

/// Primary error type for checksum operations.
pub suberror ChecksumError {
  ChecksumError(String)
}

/// Create a ChecksumError for HTTP failures.
pub fn http_error(msg : String) -> ChecksumError {
  ChecksumError("HTTP: \{msg}")
}

/// Create a ChecksumError for file I/O failures.
pub fn io_error(msg : String) -> ChecksumError {
  ChecksumError("IO: \{msg}")
}

/// Create a ChecksumError for JSON parse failures.
pub fn json_error(msg : String) -> ChecksumError {
  ChecksumError("JSON: \{msg}")
}

/// Create a ChecksumError for validation failures.
pub fn validation_error(msg : String) -> ChecksumError {
  ChecksumError("Validation: \{msg}")
}

/// Create a ChecksumError for rate limiting.
pub fn rate_limit_error(msg : String) -> ChecksumError {
  ChecksumError("RateLimit: \{msg}")
}

/// Check if an error is retryable (rate limits, transient HTTP errors).
pub fn is_retryable(err : ChecksumError) -> Bool {
  let ChecksumError(msg) = err
  msg.has_prefix("RateLimit:") || msg.has_prefix("HTTP:")
}
