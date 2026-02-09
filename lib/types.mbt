/// Core data types for the checksum updater.
/// Models the JSON structure used in example_checksums/*.json files.

/// Platform information for a specific build target.
pub struct PlatformInfo {
  sha256 : String
  url_suffix : String
  binaries : Array[String]
  archive_type : String
} derive(Show, Eq, ToJson, FromJson)

/// Version information containing release date and platform builds.
pub struct VersionInfo {
  release_date : String
  platforms : Map[String, PlatformInfo]
} derive(Show, Eq, ToJson, FromJson)

/// Top-level tool information matching the JSON schema.
pub struct ToolInfo {
  tool_name : String
  github_repo : String
  latest_version : String
  last_checked : String
  build_type : String
  versions : Map[String, VersionInfo]
  supported_platforms : Array[String]
} derive(Show, Eq, ToJson, FromJson)

/// Result of updating a single tool.
pub enum ToolUpdateResult {
  Updated(String, String, String) // tool_name, old_version, new_version
  AlreadyUpToDate(String, String) // tool_name, version
  Failed(String, String) // tool_name, error
} derive(Show, Eq)

/// Summary of a batch update operation.
pub struct UpdateSummary {
  results : Array[ToolUpdateResult]
  total : Int
  updated : Int
  failed : Int
  up_to_date : Int
} derive(Show, Eq)

/// Known platform identifiers.
pub let known_platforms : Array[String] = [
  "darwin_amd64",
  "darwin_arm64",
  "linux_amd64",
  "linux_arm64",
  "windows_amd64",
]

/// Create a default empty ToolInfo.
pub fn ToolInfo::empty(tool_name : String, github_repo : String) -> ToolInfo {
  {
    tool_name,
    github_repo,
    latest_version: "",
    last_checked: "",
    build_type: "binary",
    versions: {},
    supported_platforms: known_platforms,
  }
}
