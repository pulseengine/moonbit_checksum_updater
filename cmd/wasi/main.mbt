/// MoonBit Checksum Updater CLI Entry Point (WASI Version)
///
/// Uses wit-bindgen generated WASI bindings for stdout output.
/// The core logic types are shared with the native backend via @lib,
/// but I/O is done through WASI interfaces.

/// Entry point for wasi:cli/command
pub fn run() -> Result[Unit, Unit] {
  let stdout = @stdout.get_stdout()

  // Get command from WASI environment args
  let args = @environment.get_arguments()
  let command = if args.length() > 0 { args[0] } else { "help" }

  match command {
    "list" => run_list(stdout)
    "validate" => run_validate(stdout)
    "update-all" => run_update_all(stdout)
    "help" | "--help" | "-h" => run_help(stdout)
    "version" | "--version" => write_line(stdout, "MoonBit Checksum Updater v0.1.0 (WASI)")
    _ => {
      let _ = write_line(stdout, "Unknown command: " + command)
      run_help(stdout)
    }
  }
}

/// List all supported tools with their GitHub repos.
fn run_list(stdout : @streams.OutputStream) -> Result[Unit, Unit] {
  print_lines(stdout, [
    "Configured Tools",
    "================",
    "  wasm-tools     bytecodealliance/wasm-tools",
    "  wasmtime       bytecodealliance/wasmtime",
    "  wit-bindgen    bytecodealliance/wit-bindgen",
    "  wkg            bytecodealliance/wasm-pkg-tools",
    "  wac            bytecodealliance/wac",
    "  wasi-sdk       WebAssembly/wasi-sdk",
  ])
}

/// Validate (stub — requires filesystem access).
fn run_validate(stdout : @streams.OutputStream) -> Result[Unit, Unit] {
  print_lines(stdout, [
    "Validation Report",
    "=================",
    "  NOTE: WASI filesystem access required for full validation.",
    "  Use the native backend for local file validation.",
    "",
    "  To validate with the native binary:",
    "    ./checksum_updater validate [CHECKSUM_DIR]",
  ])
}

/// Update all (stub — requires HTTP + filesystem access).
fn run_update_all(stdout : @streams.OutputStream) -> Result[Unit, Unit] {
  print_lines(stdout, [
    "Update All",
    "==========",
    "  NOTE: Requires composing with wasi:http/outgoing-handler.",
    "  Full WASI HTTP support is planned for a future release.",
    "",
    "  For now, use the native backend:",
    "    ./checksum_updater update-all [CHECKSUM_DIR]",
  ])
}

/// Print help message.
fn run_help(stdout : @streams.OutputStream) -> Result[Unit, Unit] {
  print_lines(stdout, [
    "MoonBit Checksum Updater v0.1.0 (WASI)",
    "",
    "A WASM Component for updating tool checksums in rules_wasm_component.",
    "",
    "USAGE:",
    "    wasmtime run checksum_updater.wasm <COMMAND>",
    "",
    "COMMANDS:",
    "    list        List all supported tools",
    "    validate    Validate checksum file structure",
    "    update-all  Update checksums (requires HTTP composition)",
    "    version     Show version information",
    "    help        Show this help message",
    "",
    "NOTE: Full functionality requires composing with wasi:http/outgoing-handler",
  ])
}

/// Write a single line to stdout.
fn write_line(stdout : @streams.OutputStream, line : String) -> Result[Unit, Unit] {
  let bytes = string_to_bytes(line + "\n")
  match stdout.blocking_write_and_flush(bytes) {
    Ok(_) => Ok(())
    Err(_) => Err(())
  }
}

/// Print multiple lines to stdout.
fn print_lines(stdout : @streams.OutputStream, lines : Array[String]) -> Result[Unit, Unit] {
  let mut i = 0
  while i < lines.length() {
    let bytes = string_to_bytes(lines[i] + "\n")
    match stdout.blocking_write_and_flush(bytes) {
      Ok(_) => ()
      Err(_) => return Err(())
    }
    i = i + 1
  }
  Ok(())
}

/// Convert a String to FixedArray[Byte] for WASI streams.
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
