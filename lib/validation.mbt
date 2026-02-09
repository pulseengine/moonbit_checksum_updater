/// Pure validation functions for checksum data.
/// No I/O — just structural and format checks.

/// Validate a SHA256 hex string (must be exactly 64 lowercase hex characters).
pub fn is_valid_sha256(s : String) -> Bool {
  if s.length() != 64 {
    return false
  }
  for ch in s {
    if not(is_hex_char(ch)) {
      return false
    }
  }
  true
}

/// Check if a character is a valid lowercase hex digit.
fn is_hex_char(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')
}

/// Validate a date string in YYYY-MM-DD format.
pub fn is_valid_date(s : String) -> Bool {
  check_date_format(s)
}

/// Stricter date format check.
fn check_date_format(s : String) -> Bool {
  if s.length() != 10 {
    return false
  }
  // Positions: 0123456789
  //            YYYY-MM-DD
  // Use char_at for indexed access
  let chars = s.to_array()
  if chars[4] != '-' || chars[7] != '-' {
    return false
  }
  // Check all other positions are digits
  let digit_positions = [0, 1, 2, 3, 5, 6, 8, 9]
  for pos in digit_positions {
    if not(is_digit(chars[pos])) {
      return false
    }
  }
  true
}

/// Check if a character is an ASCII digit.
fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

/// Validate a GitHub repo string (owner/repo format).
pub fn is_valid_github_repo(s : String) -> Bool {
  let mut slash_count = 0
  let mut slash_pos = -1
  for i, ch in s {
    if ch == '/' {
      slash_count += 1
      slash_pos = i
    }
  }
  if slash_count != 1 {
    return false
  }
  slash_pos > 0 && slash_pos < s.length() - 1
}

/// Validate a platform identifier against known platforms.
pub fn is_known_platform(platform : String) -> Bool {
  known_platforms.contains(platform)
}

/// Validation issue with severity.
pub struct ValidationIssue {
  severity : String
  message : String
} derive(Show, Eq)

/// Validate a complete ToolInfo structure, returning all issues found.
pub fn validate_tool_info(info : ToolInfo) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []

  if info.tool_name == "" {
    issues.push({ severity: "error", message: "tool_name is empty" })
  }
  if info.github_repo == "" {
    issues.push({ severity: "error", message: "github_repo is empty" })
  } else if not(is_valid_github_repo(info.github_repo)) {
    issues.push({
      severity: "error",
      message: "github_repo is not in owner/repo format: \{info.github_repo}",
    })
  }
  if info.build_type != "binary" && info.build_type != "source" {
    issues.push({
      severity: "warning",
      message: "unexpected build_type: \{info.build_type}",
    })
  }

  info.versions.each(fn(version_tag, version_info) {
    if not(check_date_format(version_info.release_date)) {
      issues.push({
        severity: "error",
        message: "version \{version_tag}: invalid release_date format: \{version_info.release_date}",
      })
    }

    version_info.platforms.each(fn(platform, plat_info) {
      if not(is_known_platform(platform)) {
        issues.push({
          severity: "warning",
          message: "version \{version_tag}: unknown platform: \{platform}",
        })
      }
      if not(is_valid_sha256(plat_info.sha256)) {
        issues.push({
          severity: "error",
          message: "version \{version_tag}, platform \{platform}: invalid SHA256: \{plat_info.sha256}",
        })
      }
      if plat_info.url_suffix == "" {
        issues.push({
          severity: "error",
          message: "version \{version_tag}, platform \{platform}: empty url_suffix",
        })
      }
      if plat_info.binaries.is_empty() {
        issues.push({
          severity: "warning",
          message: "version \{version_tag}, platform \{platform}: no binaries listed",
        })
      }
    })
  })

  if info.supported_platforms.is_empty() {
    issues.push({
      severity: "warning",
      message: "supported_platforms is empty",
    })
  }

  issues
}

/// Check if validation passed (no error-severity issues).
pub fn validation_passed(issues : Array[ValidationIssue]) -> Bool {
  for issue in issues {
    if issue.severity == "error" {
      return false
    }
  }
  true
}
