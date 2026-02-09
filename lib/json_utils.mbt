/// JSON parsing and serialization utilities.

/// Parse a ToolInfo from a JSON string.
pub fn parse_tool_info(json_str : String) -> ToolInfo raise {
  let json = try {
    @json.parse(json_str)
  } catch {
    e => raise json_error("Failed to parse JSON: \{e}")
  }
  try {
    @json.from_json(json)
  } catch {
    e => raise json_error("Failed to decode ToolInfo: \{e}")
  }
}

/// Serialize a ToolInfo to a pretty-printed JSON string.
pub fn tool_info_to_json(info : ToolInfo) -> String {
  info.to_json().stringify(indent=2)
}

/// Load a ToolInfo from a file using the given FileSystem.
pub fn[F : FileSystem] load_tool_info(
  fs : F,
  path : String
) -> ToolInfo raise {
  let content = fs.read_file(path)
  parse_tool_info(content)
}

/// Save a ToolInfo to a file using the given FileSystem.
pub fn[F : FileSystem] save_tool_info(
  fs : F,
  path : String,
  info : ToolInfo
) -> Unit raise {
  let json_str = tool_info_to_json(info)
  fs.write_file(path, json_str + "\n")
}

/// Placeholder timestamp (backends should provide real timestamps).
pub fn placeholder_timestamp() -> String {
  "1970-01-01T00:00:00Z"
}
