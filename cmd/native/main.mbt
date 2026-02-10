/// Native CLI entry point for the MoonBit Checksum Updater.
/// Implements I/O traits using moonbitlang/x/fs for filesystem operations.

/// Native filesystem implementation using @fs.
struct NativeFileSystem {}

impl @lib.FileSystem for NativeFileSystem with read_file(self, path) {
  let _ = self
  try {
    @fs.read_file_to_string(path)
  } catch {
    e => raise @lib.io_error("\{e}")
  }
}

impl @lib.FileSystem for NativeFileSystem with write_file(self, path, content) {
  let _ = self
  try {
    @fs.write_string_to_file(path, content)
  } catch {
    e => raise @lib.io_error("\{e}")
  }
}

impl @lib.FileSystem for NativeFileSystem with list_dir(self, path) {
  let _ = self
  try {
    @fs.read_dir(path)
  } catch {
    e => raise @lib.io_error("\{e}")
  }
}

impl @lib.FileSystem for NativeFileSystem with file_exists(self, path) {
  let _ = self
  @fs.path_exists(path)
}

// ── C FFI declarations ──────────────────────────────────────────────
// Implemented in native_stub.c (linked via moon.pkg.json native-stub).

#borrow(url, headers)
extern "C" fn checksum_http_get_ffi(url : Bytes, headers : Bytes) -> Int = "checksum_http_get"

extern "C" fn checksum_http_get_body_ffi() -> Bytes = "checksum_http_get_body"

extern "C" fn checksum_sleep_ms_ffi(ms : Int) -> Unit = "checksum_sleep_ms"

extern "C" fn checksum_get_gh_token_ffi() -> Bytes = "checksum_get_gh_token"

// ── GitHub token resolution ─────────────────────────────────────────

/// Try to obtain a GitHub API token for authenticated requests (5000 req/hr).
/// Checks GITHUB_TOKEN env var first, then `gh auth token` CLI.
fn get_github_token() -> String {
  match @sys.get_env_var("GITHUB_TOKEN") {
    Some(token) => {
      if token.length() > 0 {
        return token
      }
    }
    None => ()
  }
  let token_bytes = checksum_get_gh_token_ffi()
  if token_bytes.length() == 0 {
    return ""
  }
  let result : Result[String, _] = try {
    Ok(decode_utf8(token_bytes))
  } catch {
    _ => Err(())
  }
  match result {
    Ok(t) => t
    Err(_) => ""
  }
}

// ── Native sleeper via C FFI ────────────────────────────────────────

struct NativeSleeper {}

impl @lib.Sleeper for NativeSleeper with sleep_ms(self, ms) {
  let _ = self
  checksum_sleep_ms_ffi(ms)
}

// ── Native HTTP client via curl FFI ─────────────────────────────────

struct NativeHttpClient {
  token : String
}

/// Inject Authorization header for GitHub API requests if a token is available.
fn inject_auth_header(
  token : String,
  url : String,
  headers : Array[(String, String)]
) -> Array[(String, String)] {
  if token.length() > 0 && url.has_prefix("https://api.github.com/") {
    let result : Array[(String, String)] = []
    for pair in headers {
      result.push(pair)
    }
    result.push(("Authorization", "Bearer \{token}"))
    result
  } else {
    headers
  }
}

/// Build a newline-separated header string for the C FFI.
/// Input: [("Name", "Value"), ...] -> "Name: Value\nName2: Value2\n"
fn build_headers_string(headers : Array[(String, String)]) -> String {
  let buf = StringBuilder::new()
  for pair in headers {
    let (name, value) = pair
    buf.write_string("\{name}: \{value}\n")
  }
  buf.to_string()
}

/// Decode UTF-8 bytes from the C FFI into a MoonBit String.
fn decode_utf8(data : Bytes) -> String raise {
  if data.length() == 0 {
    return ""
  }
  let decoder = @encoding.decoder(UTF8)
  try {
    decoder.decode(data[:])
  } catch {
    e => raise @lib.io_error("UTF-8 decode error: \{e}")
  }
}

impl @lib.HttpClient for NativeHttpClient with get(self, url, headers) {
  let actual_headers = inject_auth_header(self.token, url, headers)
  let (status, body) = do_http_get(url, actual_headers)
  if status < 200 || status >= 300 {
    raise @lib.http_error("HTTP GET failed with status \{status}")
  }
  body
}

impl @lib.HttpClient for NativeHttpClient with get_with_status(
  self,
  url,
  headers
) {
  let actual_headers = inject_auth_header(self.token, url, headers)
  do_http_get(url, actual_headers)
}

/// Shared HTTP GET implementation using C FFI.
fn do_http_get(
  url : String,
  headers : Array[(String, String)]
) -> (Int, String) raise {
  let url_bytes = @encoding.encode(UTF8, url)
  let headers_str = build_headers_string(headers)
  let headers_bytes = @encoding.encode(UTF8, headers_str)
  let status = checksum_http_get_ffi(url_bytes, headers_bytes)
  if status < 0 {
    raise @lib.http_error("HTTP request failed (curl error)")
  }
  let body_bytes = checksum_http_get_body_ffi()
  let body = decode_utf8(body_bytes)
  (status, body)
}

// ── Native SHA256 hasher via moonbitlang/x/crypto ───────────────────

struct NativeSha256Hasher {}

impl @lib.Sha256Hasher for NativeSha256Hasher with sha256(self, data) {
  let _ = self
  let hash = @crypto.sha256(data)
  @crypto.bytes_to_hex_string(hash)
}

/// Create an HTTP client with optional GitHub authentication.
fn make_http_client() -> NativeHttpClient {
  let token = get_github_token()
  if token.length() > 0 {
    println("Using GitHub authentication (5000 req/hr)")
  }
  NativeHttpClient::{ token }
}

/// Parse command-line arguments.
fn parse_args(args : Array[String]) -> (String, Array[String]) {
  if args.length() <= 1 {
    return ("help", [])
  }
  let command = args[1]
  let rest : Array[String] = []
  for i = 2; i < args.length(); i = i + 1 {
    rest.push(args[i])
  }
  (command, rest)
}

/// Main entry point.
fn main {
  let args = @sys.get_cli_args()
  let (command, extra_args) = parse_args(args)
  let fs = NativeFileSystem::{}
  let checksum_dir = if extra_args.length() > 0 {
    extra_args[0]
  } else {
    "example_checksums"
  }
  match command {
    "list" => run_list(fs, checksum_dir)
    "validate" => run_validate(fs, checksum_dir)
    "update-all" => run_update_all(fs, checksum_dir)
    "fill-checksums" => run_fill_checksums(fs, checksum_dir)
    "help" | "--help" | "-h" => print_help()
    "version" | "--version" | "-V" => println("MoonBit Checksum Updater v0.1.0")
    _ => {
      println("Unknown command: \{command}")
      print_help()
    }
  }
}

fn run_list(fs : NativeFileSystem, checksum_dir : String) -> Unit {
  let result : Result[String, _] = try {
    Ok(@lib.list_tools(fs, checksum_dir))
  } catch {
    e => Err(e)
  }
  match result {
    Ok(output) => println(output)
    Err(e) => println("Error: \{e}")
  }
}

fn run_validate(fs : NativeFileSystem, checksum_dir : String) -> Unit {
  let result : Result[String, _] = try {
    Ok(@lib.validate_all_tools(fs, checksum_dir))
  } catch {
    e => Err(e)
  }
  match result {
    Ok(output) => println(output)
    Err(e) => println("Error: \{e}")
  }
}

fn run_update_all(fs : NativeFileSystem, checksum_dir : String) -> Unit {
  let http = make_http_client()
  let sleeper = NativeSleeper::{}
  let config : @lib.UpdateConfig = {
    checksum_dir: checksum_dir,
    tools_filter: [],
    timestamp: @lib.placeholder_timestamp(),
  }
  let retry_config = @lib.RetryConfig::default()
  let result : Result[@lib.UpdateSummary, _] = try {
    Ok(@lib.update_all_tools_with_retry(http, fs, sleeper, config, retry_config))
  } catch {
    e => Err(e)
  }
  match result {
    Ok(summary) => println(@lib.format_summary(summary))
    Err(e) => println("Error: \{e}")
  }
}

fn run_fill_checksums(fs : NativeFileSystem, checksum_dir : String) -> Unit {
  let http = make_http_client()
  let hasher = NativeSha256Hasher::{}
  let files_result : Result[Array[String], _] = try {
    Ok(fs.list_dir(checksum_dir))
  } catch {
    e => Err(e)
  }
  let files = match files_result {
    Ok(f) => f
    Err(e) => {
      println("Error listing directory: \{e}")
      return
    }
  }
  let mut filled = 0
  let mut skipped = 0
  let mut failed = 0
  for file in files {
    if not(file.has_suffix(".json")) {
      continue
    }
    let path = "\{checksum_dir}/\{file}"
    let load_result : Result[@lib.ToolInfo, _] = try {
      Ok(@lib.load_tool_info(fs, path))
    } catch {
      e => Err(e)
    }
    let info = match load_result {
      Ok(i) => i
      Err(e) => {
        println("  [FAILED] \{file}: load error - \{e}")
        failed += 1
        continue
      }
    }
    let version = info.latest_version
    if version == "" {
      println("  [SKIP]   \{info.tool_name}: no latest version")
      skipped += 1
      continue
    }
    if not(info.versions.contains(version)) {
      println("  [SKIP]   \{info.tool_name}: version \{version} not found")
      skipped += 1
      continue
    }
    let version_info = info.versions[version]
    let tag = "v\{version}"
    let updated_vi = @lib.fill_checksums(http, hasher, info.github_repo, tag, version_info)
    info.versions[version] = updated_vi
    let save_result : Result[Unit, _] = try {
      Ok(@lib.save_tool_info(fs, path, info))
    } catch {
      e => Err(e)
    }
    match save_result {
      Ok(_) => {
        println("  [FILLED] \{info.tool_name} v\{version}")
        filled += 1
      }
      Err(e) => {
        println("  [FAILED] \{info.tool_name}: save error - \{e}")
        failed += 1
      }
    }
  }
  println("")
  println("Fill Checksums Summary")
  println("======================")
  println("Filled: \{filled}, Skipped: \{skipped}, Failed: \{failed}")
}

fn print_help() -> Unit {
  println("MoonBit Checksum Updater v0.1.0")
  println("")
  println("A tool for managing and validating checksums of WASM tool binaries.")
  println("")
  println("USAGE:")
  println("    checksum_updater <COMMAND> [CHECKSUM_DIR]")
  println("")
  println("COMMANDS:")
  println("    list             List all configured tools and versions")
  println("    validate         Validate checksum file structure")
  println("    update-all       Update checksums for all tools")
  println("    fill-checksums   Download assets and compute SHA256 checksums")
  println("    help             Show this help message")
  println("    version          Show version information")
  println("")
  println("ARGUMENTS:")
  println("    CHECKSUM_DIR  Directory containing checksum JSON files")
  println("                  (default: example_checksums)")
}
