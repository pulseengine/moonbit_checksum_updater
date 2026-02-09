test "is_valid_sha256 accepts valid hash" {
  let valid = "6690a33a06ef705a63dbc066210bc0f09b1c08a82952d3cde9fbebd0d484b46f"
  assert_true(is_valid_sha256(valid))
}

test "is_valid_sha256 rejects short hash" {
  assert_true(not(is_valid_sha256("abcdef")))
}

test "is_valid_sha256 rejects uppercase" {
  let upper = "6690A33A06EF705A63DBC066210BC0F09B1C08A82952D3CDE9FBEBD0D484B46F"
  assert_true(not(is_valid_sha256(upper)))
}

test "is_valid_sha256 rejects non-hex" {
  let bad = "gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg"
  assert_true(not(is_valid_sha256(bad)))
}

test "is_valid_date accepts YYYY-MM-DD" {
  assert_true(is_valid_date("2026-01-15"))
  assert_true(is_valid_date("2025-12-03"))
}

test "is_valid_date rejects bad formats" {
  assert_true(not(is_valid_date("01-15-2026")))
  assert_true(not(is_valid_date("2026/01/15")))
  assert_true(not(is_valid_date("2026-1-5")))
  assert_true(not(is_valid_date("")))
}

test "is_valid_github_repo accepts owner/repo" {
  assert_true(is_valid_github_repo("bytecodealliance/wasm-tools"))
  assert_true(is_valid_github_repo("owner/repo"))
}

test "is_valid_github_repo rejects invalid" {
  assert_true(not(is_valid_github_repo("no-slash")))
  assert_true(not(is_valid_github_repo("/leading-slash")))
  assert_true(not(is_valid_github_repo("trailing-slash/")))
  assert_true(not(is_valid_github_repo("a/b/c")))
}

test "is_known_platform" {
  assert_true(is_known_platform("darwin_arm64"))
  assert_true(is_known_platform("linux_amd64"))
  assert_true(not(is_known_platform("freebsd_amd64")))
}

test "validate_tool_info on valid tool" {
  let info : ToolInfo = {
    tool_name: "wasm-tools",
    github_repo: "bytecodealliance/wasm-tools",
    latest_version: "1.243.0",
    last_checked: "2026-01-01T00:00:00Z",
    build_type: "binary",
    versions: {
      "1.243.0": {
        release_date: "2025-12-03",
        platforms: {
          "darwin_arm64": {
            sha256: "6690a33a06ef705a63dbc066210bc0f09b1c08a82952d3cde9fbebd0d484b46f",
            url_suffix: "aarch64-macos.tar.gz",
            binaries: ["wasm-tools"],
            archive_type: "tar.gz",
          },
        },
      },
    },
    supported_platforms: ["darwin_arm64"],
  }
  let issues = validate_tool_info(info)
  assert_true(validation_passed(issues))
}

test "validate_tool_info catches empty tool_name" {
  let info = ToolInfo::empty("", "owner/repo")
  let issues = validate_tool_info(info)
  assert_true(not(validation_passed(issues)))
  assert_true(issues[0].message.contains("tool_name"))
}

test "validate_tool_info catches bad github_repo" {
  let info = ToolInfo::empty("tool", "bad-repo")
  let issues = validate_tool_info(info)
  assert_true(not(validation_passed(issues)))
}

test "validate_tool_info catches bad sha256" {
  let info : ToolInfo = {
    tool_name: "test",
    github_repo: "o/r",
    latest_version: "1.0",
    last_checked: "",
    build_type: "binary",
    versions: {
      "1.0": {
        release_date: "2026-01-01",
        platforms: {
          "linux_amd64": {
            sha256: "not-a-valid-hash",
            url_suffix: "test.tar.gz",
            binaries: ["test"],
            archive_type: "tar.gz",
          },
        },
      },
    },
    supported_platforms: ["linux_amd64"],
  }
  let issues = validate_tool_info(info)
  assert_true(not(validation_passed(issues)))
  // Find the SHA256 error
  let mut found_sha_error = false
  for issue in issues {
    if issue.message.contains("SHA256") {
      found_sha_error = true
    }
  }
  assert_true(found_sha_error)
}

test "validate_tool_info warns on unknown platform" {
  let info : ToolInfo = {
    tool_name: "test",
    github_repo: "o/r",
    latest_version: "1.0",
    last_checked: "",
    build_type: "binary",
    versions: {
      "1.0": {
        release_date: "2026-01-01",
        platforms: {
          "freebsd_amd64": {
            sha256: "a".repeat(64),
            url_suffix: "test.tar.gz",
            binaries: ["test"],
            archive_type: "tar.gz",
          },
        },
      },
    },
    supported_platforms: ["freebsd_amd64"],
  }
  let issues = validate_tool_info(info)
  // Should have warning but pass validation (warnings aren't errors)
  assert_true(validation_passed(issues))
  let mut found_platform_warning = false
  for issue in issues {
    if issue.message.contains("unknown platform") {
      found_platform_warning = true
    }
  }
  assert_true(found_platform_warning)
}

test "error helpers create correct prefixes" {
  let ChecksumError(http_msg) = http_error("timeout")
  assert_true(http_msg.has_prefix("HTTP:"))
  let ChecksumError(io_msg) = io_error("not found")
  assert_true(io_msg.has_prefix("IO:"))
  let ChecksumError(json_msg) = json_error("parse fail")
  assert_true(json_msg.has_prefix("JSON:"))
}

test "is_retryable" {
  assert_true(is_retryable(rate_limit_error("slow down")))
  assert_true(is_retryable(http_error("timeout")))
  assert_true(not(is_retryable(json_error("bad json"))))
  assert_true(not(is_retryable(io_error("file not found"))))
}
