/// Core checksum management logic.
/// Parameterized over I/O traits so it works with any backend.

/// GitHub release asset information (parsed from API JSON).
pub struct ReleaseAsset {
  name : String
  download_url : String
} derive(Show, Eq)

/// GitHub release information (parsed from API JSON).
pub struct ReleaseInfo {
  tag_name : String
  published_at : String
  assets : Array[ReleaseAsset]
} derive(Show, Eq)

/// Default tool configurations mapping tool name to GitHub repo.
pub let default_tools : Array[(String, String)] = [
  ("wasm-tools", "bytecodealliance/wasm-tools"),
  ("wasmtime", "bytecodealliance/wasmtime"),
  ("wit-bindgen", "bytecodealliance/wit-bindgen"),
  ("wkg", "bytecodealliance/wasm-pkg-tools"),
  ("wac", "bytecodealliance/wac"),
  ("wasi-sdk", "WebAssembly/wasi-sdk"),
]

/// Fetch the latest release info from GitHub API.
pub fn[H : HttpClient] fetch_latest_release(
  http : H,
  github_repo : String
) -> ReleaseInfo raise {
  let url = "https://api.github.com/repos/\{github_repo}/releases/latest"
  let headers = [
    ("Accept", "application/vnd.github+json"),
    ("User-Agent", "moonbit-checksum-updater"),
  ]
  let (status, body) = http.get_with_status(url, headers)
  if status == 403 || status == 429 {
    raise rate_limit_error("GitHub API rate limit exceeded")
  }
  if status != 200 {
    raise http_error("GitHub API returned status \{status}")
  }
  parse_release_info(body)
}

/// Parse GitHub release API JSON response into ReleaseInfo.
fn parse_release_info(body : String) -> ReleaseInfo raise {
  let json = try {
    @json.parse(body)
  } catch {
    e => raise json_error("Failed to parse release JSON: \{e}")
  }
  let tag_name = match json {
    { "tag_name": String(s), .. } => s
    _ => raise json_error("Missing tag_name in release")
  }
  let published_at = match json {
    { "published_at": String(s), .. } => s
    _ => ""
  }
  let assets : Array[ReleaseAsset] = []
  match json {
    { "assets": Array(arr), .. } =>
      for item in arr {
        match item {
          { "name": String(name), "browser_download_url": String(url), .. } =>
            assets.push({ name, download_url: url })
          _ => ()
        }
      }
    _ => ()
  }
  { tag_name, published_at, assets }
}

/// Match a release asset name to a platform identifier.
pub fn match_asset_to_platform(asset_name : String) -> String? {
  // Build a lowercase version by iterating chars
  let buf = StringBuilder::new()
  for ch in asset_name {
    let lower = if ch >= 'A' && ch <= 'Z' {
      (ch.to_int() + 32).unsafe_to_char()
    } else {
      ch
    }
    buf.write_char(lower)
  }
  let name = buf.to_string()
  if name.contains("aarch64-macos") || name.contains("arm64-macos") ||
    name.contains("aarch64-apple-darwin") {
    return Some("darwin_arm64")
  }
  if name.contains("x86_64-macos") || name.contains("amd64-macos") ||
    name.contains("x86_64-apple-darwin") {
    return Some("darwin_amd64")
  }
  if name.contains("x86_64-linux") || name.contains("amd64-linux") ||
    name.contains("x86_64-unknown-linux") {
    return Some("linux_amd64")
  }
  if name.contains("aarch64-linux") || name.contains("arm64-linux") ||
    name.contains("aarch64-unknown-linux") {
    return Some("linux_arm64")
  }
  if name.contains("x86_64-windows") || name.contains("amd64-windows") ||
    name.contains("x86_64-pc-windows") {
    return Some("windows_amd64")
  }
  None
}

/// Detect archive type from filename.
pub fn detect_archive_type(filename : String) -> String {
  if filename.has_suffix(".tar.gz") || filename.has_suffix(".tgz") {
    "tar.gz"
  } else if filename.has_suffix(".tar.xz") {
    "tar.xz"
  } else if filename.has_suffix(".zip") {
    "zip"
  } else {
    "unknown"
  }
}

/// Extract tool binary names from an asset filename.
pub fn guess_binaries(tool_name : String) -> Array[String] {
  [tool_name]
}

/// Update a single tool's checksum info by fetching the latest release.
/// Returns the updated ToolInfo and whether it was actually updated.
pub fn[H : HttpClient] update_tool(
  http : H,
  info : ToolInfo,
  timestamp : String
) -> (ToolInfo, Bool) raise {
  let release = fetch_latest_release(http, info.github_repo)
  let new_version = strip_v_prefix(release.tag_name)

  // Check if we already have this version
  if info.versions.contains(new_version) {
    return (info, false)
  }

  // Build platform map from release assets
  let platforms : Map[String, PlatformInfo] = {}
  for asset in release.assets {
    match match_asset_to_platform(asset.name) {
      Some(platform) => {
        let plat_info : PlatformInfo = {
          sha256: "",
          url_suffix: asset.name,
          binaries: guess_binaries(info.tool_name),
          archive_type: detect_archive_type(asset.name),
        }
        platforms[platform] = plat_info
      }
      None => ()
    }
  }

  // Extract release date (just the date part from ISO timestamp)
  let release_date = extract_date_prefix(release.published_at)

  let version_info : VersionInfo = { release_date, platforms }
  let new_versions = info.versions
  new_versions[new_version] = version_info

  let updated_info : ToolInfo = {
    ..info,
    latest_version: new_version,
    last_checked: timestamp,
    versions: new_versions,
  }
  (updated_info, true)
}

/// Compute and fill SHA256 checksums for a version's platform assets.
pub fn[H : HttpClient, S : Sha256Hasher] fill_checksums(
  http : H,
  hasher : S,
  github_repo : String,
  tag : String,
  version_info : VersionInfo
) -> VersionInfo raise {
  let new_platforms : Map[String, PlatformInfo] = {}
  version_info.platforms.each(fn(platform : String, plat_info : PlatformInfo) {
    new_platforms[platform] = plat_info
  })
  let base_url = "https://github.com/\{github_repo}/releases/download/\{tag}"
  let entries : Array[(String, PlatformInfo)] = []
  new_platforms.each(fn(platform : String, plat_info : PlatformInfo) {
    entries.push((platform, plat_info))
  })
  for i = 0; i < entries.length(); i = i + 1 {
    let (platform, plat_info) = entries[i]
    if plat_info.sha256 == "" {
      let url = "\{base_url}/\{plat_info.url_suffix}"
      let body = try {
        http.get(url, [("User-Agent", "moonbit-checksum-updater")])
      } catch {
        _ => {
          continue
        }
      }
      let hash = try {
        hasher.sha256(Bytes::of_string(body))
      } catch {
        _ => {
          continue
        }
      }
      new_platforms[platform] = { ..plat_info, sha256: hash }
    }
  }
  { ..version_info, platforms: new_platforms }
}

/// Extract the first 10 characters (date prefix YYYY-MM-DD) from a timestamp.
fn extract_date_prefix(s : String) -> String {
  if s.length() < 10 {
    return ""
  }
  let buf = StringBuilder::new()
  for i, ch in s {
    if i >= 10 {
      break
    }
    buf.write_char(ch)
  }
  buf.to_string()
}
