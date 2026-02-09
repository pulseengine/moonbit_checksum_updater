/// I/O abstraction traits for backend-independent core logic.
///
/// Each backend (native, WASI) implements these traits differently.
/// Core logic is parameterized over these traits, enabling testing
/// with mock implementations.

/// HTTP client for fetching remote resources.
pub(open) trait HttpClient {
  /// Perform an HTTP GET request. Returns the response body as a string.
  /// Headers is a list of (name, value) pairs.
  get(Self, url : String, headers : Array[(String, String)]) -> String raise

  /// Perform an HTTP GET returning both status code and body.
  get_with_status(
    Self,
    url : String,
    headers : Array[(String, String)]
  ) -> (Int, String) raise
}

/// File system abstraction for reading/writing local files.
pub(open) trait FileSystem {
  /// Read a file's contents as a string.
  read_file(Self, path : String) -> String raise

  /// Write a string to a file, creating or overwriting it.
  write_file(Self, path : String, content : String) -> Unit raise

  /// List files in a directory, returning their names.
  list_dir(Self, path : String) -> Array[String] raise

  /// Check if a file exists at the given path.
  file_exists(Self, path : String) -> Bool
}

/// SHA256 hasher for verifying checksums.
pub(open) trait Sha256Hasher {
  /// Compute the SHA256 hash of bytes, returning hex string.
  sha256(Self, data : Bytes) -> String raise
}

/// Sleeper abstraction for retry delays.
/// Each backend provides its own implementation (e.g. native sleep, WASI poll).
pub(open) trait Sleeper {
  /// Sleep for the given number of milliseconds.
  sleep_ms(Self, ms : Int) -> Unit
}
