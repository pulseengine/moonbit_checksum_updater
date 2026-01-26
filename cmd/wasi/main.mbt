/// MoonBit Checksum Updater CLI Entry Point (WASI Version)
///
/// Uses wit-bindgen generated WASI bindings for stdout output.

/// Entry point for wasi:cli/command
pub fn run() -> Result[Unit, Unit] {
  let stdout = @stdout.get_stdout()

  // Print help for now - argument parsing requires more WASI interfaces
  print_lines(stdout, [
    "MoonBit Checksum Updater v0.1.0",
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
    "    help        Show this help message",
    "",
    "SUPPORTED TOOLS:",
    "    wasm-tools     bytecodealliance/wasm-tools",
    "    wasmtime       bytecodealliance/wasmtime",
    "    wit-bindgen    bytecodealliance/wit-bindgen",
    "    wkg            bytecodealliance/wasm-pkg-tools",
    "    wac            bytecodealliance/wac",
    "    wasi-sdk       WebAssembly/wasi-sdk",
    "    tinygo         tinygo-org/tinygo",
    "",
    "NOTE: Full functionality requires composing with wasi:http/outgoing-handler"
  ])
}

/// Print multiple lines to stdout
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

/// Convert a String to FixedArray[Byte] for WASI streams
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
