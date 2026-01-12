// Checksum Manager
// Core functionality for managing tool checksums

import JsonUtils
import HttpClient
import Types

pub struct ChecksumManager {
    http_client: HttpClient::HttpClient,
    checksums_dir: String,
    tool_configs: Dict[String, ToolConfig]
}

pub struct ToolConfig {
    github_repo: String,
    build_type: String,
    custom_platform_patterns: Option[List[Types::PlatformPattern]]
}

pub fn create_checksum_manager(checksums_dir: String) -> ChecksumManager {
    ChecksumManager {
        http_client: HttpClient::create_http_client(),
        checksums_dir: checksums_dir,
        tool_configs: create_default_tool_configs()
    }
}

impl ChecksumManager {
    // Load tool information from JSON file
    pub fn load_tool_info(&self, tool_name: String) -> Result[Types::ToolInfo, String] {
        let file_path = self.get_tool_json_path(tool_name)
        return JsonUtils::load_tool_json(file_path)
    }
    
    // Save tool information to JSON file
    pub fn save_tool_info(&self, tool_info: Types::ToolInfo) -> Result[Unit, String] {
        let file_path = self.get_tool_json_path(tool_info.tool_name)
        return JsonUtils::save_tool_json(file_path, tool_info)
    }
    
    // Get all available tools
    pub fn list_available_tools(&self) -> List[String] {
        // In real implementation, this would scan the checksums directory
        // For now, return tools from our default configs
        return self.tool_configs.keys().to_list()
    }
    
    // Get tool information including current versions
    pub fn get_tool_info(&self, tool_name: String) -> Result[Types::ToolInfo, String] {
        if !self.tool_configs.contains_key(tool_name) {
            return Err(format("Tool '{}' not configured", tool_name))
        }
        
        let tool_info = self.load_tool_info(tool_name)
        
        match tool_info {
            Ok(info) => Ok(info),
            Err(_) => {
                // Create new tool info if file doesn't exist
                let config = self.tool_configs[tool_name]
                Ok(JsonUtils::create_empty_tool_info(tool_name, config.github_repo))
            }
        }
    }
    
    // Update checksums for a specific tool
    pub async fn update_tool_checksums(&self, tool_name: String, config: Types::UpdateConfig) -> Result[Types::ToolUpdateResult, String] {
        if !self.tool_configs.contains_key(tool_name) {
            return Err(format("Tool '{}' not configured", tool_name))
        }
        
        let tool_config = self.tool_configs[tool_name]
        
        // Get current tool info
        let current_info = self.get_tool_info(tool_name)
        
        match current_info {
            Ok(mut tool_info) => {
                // Fetch latest releases from GitHub
                let releases = self.http_client.fetch_github_releases(tool_config.github_repo)
                
                match releases {
                    Ok(releases) => {
                        // Find the latest release
                        let latest_release = self.find_latest_release(releases)
                        
                        match latest_release {
                            Some(release) => {
                                let latest_version = HttpClient::extract_version_from_tag(release.tag_name)
                                
                                // Check if we already have this version
                                if tool_info.versions.contains_key(latest_version) && !config.force {
                                    return Ok(Types::ToolUpdateResult {
                                        tool_name: tool_name,
                                        old_version: Some(latest_version),
                                        new_version: latest_version,
                                        version_change: "none",
                                        platforms_updated: 0,
                                        release_notes_url: HttpClient::get_release_notes_url(release),
                                        success: true,
                                        error: None
                                    })
                                }
                                
                                // Process the new version
                                let version_info = self.process_release(release, tool_config)
                                
                                match version_info {
                                    Ok(version_info) => {
                                        // Merge into existing tool info
                                        let old_version = tool_info.latest_version
                                        tool_info = JsonUtils::merge_version_info(tool_info, latest_version, version_info)
                                        
                                        // Save updated tool info
                                        if !config.dry_run {
                                            self.save_tool_info(tool_info)
                                        }
                                        
                                        let version_change = Types::compare_versions(old_version, latest_version)
                                        
                                        return Ok(Types::ToolUpdateResult {
                                            tool_name: tool_name,
                                            old_version: Some(old_version),
                                            new_version: latest_version,
                                            version_change: version_change,
                                            platforms_updated: len(version_info.platforms),
                                            release_notes_url: HttpClient::get_release_notes_url(release),
                                            success: true,
                                            error: None
                                        })
                                    },
                                    Err(error) => return Err(error)
                                }
                            },
                            None => return Err(format("No valid releases found for {}", tool_name))
                        }
                    },
                    Err(error) => return Err(error)
                }
            },
            Err(error) => return Err(error)
        }
    }
    
    // Find the latest release from a list
    fn find_latest_release(&self, releases: List<HttpClient::GitHubRelease>) -> Option<HttpClient::GitHubRelease> {
        if releases.is_empty() {
            return None
        }
        
        // Sort by published_at date, newest first
        let sorted = releases.sort_by(|a, b| b.published_at.compare(a.published_at))
        
        // Filter out pre-releases and drafts (in real implementation)
        for release in sorted {
            // Skip drafts and pre-releases for now
            if !release.tag_name.contains("-rc") && !release.tag_name.contains("-beta") {
                return Some(release)
            }
        }
        
        // If no stable releases, return the newest one
        return Some(sorted[0])
    }
    
    // Process a GitHub release into version info
    fn process_release(&self, release: HttpClient::GitHubRelease, tool_config: ToolConfig) -> Result[Types::VersionInfo, String] {
        let version = HttpClient::extract_version_from_tag(release.tag_name)
        let release_date = self.parse_release_date(release.published_at)
        
        // Get platform patterns
        let patterns = tool_config.custom_platform_patterns.unwrap_or(Types::default_platform_patterns())
        
        // Match assets to platforms
        let matched_assets = HttpClient::match_assets_to_platforms(release.assets, patterns)
        
        if matched_assets.is_empty() {
            return Err(format("No matching assets found for release {}", release.tag_name))
        }
        
        // Process each platform
        let mut platforms = Dict::new()
        
        for (platform, asset) in matched_assets {
            // Download and compute checksum
            let download_result = self.http_client.download_and_compute_sha256(asset.browser_download_url)
            
            match download_result {
                Ok((_, sha256)) => {
                    // Determine binaries and archive type from patterns
                    let pattern = patterns.find(|p| p.platform == platform).unwrap()
                    let binaries = self.determine_binaries(asset.name, platform)
                    
                    platforms[platform] = Types::PlatformInfo {
                        sha256: sha256,
                        url_suffix: asset.name,
                        binaries: binaries,
                        archive_type: pattern.archive_type
                    }
                },
                Err(error) => return Err(format("Failed to download {}: {}", asset.name, error))
            }
        }
        
        return Ok(Types::VersionInfo {
            release_date: release_date,
            platforms: platforms
        })
    }
    
    // Parse release date from GitHub timestamp
    fn parse_release_date(&self, github_timestamp: String) -> String {
        // Convert GitHub timestamp (ISO8601) to YYYY-MM-DD format
        // In real implementation, use proper date parsing
        if github_timestamp.contains("T") {
            return github_timestamp.split("T")[0]
        }
        return "1970-01-01"
    }
    
    // Determine binaries from asset name and platform
    fn determine_binaries(&self, asset_name: String, platform: String) -> List[String] {
        // Simple heuristic based on common patterns
        if platform.contains("windows") {
            return [asset_name.replace(".zip", ".exe").replace("-", "_")]
        } else {
            // For Unix-like systems, common binary names
            let mut binaries = List::new()
            
            if asset_name.contains("wasm-tools") {
                binaries.extend(["wasm-tools", "wasm-opt", "wasm2c"])
            } else if asset_name.contains("wit-bindgen") {
                binaries.push("wit-bindgen")
            } else {
                // Default: use the main part of the asset name
                let main_name = asset_name.split("-")[0]
                binaries.push(main_name)
            }
            
            return binaries
        }
    }
    
    // Get path to tool JSON file
    fn get_tool_json_path(&self, tool_name: String) -> String {
        return format("{}/{}.json", self.checksums_dir, tool_name)
    }
}

// Create default tool configurations
fn create_default_tool_configs() -> Dict[String, ToolConfig] {
    let mut configs = Dict::new()
    
    // WebAssembly tools
    configs["wasm-tools"] = ToolConfig {
        github_repo: "bytecodealliance/wasm-tools",
        build_type: "binary",
        custom_platform_patterns: None
    }
    
    configs["wit-bindgen"] = ToolConfig {
        github_repo: "bytecodealliance/wit-bindgen",
        build_type: "binary",
        custom_platform_patterns: None
    }
    
    configs["wasmtime"] = ToolConfig {
        github_repo: "bytecodealliance/wasmtime",
        build_type: "binary",
        custom_platform_patterns: None
    }
    
    // MoonBit tools
    configs["moonbit"] = ToolConfig {
        github_repo: "moonbitlang/moonbit",
        build_type: "binary",
        custom_platform_patterns: None
    }
    
    // Rocq tools  
    configs["rocq"] = ToolConfig {
        github_repo: "pulseengine/rocq",
        build_type: "binary",
        custom_platform_patterns: None
    }
    
    return configs
}

// Get checksum for specific tool/version/platform
pub fn get_tool_checksum(manager: &ChecksumManager, tool_name: String, version: String, platform: String) -> Result[String, String] {
    let tool_info = manager.get_tool_info(tool_name)
    
    match tool_info {
        Ok(info) => {
            if info.versions.contains_key(version) {
                let version_info = info.versions[version]
                if version_info.platforms.contains_key(platform) {
                    let platform_info = version_info.platforms[platform]
                    return Ok(platform_info.sha256)
                }
            }
            return Err(format("Checksum not found for {} {} {}", tool_name, version, platform))
        },
        Err(error) => return Err(error)
    }
}

// Validate that a tool/version/platform combination exists
pub fn validate_tool_exists(manager: &ChecksumManager, tool_name: String, version: String, platform: String) -> Bool {
    let tool_info = manager.get_tool_info(tool_name)
    
    match tool_info {
        Ok(info) => {
            return info.versions.contains_key(version) && 
                   info.versions[version].platforms.contains_key(platform) &&
                   !info.versions[version].platforms[platform].sha256.is_empty()
        },
        Err(_) => return false
    }
}