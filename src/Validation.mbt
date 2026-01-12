// Comprehensive Validation System for Checksum Updater
// Advanced validation with auto-fix capabilities

import JsonUtils
import Types
import Errors
import HttpClient

pub struct Validator {
    strict_mode: Bool,
    auto_fix: Bool,
    http_client: HttpClient::HttpClient
}

pub fn create_validator(strict_mode: Bool, auto_fix: Bool) -> Validator {
    Validator {
        strict_mode: strict_mode,
        auto_fix: auto_fix,
        http_client: HttpClient::create_http_client()
    }
}

impl Validator {
    // Validate entire tool configuration
    pub async fn validate_tool(&self, tool_info: Types::ToolInfo) -> Result[Types::ValidationResults, String> {
        let mut valid_checksums = 0
        let mut invalid_checksums = 0
        let mut fixed_checksums = 0
        let mut errors = List::new()
        
        // Validate tool metadata
        self.validate_tool_metadata(&tool_info)?
        
        // Validate each version
        for (version, version_info) in tool_info.versions {
            self.validate_version_info(&tool_info, version, version_info)?
            
            // Validate each platform
            for (platform, platform_info) in version_info.platforms {
                let validation_result = self.validate_platform_checksum(tool_info, version, platform, platform_info).await?
                
                match validation_result {
                    ValidationResult::Valid => valid_checksums += 1,
                    ValidationResult::Invalid => invalid_checksums += 1,
                    ValidationResult::Fixed => {
                        fixed_checksums += 1
                        invalid_checksums += 1  // Count as invalid before fix
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
    }
    
    // Validate tool metadata
    fn validate_tool_metadata(&self, tool_info: &Types::ToolInfo) -> Result<Unit, String> {
        // Check required fields
        if tool_info.tool_name.is_empty() {
            return Err("Tool name is required")
        }
        
        if tool_info.github_repo.is_empty() {
            return Err("GitHub repository is required")
        }
        
        // Validate GitHub repo format
        if !strings::contains(tool_info.github_repo, "/") {
            return Err(format("Invalid GitHub repository format: {}", tool_info.github_repo))
        }
        
        // Validate build type
        let valid_build_types = ["binary", "source", "wasm"]
        if !valid_build_types.contains(tool_info.build_type) {
            return Err(format("Invalid build type: {}", tool_info.build_type))
        }
        
        return Ok(())
    }
    
    // Validate version information
    fn validate_version_info(&self, tool_info: &Types::ToolInfo, version: String, version_info: Types::VersionInfo) -> Result<Unit, String> {
        // Check release date format
        if !self.is_valid_date(version_info.release_date) {
            return Err(format("Invalid release date format: {}", version_info.release_date))
        }
        
        // Check that platforms are not empty
        if version_info.platforms.is_empty() {
            return Err(format("No platforms defined for version {}", version))
        }
        
        return Ok(())
    }
    
    // Validate platform checksum
    async fn validate_platform_checksum(&self, tool_info: Types::ToolInfo, version: String, platform: String, platform_info: Types::PlatformInfo) -> Result<ValidationResult, String> {
        // Validate SHA256 format
        if !self.is_valid_sha256(platform_info.sha256) {
            if self.auto_fix {
                return self.try_auto_fix_checksum(tool_info, version, platform, platform_info).await
            }
            return Ok(ValidationResult::Invalid)
        }
        
        // Validate URL suffix
        if platform_info.url_suffix.is_empty() {
            return Err(format("Empty URL suffix for {} {} {}", tool_info.tool_name, version, platform))
        }
        
        // In strict mode, verify checksum by downloading
        if self.strict_mode {
            return self.verify_checksum_by_download(tool_info, version, platform, platform_info).await
        }
        
        return Ok(ValidationResult::Valid)
    }
    
    // Verify checksum by downloading the file
    async fn verify_checksum_by_download(&self, tool_info: Types::ToolInfo, version: String, platform: String, platform_info: Types::PlatformInfo) -> Result<ValidationResult, String> {
        // Construct download URL
        let download_url = self.build_download_url(tool_info, version, platform)?
        
        // Download and compute checksum
        let download_result = self.http_client.download_and_compute_sha256(download_url).await
        
        match download_result {
            Ok((_, computed_sha256)) => {
                if computed_sha256 == platform_info.sha256 {
                    return Ok(ValidationResult::Valid)
                } else {
                    return Err(format!(
                        "Checksum mismatch for {} {} {}. Expected: {}, Actual: {}",
                        tool_info.tool_name, version, platform, platform_info.sha256, computed_sha256
                    ))
                }
            },
            Err(error) => {
                return Err(format!(
                    "Failed to download for checksum verification: {}",
                    error
                ))
            }
        }
    }
    
    // Try to automatically fix invalid checksum
    async fn try_auto_fix_checksum(&self, tool_info: Types::ToolInfo, version: String, platform: String, platform_info: Types::PlatformInfo) -> Result<ValidationResult, String> {
        // Construct download URL
        let download_url = self.build_download_url(tool_info, version, platform)?
        
        // Download and compute new checksum
        let download_result = self.http_client.download_and_compute_sha256(download_url).await
        
        match download_result {
            Ok((_, new_sha256)) => {
                // Update the tool info with new checksum
                let mut updated_tool_info = tool_info
                if updated_tool_info.versions.contains_key(version) {
                    let mut version_info = updated_tool_info.versions[version]
                    if version_info.platforms.contains_key(platform) {
                        let mut platform_info = version_info.platforms[platform]
                        platform_info.sha256 = new_sha256
                        version_info.platforms[platform] = platform_info
                        updated_tool_info.versions[version] = version_info
                        
                        // Save the updated tool info
                        JsonUtils::save_tool_json(
                            format!("checksums/{}.json", tool_info.tool_name),
                            updated_tool_info
                        )?
                        
                        return Ok(ValidationResult::Fixed)
                    }
                }
                
                return Err("Failed to update checksum in tool info")
            },
            Err(error) => {
                return Err(format!("Failed to download for checksum fix: {}", error))
            }
        }
    }
    
    // Build download URL from tool info
    fn build_download_url(&self, tool_info: Types::ToolInfo, version: String, platform: String) -> Result<String, String> {
        // Get platform info
        if !tool_info.versions.contains_key(version) {
            return Err(format("Version {} not found", version))
        }
        
        let version_info = tool_info.versions[version]
        if !version_info.platforms.contains_key(platform) {
            return Err(format("Platform {} not found for version {}", platform, version))
        }
        
        let platform_info = version_info.platforms[platform]
        
        // Construct URL based on GitHub repo
        let base_url = format!("https://github.com/{}/releases/download/{}", 
            tool_info.github_repo, version)
        
        return Ok(format!("{}/{}", base_url, platform_info.url_suffix))
    }
    
    // Validate SHA256 format
    fn is_valid_sha256(&self, hash: String) -> Bool {
        // SHA256 should be 64 hex characters
        if len(hash) != 64 {
            return false
        }
        
        // Check that it's all hex characters
        return regex::matches(hash, r"^[0-9a-fA-F]{64}$")
    }
    
    // Validate date format (YYYY-MM-DD)
    fn is_valid_date(&self, date: String) -> Bool {
        return regex::matches(date, r"^\d{4}-\d{2}-\d{2}$")
    }
    
    // Check for common issues in tool configuration
    pub fn check_common_issues(&self, tool_info: Types::ToolInfo) -> List[String> {
        let mut issues = List::new()
        
        // Check for placeholder checksums
        for (version, version_info) in tool_info.versions {
            for (platform, platform_info) in version_info.platforms {
                if platform_info.sha256.contains("placeholder") || 
                   platform_info.sha256.contains("TODO") ||
                   platform_info.sha256.is_empty() {
                    issues.push(format!(
                        "Placeholder checksum found for {} {} {}",
                        tool_info.tool_name, version, platform
                    ))
                }
            }
        }
        
        // Check for missing platforms
        for version in tool_info.versions.keys() {
            let version_info = tool_info.versions[version]
            
            for platform in tool_info.supported_platforms {
                if !version_info.platforms.contains_key(platform) {
                    issues.push(format!(
                        "Missing platform {} for {} {}",
                        platform, tool_info.tool_name, version
                    ))
                }
            }
        }
        
        return issues
    }
    
    // Validate toolchain completeness
    pub fn validate_toolchain_completeness(&self, required_tools: List[String], required_versions: Dict[String, String]) -> List[String> {
        let mut missing = List::new()
        
        for tool_name in required_tools {
            let required_version = required_versions.get(tool_name).unwrap_or("latest")
            
            // Load tool info
            let tool_info_result = JsonUtils::load_tool_json(format!("checksums/{}.json", tool_name))
            
            match tool_info_result {
                Ok(tool_info) => {
                    let version_to_check = if required_version == "latest" {
                        tool_info.latest_version
                    } else {
                        required_version
                    }
                    
                    if !tool_info.versions.contains_key(version_to_check) {
                        missing.push(format!(
                            "Missing version {} for tool {}",
                            version_to_check, tool_name
                        ))
                    } else {
                        let version_info = tool_info.versions[version_to_check]
                        
                        // Check that all supported platforms have checksums
                        for platform in tool_info.supported_platforms {
                            if !version_info.platforms.contains_key(platform) {
                                missing.push(format!(
                                    "Missing platform {} for {} {}",
                                    platform, tool_name, version_to_check
                                ))
                            } else {
                                let platform_info = version_info.platforms[platform]
                                if !self.is_valid_sha256(platform_info.sha256) {
                                    missing.push(format!(
                                        "Invalid checksum for {} {} {}",
                                        tool_name, version_to_check, platform
                                    ))
                                }
                            }
                        }
                    }
                },
                Err(error) => {
                    missing.push(format!("Failed to load tool {}: {}", tool_name, error))
                }
            }
        }
        
        return missing
    }
}

// Validation result types
pub enum ValidationResult {
    Valid,       // Checksum is valid
    Invalid,     // Checksum is invalid
    Fixed        // Checksum was automatically fixed
}

// Enhanced validation with retry logic
pub async fn validate_with_retry(validator: &Validator, tool_info: Types::ToolInfo, max_retries: Int) -> Result[Types::ValidationResults, String> {
    let mut retry_count = 0
    
    while retry_count < max_retries {
        let result = validator.validate_tool(tool_info).await
        
        match result {
            Ok(validation_results) => {
                // If we have invalid checksums and auto-fix is enabled, retry
                if validation_results.invalid_checksums > 0 && validator.auto_fix {
                    if retry_count < max_retries - 1 {
                        retry_count += 1
                        time::sleep(1000) // Wait before retry
                        continue
                    }
                }
                return Ok(validation_results)
            },
            Err(error) => {
                if Errors::is_retryable_error(error) && retry_count < max_retries - 1 {
                    retry_count += 1
                    time::sleep(2000) // Longer wait for retryable errors
                    continue
                }
                return Err(error)
            }
        }
    }
    
    return Err("Max validation retries exceeded")
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
    report += format!("- **Tools validated**: {}\n", results.tools_validated)
    report += format!("- **Valid checksums**: {}\n", results.valid_checksums)
    report += format!("- **Invalid checksums**: {}\n", results.invalid_checksums)
    report += format!("- **Fixed checksums**: {}\n", results.fixed_checksums)
    
    if !results.errors.is_empty() {
        report += "\n### ⚠️ Validation Errors\n\n"
        
        for error in results.errors {
            report += format!("- **{}**: {}\n", error.tool_name, error.message)
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
    report += format!("Tools validated: {}\n", results.tools_validated)
    report += format!("Valid checksums: {}\n", results.valid_checksums)
    report += format!("Invalid checksums: {}\n", results.invalid_checksums)
    report += format!("Fixed checksums: {}\n", results.fixed_checksums)
    
    if !results.errors.is_empty() {
        report += "\n=== Validation Errors ===\n"
        
        for error in results.errors {
            report += format!("⚠️  {}: {}\n", error.tool_name, error.message)
        }
    }
    
    return report
}