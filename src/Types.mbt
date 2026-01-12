// Checksum Updater Types and Data Structures
// This module defines the core data types used throughout the checksum updater

pub type Platform = String
pub type Version = String
pub type Sha256 = String
pub type Url = String
pub type Timestamp = String

// Platform information for a specific tool version
pub struct PlatformInfo {
    sha256: Sha256,
    url_suffix: String,
    binaries: List[String],
    archive_type: String, // "tar.gz" | "zip"
}

// Version information with all platforms
pub struct VersionInfo {
    release_date: String, // "YYYY-MM-DD"
    platforms: Dict[Platform, PlatformInfo]
}

// Complete tool information
pub struct ToolInfo {
    tool_name: String,
    github_repo: String,
    latest_version: Version,
    last_checked: Timestamp,
    build_type: String, // "binary" | "source" | "wasm"
    versions: Dict[Version, VersionInfo],
    supported_platforms: List[Platform]
}

// Update configuration
pub struct UpdateConfig {
    force: Bool,
    dry_run: Bool,
    skip_errors: Bool,
    parallel: Bool,
    timeout_seconds: Int
}

// Individual tool update result
pub struct ToolUpdateResult {
    tool_name: String,
    old_version: Option[Version],
    new_version: Version,
    version_change: String, // "major" | "minor" | "patch" | "new"
    platforms_updated: Int,
    release_notes_url: Option[Url],
    success: Bool,
    error: Option[String]
}

// Summary of update operation
pub struct UpdateSummary {
    tools_processed: Int,
    tools_updated: Int,
    new_versions_found: Int,
    errors: Int,
    duration_ms: Int
}

// Complete update results
pub struct UpdateResults {
    summary: UpdateSummary,
    updates: List[ToolUpdateResult],
    errors: List[ToolError]
}

// Tool error information
pub struct ToolError {
    tool_name: String,
    message: String,
    is_retryable: Bool
}

// Validation results
pub struct ValidationResults {
    tools_validated: Int,
    valid_checksums: Int,
    invalid_checksums: Int,
    fixed_checksums: Int,
    errors: List[ToolError]
}

// GitHub release information
pub struct GitHubRelease {
    tag_name: String,
    name: String,
    published_at: Timestamp,
    body: String,
    html_url: Url,
    assets: List[GitHubAsset]
}

// GitHub release asset
pub struct GitHubAsset {
    name: String,
    browser_download_url: Url,
    size: Int,
    download_count: Int
}

// Platform detection patterns
pub struct PlatformPattern {
    platform: Platform,
    pattern: String, // Regex pattern to match asset names
    archive_type: String
}

// Default platform patterns for common tools
pub fn default_platform_patterns() -> List[PlatformPattern] {
    [
        PlatformPattern {
            platform: "darwin_arm64",
            pattern: r"(aarch64|arm64)-macos\.(tar\.gz|zip)",
            archive_type: "tar.gz"
        },
        PlatformPattern {
            platform: "darwin_amd64",
            pattern: r"(x86_64|amd64)-macos\.(tar\.gz|zip)",
            archive_type: "tar.gz"
        },
        PlatformPattern {
            platform: "linux_amd64",
            pattern: r"(x86_64|amd64)-linux\.(tar\.gz|zip)",
            archive_type: "tar.gz"
        },
        PlatformPattern {
            platform: "linux_arm64",
            pattern: r"(aarch64|arm64)-linux\.(tar\.gz|zip)",
            archive_type: "tar.gz"
        },
        PlatformPattern {
            platform: "windows_amd64",
            pattern: r"(x86_64|amd64)-windows\.(zip|tar\.gz)",
            archive_type: "zip"
        }
    ]
}

// Common platforms list
pub fn common_platforms() -> List[Platform] {
    [
        "darwin_amd64",
        "darwin_arm64", 
        "linux_amd64",
        "linux_arm64",
        "windows_amd64"
    ]
}

// Semantic version comparison
pub fn compare_versions(old_ver: Version, new_ver: Version) -> String {
    // Simplified version comparison - in real implementation would use proper semver parsing
    if old_ver == new_ver {
        "none"
    } else if strings::starts_with(new_ver, "0.") || strings::starts_with(old_ver, "0.") {
        // Handle pre-1.0 versions differently
        if new_ver > old_ver { "major" } else { "patch" }
    } else {
        let old_parts = strings::split(old_ver, ".")
        let new_parts = strings::split(new_ver, ".")
        
        if len(old_parts) >= 1 && len(new_parts) >= 1 && new_parts[0] != old_parts[0] {
            "major"
        } else if len(old_parts) >= 2 && len(new_parts) >= 2 && new_parts[1] != old_parts[1] {
            "minor"
        } else {
            "patch"
        }
    }
}