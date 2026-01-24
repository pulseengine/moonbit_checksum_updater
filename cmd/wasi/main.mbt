/// MoonBit Checksum Updater CLI Entry Point (WASI Version)
///
/// This file uses wit-bindgen generated WASI bindings for proper
/// stdout/stderr/environment access in WebAssembly components.
///
/// The wasi:cli/command world provides:
/// - @stdout.get_stdout() for stdout stream
/// - @streams.OutputStream for writing

/// The run function is the entry point for wasi:cli/command
/// It's called by the WASI runtime when the component starts
pub fn run() -> Result[Unit, Unit] {
  // Get stdout stream from WASI bindings
  let stdout = @stdout.get_stdout()

  // Print usage information
  let messages = [
    "MoonBit Checksum Updater v0.1.0 (WASI)\n",
    "\n",
    "Usage: checksum_updater <command> [options]\n",
    "\n",
    "Commands:\n",
    "  update-all           Update checksums for all tools\n",
    "  update --tools=<t>   Update specific tools (comma-separated)\n",
    "  validate             Validate existing checksums\n",
    "  list                 List all available tools\n",
    "  help                 Show this help message\n",
  ]

  // Write each message to stdout
  for i = 0; i < messages.length(); i = i + 1 {
    let bytes = string_to_bytes(messages[i])
    match stdout.blocking_write_and_flush(bytes) {
      Ok(_) => ()
      Err(_) => return Err(())
    }
  }

  Ok(())
}

/// Convert a String to FixedArray[Byte] for WASI streams
fn string_to_bytes(s : String) -> FixedArray[Byte] {
  let len = s.length()
  let bytes = FixedArray::make(len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    bytes[i] = s[i].to_int().to_byte()
  }
  bytes
}
