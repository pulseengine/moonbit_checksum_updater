// Update Engine
// Orchestrates the checksum update process for multiple tools

import ChecksumManager
import Types
import AsyncUtils
import Errors

pub struct UpdateEngine {
    manager: ChecksumManager::ChecksumManager
}

pub fn create_update_engine(manager: ChecksumManager::ChecksumManager) -> UpdateEngine {
    UpdateEngine {
        manager: manager
    }
}

impl UpdateEngine {
    // Update checksums for multiple tools
    pub async fn update_tools(&self, tool_names: List[String], config: Types::UpdateConfig) -> Types::UpdateResults {
        let start_time = time::now()
        
        if config.parallel {
            // Use enhanced async utilities for parallel processing
            return self.update_tools_parallel(tool_names, config).await
        } else {
            // Sequential processing
            return self.update_tools_sequential(tool_names, config).await
        }
    }
    
    // Parallel tool updates using enhanced async utilities
    async fn update_tools_parallel(&self, tool_names: List[String], config: Types::UpdateConfig) -> Types::UpdateResults {
        let mut results = List::new()
        let mut errors = List::new()
        
        // Create update function with proper error handling
        let update_func = |tool_name: String| -> Result[Types::ToolUpdateResult, String> {
            match self.update_single_tool(tool_name, config) {
                Ok(result) => Ok(result),
                Err(error) => Err(error)
            }
        }
        
        // Use async utilities for parallel processing with timeout
        let async_results = AsyncUtils::update_tools_parallel(
            tool_names,
            update_func,
            config.parallel_concurrency().unwrap_or(4),
            config.timeout_seconds
        ).await
        
        // Convert results
        for result in async_results.updates {
            results.push(result)
        }
        
        for error in async_results.errors {
            errors.push(Types::ToolError {
                tool_name: error.tool_name,
                message: error.message,
                is_retryable: error.is_retryable
            })
        }
        
        let duration_ms = time::now().diff(start_time).as_milliseconds()
        
        return Types::UpdateResults {
            summary: Types::UpdateSummary {
                tools_processed: len(tool_names),
                tools_updated: len(results),
                new_versions_found: self.count_new_versions(results),
                errors: len(errors),
                duration_ms: duration_ms
            },
            updates: results,
            errors: errors
        }
    }
    
    // Sequential tool updates
    async fn update_tools_sequential(&self, tool_names: List[String], config: Types::UpdateConfig) -> Types::UpdateResults {
        let start_time = time::now()
        let mut results = List::new()
        let mut errors = List::new()
        
        for tool_name in tool_names {
            let result = self.update_single_tool(tool_name, config).await
            
            match result {
                Ok(update_result) => results.push(update_result),
                Err(error) => errors.push(Types::ToolError {
                    tool_name: tool_name,
                    message: error,
                    is_retryable: Errors::is_retryable_error(error)
                })
            }
        }
        
        let duration_ms = time::now().diff(start_time).as_milliseconds()
        
        return Types::UpdateResults {
            summary: Types::UpdateSummary {
                tools_processed: len(tool_names),
                tools_updated: len(results),
                new_versions_found: self.count_new_versions(results),
                errors: len(errors),
                duration_ms: duration_ms
            },
            updates: results,
            errors: errors
        }
    }
    
    // Count new versions in update results
    fn count_new_versions(&self, results: List[Types::ToolUpdateResult]) -> Int {
        let mut count = 0
        for result in results {
            if result.version_change != "none" {
                count += 1
            }
        }
        return count
    }
    
    // Update a single tool
    async fn update_single_tool(&self, tool_name: String, config: Types::UpdateConfig) -> Result[Types::ToolUpdateResult, String] {
        let result = self.manager.update_tool_checksums(tool_name, config).await
        
        match result {
            Ok(update_result) => Ok(update_result),
            Err(error) => {
                if config.skip_errors {
                    // Return partial success result
                    Ok(Types::ToolUpdateResult {
                        tool_name: tool_name,
                        old_version: None,
                        new_version: "0.0.0",
                        version_change: "none",
                        platforms_updated: 0,
                        release_notes_url: None,
                        success: false,
                        error: Some(error)
                    })
                } else {
                    Err(error)
                }
            }
        }
    }
    
    // Update all available tools
    pub async fn update_all_tools(&self, config: Types::UpdateConfig) -> Types::UpdateResults {
        let available_tools = self.manager.list_available_tools()
        return self.update_tools(available_tools, config).await
    }
    
    // Get recommended versions for toolchain bundles
    pub fn get_recommended_versions(&self, stability: String) -> Dict[String, String] {
        // This would be enhanced with proper toolchain bundle support
        let mut recommendations = Dict::new()
        
        if stability == "stable" {
            recommendations["wasm-tools"] = "1.243.0"
            recommendations["wit-bindgen"] = "0.49.0"
            recommendations["wasmtime"] = "15.0.0"
            recommendations["moonbit"] = "0.6.33"
        } else {
            // Latest versions - would fetch from GitHub in real implementation
            recommendations["wasm-tools"] = "1.243.0"
            recommendations["wit-bindgen"] = "0.49.0" 
            recommendations["wasmtime"] = "15.0.0"
            recommendations["moonbit"] = "0.6.33"
        }
        
        return recommendations
    }
    
    // Validate tool compatibility
    pub fn validate_tool_compatibility(&self, tools_config: Dict[String, String]) -> List[String] {
        let mut warnings = List::new()
        
        // Simple compatibility matrix - would be enhanced
        let compatibility = Dict::new()
        compatibility["1.243.0"] = Dict::new()
        compatibility["1.243.0"]["wit-bindgen"] = ["0.46.0", "0.48.1", "0.49.0"]
        
        if tools_config.contains_key("wasm-tools") {
            let wasm_tools_version = tools_config["wasm-tools"]
            if compatibility.contains_key(wasm_tools_version) {
                let compat_info = compatibility[wasm_tools_version]
                
                for (tool, version) in tools_config {
                    if tool != "wasm-tools" && compat_info.contains_key(tool) {
                        let recommended_versions = compat_info[tool]
                        if !recommended_versions.contains(version) {
                            warnings.push(format(
                                "Warning: {} version {} may not be compatible with wasm-tools {}. Recommended: {}",
                                tool, version, wasm_tools_version, strings::join(recommended_versions, ", ")
                            ))
                        }
                    }
                }
            }
        }
        
        return warnings
    }
}

// Generate a summary report from update results
pub fn generate_update_summary(results: Types::UpdateResults, format: String) -> String {
    if format == "markdown" {
        return generate_markdown_summary(results)
    } else if format == "json" {
        return generate_json_summary(results)
    } else {
        return generate_text_summary(results)
    }
}

fn generate_markdown_summary(results: Types::UpdateResults) -> String {
    let mut summary = String::new()
    
    summary += "## 📊 Update Summary\n\n"
    summary += format("- **Tools processed**: {}\n", results.summary.tools_processed)
    summary += format("- **Tools updated**: {}\n", results.summary.tools_updated)
    summary += format("- **New versions found**: {}\n", results.summary.new_versions_found)
    summary += format("- **Errors encountered**: {}\n", results.summary.errors)
    summary += format("- **Duration**: {}ms\n\n", results.summary.duration_ms)
    
    if !results.updates.is_empty() {
        summary += "### ✅ Successfully Updated\n\n"
        
        for update in results.updates {
            if update.success {
                let change_emoji = match update.version_change {
                    "major" => "🚨",
                    "minor" => "✨",
                    "patch" => "🔧",
                    _ => "📦"
                }
                
                summary += format(
                    "- {} **{}**: `{}` → `{}` ({})\n",
                    change_emoji,
                    update.tool_name,
                    update.old_version.unwrap_or("none"),
                    update.new_version,
                    update.version_change
                )
            }
        }
        
        summary += "\n"
    }
    
    if !results.errors.is_empty() {
        summary += "### ❌ Errors\n\n"
        
        for error in results.errors {
            summary += format("- **{}**: {}\n", error.tool_name, error.message)
        }
        
        summary += "\n"
    }
    
    return summary
}

fn generate_json_summary(results: Types::UpdateResults) -> String {
    // In real implementation, use proper JSON serialization
    return json::stringify(results, indent = 2)
}

fn generate_text_summary(results: Types::UpdateResults) -> String {
    let mut summary = String::new()
    
    summary += "=== Update Results ===\n"
    summary += format("Tools processed: {}\n", results.summary.tools_processed)
    summary += format("Tools updated: {}\n", results.summary.tools_updated)
    summary += format("New versions found: {}\n", results.summary.new_versions_found)
    summary += format("Errors: {}\n", results.summary.errors)
    summary += format("Duration: {}ms\n\n", results.summary.duration_ms)
    
    if !results.updates.is_empty() {
        summary += "=== Updates ===\n"
        
        for update in results.updates {
            if update.success {
                summary += format(
                    "✅ {}: {} → {} ({})\n",
                    update.tool_name,
                    update.old_version.unwrap_or("none"),
                    update.new_version,
                    update.version_change
                )
            }
        }
        
        summary += "\n"
    }
    
    if !results.errors.is_empty() {
        summary += "=== Errors ===\n"
        
        for error in results.errors {
            summary += format("❌ {}: {}\n", error.tool_name, error.message)
        }
        
        summary += "\n"
    }
    
    return summary
}