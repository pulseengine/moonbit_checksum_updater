/// Multi-tool update orchestration and result formatting.

/// Configuration for an update run.
pub(all) struct UpdateConfig {
  checksum_dir : String
  tools_filter : Array[String]
  timestamp : String
} derive(Show, Eq)

/// Update all tools found in the checksum directory.
pub fn[H : HttpClient, F : FileSystem] update_all_tools(
  http : H,
  fs : F,
  config : UpdateConfig
) -> UpdateSummary raise {
  let files = fs.list_dir(config.checksum_dir)
  let results : Array[ToolUpdateResult] = []
  let mut updated = 0
  let mut failed = 0
  let mut up_to_date = 0

  for file in files {
    if not(file.has_suffix(".json")) {
      continue
    }
    let path = "\{config.checksum_dir}/\{file}"
    let info = try {
      load_tool_info(fs, path)
    } catch {
      e => {
        let tool = strip_json_extension(file)
        results.push(Failed(tool, "Load failed: \{e}"))
        failed += 1
        continue
      }
    }

    // Apply filter
    if not(config.tools_filter.is_empty()) &&
      not(config.tools_filter.contains(info.tool_name)) {
      continue
    }

    // Try to update
    let update_result : Result[(ToolInfo, Bool), _] = try {
      Ok(update_tool(http, info, config.timestamp))
    } catch {
      e => Err(e)
    }
    match update_result {
      Ok((new_info, was_updated)) =>
        if was_updated {
          try {
            save_tool_info(fs, path, new_info)
          } catch {
            e => {
              results.push(Failed(info.tool_name, "Save failed: \{e}"))
              failed += 1
              continue
            }
          }
          results.push(
            Updated(
              info.tool_name,
              info.latest_version,
              new_info.latest_version,
            ),
          )
          updated += 1
        } else {
          results.push(AlreadyUpToDate(info.tool_name, info.latest_version))
          up_to_date += 1
        }
      Err(e) => {
        results.push(Failed(info.tool_name, "\{e}"))
        failed += 1
      }
    }
  }

  { results, total: results.length(), updated, failed, up_to_date }
}

/// Update all tools with retry support for rate-limited GitHub API calls.
pub fn[H : HttpClient, F : FileSystem, S : Sleeper] update_all_tools_with_retry(
  http : H,
  fs : F,
  sleeper : S,
  config : UpdateConfig,
  retry_config : RetryConfig
) -> UpdateSummary raise {
  let files = fs.list_dir(config.checksum_dir)
  let results : Array[ToolUpdateResult] = []
  let mut updated = 0
  let mut failed = 0
  let mut up_to_date = 0

  for file in files {
    if not(file.has_suffix(".json")) {
      continue
    }
    let path = "\{config.checksum_dir}/\{file}"
    let info = try {
      load_tool_info(fs, path)
    } catch {
      e => {
        let tool = strip_json_extension(file)
        results.push(Failed(tool, "Load failed: \{e}"))
        failed += 1
        continue
      }
    }

    if not(config.tools_filter.is_empty()) &&
      not(config.tools_filter.contains(info.tool_name)) {
      continue
    }

    let update_result : Result[(ToolInfo, Bool), _] = try {
      Ok(update_tool_with_retry(http, sleeper, retry_config, info, config.timestamp))
    } catch {
      e => Err(e)
    }
    match update_result {
      Ok((new_info, was_updated)) =>
        if was_updated {
          try {
            save_tool_info(fs, path, new_info)
          } catch {
            e => {
              results.push(Failed(info.tool_name, "Save failed: \{e}"))
              failed += 1
              continue
            }
          }
          results.push(
            Updated(
              info.tool_name,
              info.latest_version,
              new_info.latest_version,
            ),
          )
          updated += 1
        } else {
          results.push(AlreadyUpToDate(info.tool_name, info.latest_version))
          up_to_date += 1
        }
      Err(e) => {
        results.push(Failed(info.tool_name, "\{e}"))
        failed += 1
      }
    }
  }

  { results, total: results.length(), updated, failed, up_to_date }
}

/// Format an UpdateSummary as a human-readable report.
pub fn format_summary(summary : UpdateSummary) -> String {
  let buf = StringBuilder::new()
  buf.write_string("Checksum Update Summary\n")
  buf.write_string("=======================\n")
  buf.write_string("Total: \{summary.total}, Updated: \{summary.updated}, ")
  buf.write_string("Up-to-date: \{summary.up_to_date}, Failed: \{summary.failed}\n\n")

  for result in summary.results {
    match result {
      Updated(tool_name, old_version, new_version) =>
        buf.write_string(
          "  [UPDATED] \{tool_name}: \{old_version} -> \{new_version}\n",
        )
      AlreadyUpToDate(tool_name, version) =>
        buf.write_string("  [OK]      \{tool_name}: \{version} (up to date)\n")
      Failed(tool_name, error) =>
        buf.write_string("  [FAILED]  \{tool_name}: \{error}\n")
    }
  }
  buf.to_string()
}

/// List all configured tools with their current versions.
pub fn[F : FileSystem] list_tools(
  fs : F,
  checksum_dir : String
) -> String raise {
  let buf = StringBuilder::new()
  buf.write_string("Configured Tools\n")
  buf.write_string("================\n")

  let files = fs.list_dir(checksum_dir)
  let mut found = false
  for file in files {
    if not(file.has_suffix(".json")) {
      continue
    }
    let path = "\{checksum_dir}/\{file}"
    let load_result : Result[ToolInfo, _] = try {
      Ok(load_tool_info(fs, path))
    } catch {
      e => Err(e)
    }
    match load_result {
      Ok(info) => {
        buf.write_string(
          "  \{info.tool_name} v\{info.latest_version} (\{info.github_repo})\n",
        )
        found = true
      }
      Err(_) => {
        buf.write_string("  \{file}: (failed to load)\n")
        found = true
      }
    }
  }
  if not(found) {
    buf.write_string("  (no checksum files found)\n")
  }
  buf.to_string()
}

/// Validate all tools in a directory and return a formatted report.
pub fn[F : FileSystem] validate_all_tools(
  fs : F,
  checksum_dir : String
) -> String raise {
  let buf = StringBuilder::new()
  buf.write_string("Validation Report\n")
  buf.write_string("=================\n")

  let files = fs.list_dir(checksum_dir)
  let mut total_errors = 0
  let mut total_warnings = 0

  for file in files {
    if not(file.has_suffix(".json")) {
      continue
    }
    let path = "\{checksum_dir}/\{file}"
    let load_result : Result[ToolInfo, _] = try {
      Ok(load_tool_info(fs, path))
    } catch {
      e => Err(e)
    }
    match load_result {
      Ok(info) => {
        let issues = validate_tool_info(info)
        if issues.is_empty() {
          buf.write_string("  \{info.tool_name}: OK\n")
        } else {
          buf.write_string("  \{info.tool_name}:\n")
          for issue in issues {
            buf.write_string("    [\{issue.severity}] \{issue.message}\n")
            if issue.severity == "error" {
              total_errors += 1
            } else {
              total_warnings += 1
            }
          }
        }
      }
      Err(e) => {
        buf.write_string("  \{file}: FAILED to load - \{e}\n")
        total_errors += 1
      }
    }
  }

  buf.write_string(
    "\nTotal: \{total_errors} errors, \{total_warnings} warnings\n",
  )
  buf.to_string()
}

/// Strip the ".json" extension from a filename.
fn strip_json_extension(filename : String) -> String {
  if filename.has_suffix(".json") {
    let buf = StringBuilder::new()
    let stop = filename.length() - 5
    for i, ch in filename {
      if i >= stop {
        break
      }
      buf.write_char(ch)
    }
    buf.to_string()
  } else {
    filename
  }
}
