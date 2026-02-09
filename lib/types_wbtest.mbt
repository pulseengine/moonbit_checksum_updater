test "ToolInfo::empty creates valid structure" {
  let info = ToolInfo::empty("wasm-tools", "bytecodealliance/wasm-tools")
  assert_eq(info.tool_name, "wasm-tools")
  assert_eq(info.github_repo, "bytecodealliance/wasm-tools")
  assert_eq(info.latest_version, "")
  assert_eq(info.build_type, "binary")
  assert_eq(info.versions.size(), 0)
  assert_eq(info.supported_platforms.length(), 5)
}

test "ToolInfo JSON round-trip" {
  let info : ToolInfo = {
    tool_name: "test-tool",
    github_repo: "owner/repo",
    latest_version: "1.0.0",
    last_checked: "2026-01-01T00:00:00Z",
    build_type: "binary",
    versions: {
      "1.0.0": {
        release_date: "2026-01-01",
        platforms: {
          "linux_amd64": {
            sha256: "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
            url_suffix: "x86_64-linux.tar.gz",
            binaries: ["test-tool"],
            archive_type: "tar.gz",
          },
        },
      },
    },
    supported_platforms: ["linux_amd64"],
  }
  let json_str = tool_info_to_json(info)
  let parsed = parse_tool_info(json_str)
  assert_eq(parsed.tool_name, "test-tool")
  assert_eq(parsed.latest_version, "1.0.0")
  // Map[] returns the value directly; check version exists via contains
  assert_true(parsed.versions.contains("1.0.0"))
  let v = parsed.versions["1.0.0"]
  assert_true(v.platforms.contains("linux_amd64"))
  let plat = v.platforms["linux_amd64"]
  assert_eq(plat.archive_type, "tar.gz")
}

test "PlatformInfo JSON round-trip" {
  let plat : PlatformInfo = {
    sha256: "a".repeat(64),
    url_suffix: "test.tar.gz",
    binaries: ["bin1", "bin2"],
    archive_type: "tar.gz",
  }
  let json = plat.to_json()
  let parsed : PlatformInfo = @json.from_json(json)
  assert_eq(parsed, plat)
}

test "version comparison" {
  assert_true(is_newer_version("1.0.0", "1.0.1"))
  assert_true(is_newer_version("1.0.0", "1.1.0"))
  assert_true(is_newer_version("1.0.0", "2.0.0"))
  assert_true(not(is_newer_version("1.0.1", "1.0.0")))
  assert_true(not(is_newer_version("1.0.0", "1.0.0")))
}

test "semver parsing" {
  assert_eq(parse_semver("1.2.3"), Some((1, 2, 3)))
  assert_eq(parse_semver("v1.2.3"), Some((1, 2, 3)))
  assert_eq(parse_semver("invalid"), None)
  assert_eq(parse_semver("1.2"), None)
  assert_eq(parse_semver("1.2.3.4"), None)
}

test "strip v prefix" {
  assert_eq(strip_v_prefix("v1.0.0"), "1.0.0")
  assert_eq(strip_v_prefix("1.0.0"), "1.0.0")
  assert_eq(strip_v_prefix("v"), "v")
  assert_eq(strip_v_prefix(""), "")
}

test "UpdateSummary fields" {
  let summary : UpdateSummary = {
    results: [
      Updated("tool-a", "1.0", "2.0"),
      AlreadyUpToDate("tool-b", "3.0"),
      Failed("tool-c", "error msg"),
    ],
    total: 3,
    updated: 1,
    failed: 1,
    up_to_date: 1,
  }
  assert_eq(summary.total, 3)
  assert_eq(summary.updated, 1)
}

test "format_summary output" {
  let summary : UpdateSummary = {
    results: [Updated("mytool", "1.0", "2.0")],
    total: 1,
    updated: 1,
    failed: 0,
    up_to_date: 0,
  }
  let report = format_summary(summary)
  assert_true(report.contains("mytool"))
  assert_true(report.contains("1.0"))
  assert_true(report.contains("2.0"))
  assert_true(report.contains("UPDATED"))
}

test "match_asset_to_platform" {
  assert_eq(
    match_asset_to_platform("wasm-tools-1.0-aarch64-macos.tar.gz"),
    Some("darwin_arm64"),
  )
  assert_eq(
    match_asset_to_platform("wasm-tools-1.0-x86_64-linux.tar.gz"),
    Some("linux_amd64"),
  )
  assert_eq(
    match_asset_to_platform("wasm-tools-1.0-x86_64-windows.zip"),
    Some("windows_amd64"),
  )
  assert_eq(match_asset_to_platform("checksums.txt"), None)
}

test "detect_archive_type" {
  assert_eq(detect_archive_type("foo.tar.gz"), "tar.gz")
  assert_eq(detect_archive_type("foo.tgz"), "tar.gz")
  assert_eq(detect_archive_type("foo.tar.xz"), "tar.xz")
  assert_eq(detect_archive_type("foo.zip"), "zip")
  assert_eq(detect_archive_type("foo.bin"), "unknown")
}
