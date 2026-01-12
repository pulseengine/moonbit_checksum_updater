// Basic tests for the checksum updater

import ChecksumManager
import Types
import JsonUtils
import os
import temp

pub fn test_json_serialization() {
    println("Testing JSON serialization...")
    
    // Create a simple tool info
    let tool_info = JsonUtils::create_empty_tool_info("test-tool", "test/repo")
    
    // Add a version
    let mut version_info = Types::VersionInfo {
        release_date: "2024-01-01",
        platforms: Dict::new()
    }
    
    version_info.platforms["linux_amd64"] = Types::PlatformInfo {
        sha256: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
        url_suffix: "test-tool-linux-amd64.tar.gz",
        binaries: ["test-tool"],
        archive_type: "tar.gz"
    }
    
    let tool_info = JsonUtils::merge_version_info(tool_info, "1.0.0", version_info)
    
    // Test serialization
    let temp_dir = temp::create_temp_dir()
    let json_path = format("{}/test-tool.json", temp_dir)
    
    let save_result = JsonUtils::save_tool_json(json_path, tool_info)
    
    match save_result {
        Ok(_) => println("✅ JSON serialization successful"),
        Err(error) => println("❌ JSON serialization failed: {}", error)
    }
    
    // Test deserialization
    let load_result = JsonUtils::load_tool_json(json_path)
    
    match load_result {
        Ok(loaded_info) => {
            if loaded_info.latest_version == "1.0.0" {
                println("✅ JSON deserialization successful")
            } else {
                println("❌ JSON deserialization failed: version mismatch")
            }
        },
        Err(error) => println("❌ JSON deserialization failed: {}", error)
    }
    
    // Clean up
    os::remove_file(json_path)
    temp::remove_temp_dir(temp_dir)
}

pub fn test_version_comparison() {
    println("Testing version comparison...")
    
    let test_cases = [
        ("1.0.0", "1.0.1", "patch"),
        ("1.0.0", "1.1.0", "minor"),
        ("1.0.0", "2.0.0", "major"),
        ("0.5.0", "0.6.0", "major"), // Pre-1.0 versions
        ("1.2.3", "1.2.3", "none")
    ]
    
    for (old_ver, new_ver, expected) in test_cases {
        let result = Types::compare_versions(old_ver, new_ver)
        if result == expected {
            println("✅ {} → {} = {}", old_ver, new_ver, result)
        } else {
            println("❌ {} → {} = {} (expected {})", old_ver, new_ver, result, expected)
        }
    }
}

pub fn test_checksum_manager() {
    println("Testing checksum manager...")
    
    let temp_dir = temp::create_temp_dir()
    let manager = ChecksumManager::create_checksum_manager(temp_dir)
    
    // Test tool listing
    let tools = manager.list_available_tools()
    println("Available tools: {}", len(tools))
    
    // Test getting tool info
    for tool in tools[0..min(2, len(tools))] { // Test first 2 tools
        let info_result = manager.get_tool_info(tool)
        match info_result {
            Ok(info) => println("✅ Got info for {}: {}", tool, info.latest_version),
            Err(error) => println("❌ Failed to get info for {}: {}", tool, error)
        }
    }
    
    // Clean up
    temp::remove_temp_dir(temp_dir)
}

pub fn test_platform_patterns() {
    println("Testing platform patterns...")
    
    let patterns = Types::default_platform_patterns()
    
    let test_assets = [
        "wasm-tools-1.0.0-x86_64-linux.tar.gz",
        "wasm-tools-1.0.0-aarch64-macos.tar.gz",
        "wit-bindgen-0.1.0-x86_64-windows.zip",
        "unknown-file.txt"
    ]
    
    for asset in test_assets {
        let mut matched = false
        for pattern in patterns {
            if regex::matches(asset, pattern.pattern) {
                println("✅ {} matches {} ({})", asset, pattern.platform, pattern.pattern)
                matched = true
                break
            }
        }
        
        if !matched {
            println("⚠️  {} no match found", asset)
        }
    }
}

pub fn main() {
    println("Running Checksum Updater Tests...\n")
    
    test_json_serialization()
    println()
    
    test_version_comparison()
    println()
    
    test_checksum_manager()
    println()
    
    test_platform_patterns()
    println()
    
    println("Tests completed!")
}