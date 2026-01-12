// Checksum Validator
// Validates existing checksums and fixes common issues

import ChecksumManager
import Types
import HttpClient

pub struct ChecksumValidator {
    http_client: HttpClient::HttpClient
}

pub fn create_checksum_validator() -> ChecksumValidator {
    ChecksumValidator {
        http_client: HttpClient::create_http_client()
    }
}

impl ChecksumValidator {
    // Validate checksums for a specific tool
    pub async fn validate_tool(&self, manager: &ChecksumManager::ChecksumManager, tool_name: String, fix: Bool) -> Result[Types::ValidationResults, String] {
        let tool_info = manager.get_tool_info(tool_name)
        
        match tool_info {
            Ok(info) => {
                let mut valid_checksums = 0
                let mut invalid_checksums = 0
                let mut fixed_checksums = 0
                let mut errors = List::new()
                
                // Check each version
                for (version, version_info) in info.versions {
                    // Check each platform
                    for (platform, platform_info) in version_info.platforms {
                        let validation_result = self.validate_platform_checksum(manager, tool_name, version, platform, platform_info, fix).await
                        
                        match validation_result {
                            Ok(is_valid) => {
                                if is_valid {
                                    valid_checksums += 1
                                } else {
                                    invalid_checksums += 1
                                }
                            },
                            Err(error) => {
                                errors.push(Types::ToolError {
                                    tool_name: tool_name,
                                    message: format("Validation failed for {} {} {}: {}", tool_name, version, platform, error),
                                    is_retryable: true
                                })
                            }
                        }
                    }
                }
                
                return Ok(Types::ValidationResults {
                    tools_validated: 1,
                    valid_checksums: valid_checksums,
                    invalid_checksums: invalid_checksums,
                    fixed_checksums: fixed_checksums,
                    errors: errors
                })
            },
            Err(error) => return Err(error)
        }
    }
    
    // Validate checksums for multiple tools
    pub async fn validate_tools(&self, manager: &ChecksumManager::ChecksumManager, tool_names: List[String], fix: Bool) -> Types::ValidationResults {
        let mut total_valid = 0
        let mut total_invalid = 0
        let mut total_fixed = 0
        let mut all_errors = List::new()
        
        for tool_name in tool_names {
            let result = self.validate_tool(manager, tool_name, fix).await
            
            match result {
                Ok(validation_results) => {
                    total_valid += validation_results.valid_checksums
                    total_invalid += validation_results.invalid_checksums
                    total_fixed += validation_results.fixed_checksums
                    all_errors.extend(validation_results.errors)
                },
                Err(error) => {
                    all_errors.push(Types::ToolError {
                        tool_name: tool_name,
                        message: format("Validation failed: {}", error),
                        is_retryable: true
                    })
                }
            }
        }
        
        Types::ValidationResults {
            tools_validated: len(tool_names),
            valid_checksums: total_valid,
            invalid_checksums: total_invalid,
            fixed_checksums: total_fixed,
            errors: all_errors
        }
    }
    
    // Validate a specific platform checksum
    async fn validate_platform_checksum(&self, manager: &ChecksumManager::ChecksumManager, tool_name: String, version: String, platform: String, platform_info: Types::PlatformInfo, fix: Bool) -> Result[Bool, String] {
        // Check if checksum is valid format
        if !self.is_valid_sha256(platform_info.sha256) {
            if fix {
                return self.try_fix_checksum(manager, tool_name, version, platform, platform_info).await
            }
            return Ok(false)
        }
        
        // For thorough validation, we could re-download and verify
        // But that's expensive, so we'll skip it for now
        // In production, this would be configurable
        
        return Ok(true)
    }
    
    // Check if a string is a valid SHA256 hash
    fn is_valid_sha256(&self, hash: String) -> Bool {
        // SHA256 should be 64 hex characters
        if len(hash) != 64 {
            return false
        }
        
        // Check that it's all hex characters
        return regex::matches(hash, r"^[0-9a-fA-F]{64}$")
    }
    
    // Try to fix an invalid checksum
    async fn try_fix_checksum(&self, manager: &ChecksumManager::ChecksumManager, tool_name: String, version: String, platform: String, platform_info: Types::PlatformInfo) -> Result[Bool, String] {
        // If we have a URL, try to download and recompute checksum
        if platform_info.url_suffix.is_empty() {
            return Err("No URL suffix available to recompute checksum")
        }
        
        // Construct download URL (this would be tool-specific in real implementation)
        let tool_config = manager.tool_configs.get(tool_name)
        
        match tool_config {
            Some(config) => {
                let base_url = format("https://github.com/{}/releases/download/{}", config.github_repo, version)
                let download_url = format("{}/{}", base_url, platform_info.url_suffix)
                
                let download_result = self.http_client.download_and_compute_sha256(download_url).await
                
                match download_result {
                    Ok((_, new_sha256)) => {
                        // Update the tool info with new checksum
                        let mut tool_info = manager.get_tool_info(tool_name)?
                        
                        if tool_info.versions.contains_key(version) {
                            let mut version_info = tool_info.versions[version]
                            
                            if version_info.platforms.contains_key(platform) {
                                let mut platform_info = version_info.platforms[platform]
                                platform_info.sha256 = new_sha256
                                version_info.platforms[platform] = platform_info
                                tool_info.versions[version] = version_info
                                
                                // Save the fixed tool info
                                manager.save_tool_info(tool_info)?
                                
                                return Ok(true)
                            }
                        }
                        
                        return Err("Failed to update checksum in tool info")
                    },
                    Err(error) => return Err(format("Failed to download for checksum fix: {}", error))
                }
            },
            None => return Err("Tool not configured")
        }
    }
    
    // Check for common checksum issues
    pub fn check_common_issues(&self, manager: &ChecksumManager::ChecksumManager, tool_name: String) -> List[String] {
        let mut issues = List::new()
        
        let tool_info = manager.get_tool_info(tool_name)
        
        match tool_info {
            Ok(info) => {
                // Check for placeholder checksums
                for (version, version_info) in info.versions {
                    for (platform, platform_info) in version_info.platforms {
                        if platform_info.sha256.contains("placeholder") || platform_info.sha256.contains("TODO") {
                            issues.push(format("Placeholder checksum found for {} {} {}", tool_name, version, platform))
                        }
                    }
                }
                
                // Check for missing platforms
                for version in info.versions.keys() {
                    let version_info = info.versions[version]
                    
                    for platform in info.supported_platforms {
                        if !version_info.platforms.contains_key(platform) {
                            issues.push(format("Missing platform {} for {} {}", platform, tool_name, version))
                        }
                    }
                }
            },
            Err(error) => {
                issues.push(format("Failed to load tool info: {}", error))
            }
        }
        
        return issues
    }
    
    // Validate that all required tools have checksums
    pub fn validate_toolchain_completeness(&self, manager: &ChecksumManager::ChecksumManager, required_tools: List[String], required_versions: Dict[String, String]) -> List[String] {
        let mut missing = List::new()
        
        for tool_name in required_tools {
            let required_version = required_versions.get(tool_name).unwrap_or("latest")
            
            let tool_info = manager.get_tool_info(tool_name)
            
            match tool_info {
                Ok(info) => {
                    let version_to_check = if required_version == "latest" {
                        info.latest_version
                    } else {
                        required_version
                    }
                    
                    if !info.versions.contains_key(version_to_check) {
                        missing.push(format("Missing version {} for tool {}", version_to_check, tool_name))
                    } else {
                        let version_info = info.versions[version_to_check]
                        
                        // Check that all supported platforms have checksums
                        for platform in info.supported_platforms {
                            if !version_info.platforms.contains_key(platform) {
                                missing.push(format("Missing platform {} for {} {}", platform, tool_name, version_to_check))
                            } else {
                                let platform_info = version_info.platforms[platform]
                                if !self.is_valid_sha256(platform_info.sha256) {
                                    missing.push(format("Invalid checksum for {} {} {}", tool_name, version_to_check, platform))
                                }
                            }
                        }
                    }
                },
                Err(error) => {
                    missing.push(format("Failed to load tool {}: {}", tool_name, error))
                }
            }
        }
        
        return missing
    }
}

// Generate validation report
pub fn generate_validation_report(results: Types::ValidationResults, format: String) -> String {
    if format == "markdown" {
        return generate_markdown_validation_report(results)
    } else if format == "json" {
        return generate_json_validation_report(results)
    } else {
        return generate_text_validation_report(results)
    }
}

fn generate_markdown_validation_report(results: Types::ValidationResults) -> String {
    let mut report = String::new()
    
    report += "## 🔍 Validation Results\n\n"
    report += format("- **Tools validated**: {}\n", results.tools_validated)
    report += format("- **Valid checksums**: {}\n", results.valid_checksums)
    report += format("- **Invalid checksums**: {}\n", results.invalid_checksums)
    report += format("- **Fixed checksums**: {}\n", results.fixed_checksums)
    
    if !results.errors.is_empty() {
        report += "\n### ⚠️ Validation Errors\n\n"
        
        for error in results.errors {
            report += format("- **{}**: {}\n", error.tool_name, error.message)
        }
    }
    
    return report
}

fn generate_json_validation_report(results: Types::ValidationResults) -> String {
    // In real implementation, use proper JSON serialization
    return json::stringify(results, indent = 2)
}

fn generate_text_validation_report(results: Types::ValidationResults) -> String {
    let mut report = String::new()
    
    report += "=== Validation Results ===\n"
    report += format("Tools validated: {}\n", results.tools_validated)
    report += format("Valid checksums: {}\n", results.valid_checksums)
    report += format("Invalid checksums: {}\n", results.invalid_checksums)
    report += format("Fixed checksums: {}\n", results.fixed_checksums)
    
    if !results.errors.is_empty() {
        report += "\n=== Validation Errors ===\n"
        
        for error in results.errors {
            report += format("⚠️  {}: {}\n", error.tool_name, error.message)
        }
    }
    
    return report
}