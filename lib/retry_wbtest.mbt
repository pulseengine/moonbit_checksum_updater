test "compute_delay exponential backoff" {
  let config : RetryConfig = {
    max_retries: 5,
    initial_delay_ms: 1000,
    max_delay_ms: 10000,
  }
  assert_eq(compute_delay(config, 0), 1000)
  assert_eq(compute_delay(config, 1), 2000)
  assert_eq(compute_delay(config, 2), 4000)
  assert_eq(compute_delay(config, 3), 8000)
  // Should cap at max_delay_ms
  assert_eq(compute_delay(config, 4), 10000)
  assert_eq(compute_delay(config, 5), 10000)
}

test "compute_delay respects max" {
  let config : RetryConfig = {
    max_retries: 3,
    initial_delay_ms: 500,
    max_delay_ms: 1500,
  }
  assert_eq(compute_delay(config, 0), 500)
  assert_eq(compute_delay(config, 1), 1000)
  assert_eq(compute_delay(config, 2), 1500) // capped
  assert_eq(compute_delay(config, 3), 1500) // still capped
}

test "RetryConfig::default values" {
  let config = RetryConfig::default()
  assert_eq(config.max_retries, 3)
  assert_eq(config.initial_delay_ms, 1000)
  assert_eq(config.max_delay_ms, 10000)
}

test "RetryConfig::none disables retries" {
  let config = RetryConfig::none()
  assert_eq(config.max_retries, 0)
}
