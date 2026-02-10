/// MoonBit Checksum Updater CLI (WASI Component)
///
/// A self-contained WASI component that implements the checksum updater CLI.
/// Uses wit-bindgen generated WASI bindings for I/O.
///
/// Available WASI interfaces: stdout, environment, streams.
/// Filesystem and HTTP require rule enhancements (see README).

// ── Default tool configurations ─────────────────────────────────────
// Duplicated from lib/ since moonbit_wasm_cli doesn't support deps yet.

let default_tools : Array[(String, String)] = [
  ("wasm-tools", "bytecodealliance/wasm-tools"),
  ("wasmtime", "bytecodealliance/wasmtime"),
  ("wit-bindgen", "bytecodealliance/wit-bindgen"),
  ("wkg", "bytecodealliance/wasm-pkg-tools"),
  ("wac", "bytecodealliance/wac"),
  ("wasi-sdk", "WebAssembly/wasi-sdk"),
]

let supported_platforms : Array[String] = [
  "darwin_arm64", "darwin_amd64", "linux_amd64", "linux_arm64", "windows_amd64",
]

let version : String = "0.1.0"

// ── Entry point ─────────────────────────────────────────────────────

/// Entry point for wasi:cli/command.
pub fn run() -> Result[Unit, Unit] {
  let stdout = @stdout.get_stdout()
  let args = @environment.get_arguments()
  let command = if args.length() > 0 { args[0] } else { "help" }
  let checksum_dir = if args.length() > 1 { args[1] } else { "example_checksums" }
  match command {
    "list" => run_list(stdout)
    "validate" => run_validate(stdout, checksum_dir)
    "update-all" => run_update_all(stdout, checksum_dir)
    "fill-checksums" => run_fill_checksums(stdout, checksum_dir)
    "help" | "--help" | "-h" => run_help(stdout)
    "version" | "--version" | "-V" =>
      write_line(stdout, "MoonBit Checksum Updater v\{version} (WASI)")
    _ => {
      let _ = write_line(stdout, "Unknown command: \{command}")
      run_help(stdout)
    }
  }
}

// ── Commands ────────────────────────────────────────────────────────

/// List all configured tools with their GitHub repos.
fn run_list(stdout : @streams.OutputStream) -> Result[Unit, Unit] {
  let _ = write_line(stdout, "Configured Tools")
  let _ = write_line(stdout, "================")
  for pair in default_tools {
    let (name, repo) = pair
    let _ = write_line(stdout, "  \{name}  \{repo}")
  }
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "Supported Platforms")
  let _ = write_line(stdout, "===================")
  for plat in supported_platforms {
    let _ = write_line(stdout, "  \{plat}")
  }
  Ok(())
}

/// Validate checksum files (requires WASI filesystem access).
fn run_validate(
  stdout : @streams.OutputStream,
  checksum_dir : String
) -> Result[Unit, Unit] {
  let env = @environment.get_environment()
  let has_token = has_env_var(env, "GITHUB_TOKEN")
  let _ = write_line(stdout, "Validation Report")
  let _ = write_line(stdout, "=================")
  let _ = write_line(stdout, "  Checksum directory: \{checksum_dir}")
  let _ = write_line(
    stdout,
    "  GitHub token: " + (if has_token { "available" } else { "not set" }),
  )
  let _ = write_line(stdout, "")
  let _ = write_line(
    stdout,
    "  NOTE: Filesystem access requires composing with wasi:filesystem.",
  )
  let _ = write_line(stdout, "  Run with: wasmtime run --dir=. component.wasm validate")
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "  For full validation, use the native backend:")
  write_line(stdout, "    ./checksum_updater validate \{checksum_dir}")
}

/// Update all tools (requires HTTP + filesystem).
fn run_update_all(
  stdout : @streams.OutputStream,
  checksum_dir : String
) -> Result[Unit, Unit] {
  let _ = write_line(stdout, "Update All Tools")
  let _ = write_line(stdout, "================")
  let _ = write_line(stdout, "  Checksum directory: \{checksum_dir}")
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "  Tools to update:")
  for pair in default_tools {
    let (name, repo) = pair
    let _ = write_line(stdout, "    - \{name} (\{repo})")
  }
  let _ = write_line(stdout, "")
  let _ = write_line(
    stdout,
    "  NOTE: Requires composing with wasi:http/outgoing-handler.",
  )
  let _ = write_line(stdout, "  WASI HTTP is not part of wasi:cli/command world.")
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "  For now, use the native backend:")
  write_line(stdout, "    ./checksum_updater update-all \{checksum_dir}")
}

/// Fill checksums (requires HTTP + filesystem).
fn run_fill_checksums(
  stdout : @streams.OutputStream,
  checksum_dir : String
) -> Result[Unit, Unit] {
  let _ = write_line(stdout, "Fill Checksums")
  let _ = write_line(stdout, "==============")
  let _ = write_line(stdout, "  Checksum directory: \{checksum_dir}")
  let _ = write_line(stdout, "")
  let _ = write_line(
    stdout,
    "  NOTE: Requires composing with wasi:http/outgoing-handler.",
  )
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "  For now, use the native backend:")
  write_line(stdout, "    ./checksum_updater fill-checksums \{checksum_dir}")
}

/// Print help message.
fn run_help(stdout : @streams.OutputStream) -> Result[Unit, Unit] {
  let _ = write_line(
    stdout,
    "MoonBit Checksum Updater v\{version} (WASI Component)",
  )
  let _ = write_line(stdout, "")
  let _ = write_line(
    stdout,
    "A WASM Component for managing checksums of tool binaries.",
  )
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "USAGE:")
  let _ = write_line(
    stdout,
    "    wasmtime run checksum_updater.wasm <COMMAND> [CHECKSUM_DIR]",
  )
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "COMMANDS:")
  let _ = write_line(
    stdout,
    "    list             List all configured tools and platforms",
  )
  let _ = write_line(
    stdout,
    "    validate         Validate checksum file structure",
  )
  let _ = write_line(
    stdout,
    "    update-all       Update checksums for all tools",
  )
  let _ = write_line(
    stdout,
    "    fill-checksums   Download assets and compute SHA256 checksums",
  )
  let _ = write_line(
    stdout,
    "    help             Show this help message",
  )
  let _ = write_line(
    stdout,
    "    version          Show version information",
  )
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "ARGUMENTS:")
  let _ = write_line(
    stdout,
    "    CHECKSUM_DIR  Directory containing checksum JSON files",
  )
  let _ = write_line(
    stdout,
    "                  (default: example_checksums)",
  )
  let _ = write_line(stdout, "")
  let _ = write_line(stdout, "CAPABILITIES:")
  let _ = write_line(stdout, "    list, help, version    Fully functional")
  let _ = write_line(
    stdout,
    "    validate               Requires wasi:filesystem (--dir=.)",
  )
  let _ = write_line(
    stdout,
    "    update-all, fill       Requires wasi:http composition",
  )
  Ok(())
}

// ── Helpers ─────────────────────────────────────────────────────────

/// Check if an environment variable is set.
fn has_env_var(
  env : Array[(String, String)],
  key : String
) -> Bool {
  for pair in env {
    let (k, _) = pair
    if k == key {
      return true
    }
  }
  false
}

/// Write a single line to stdout.
fn write_line(
  stdout : @streams.OutputStream,
  line : String
) -> Result[Unit, Unit] {
  let bytes = string_to_bytes(line + "\n")
  match stdout.blocking_write_and_flush(bytes) {
    Ok(_) => Ok(())
    Err(_) => Err(())
  }
}

/// Convert a String to FixedArray[Byte] for WASI streams.
/// Uses simple ASCII encoding (sufficient for CLI output).
fn string_to_bytes(s : String) -> FixedArray[Byte] {
  let len = s.length()
  let bytes = FixedArray::make(len, b'\x00')
  let mut i = 0
  while i < len {
    bytes[i] = s[i].to_int().to_byte()
    i = i + 1
  }
  bytes
}
