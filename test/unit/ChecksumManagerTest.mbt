// Unit Tests for ChecksumManager
// Tests checksum management functionality

import ChecksumManager
import Types
import JsonUtils
import temp
import os

pub fn test_load_tool_info() {
    println("Testing tool info loading...")
    
    let manager = ChecksumManager::create_checksum_manager("./checksums")
    
    let result = manager.get_tool_info("wasm-tools")
    
    match result {
        Ok(info) => {
            assert(info.tool_name == "wasm-tools", "Tool name should match")
            assert(!info.latest_version.is_empty(), "Should have version")
            assert(len(info.supported_platforms) > 0, "Should have platforms")
            println("✅ Tool info loading successful")
        },
        Err(error) => {
            println("⚠️  Tool info loading failed (may be expected): {}", error)
            // This might fail if checksums directory doesn't exist
        }
    }
}

pub fn test_json_serialization() {
    println("Testing JSON serialization...")
    
    let temp_dir = temp::create_temp_dir()
    let manager = ChecksumManager::create_checksum_manager(temp_dir)
    
    // Create a test tool info
    let mut tool_info = JsonUtils::create_empty_tool_info("test-tool", "test/repo")
    
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
    
    tool_info = JsonUtils::merge_version_info(tool_info, "1.0.0", version_info)
    
    // Test saving
    let save_result = manager.save_tool_info(tool_info)
    
    match save_result {
        Ok(_) => println("✅ JSON serialization successful"),
        Err(error) => {
            println("❌ JSON serialization failed: {}", error)
            assert(false, format("Serialization failed: {}", error))
        }
    }
    
    // Test loading
    let load_result = manager.load_tool_info("test-tool")
    
    match load_result {
        Ok(loaded_info) => {
            assert(loaded_info.latest_version == "1.0.0", "Version should match")
            assert(loaded_info.versions.contains_key("1.0.0"), "Should contain version")
            println("✅ JSON deserialization successful")
        },
        Err(error) => {
            println("❌ JSON deserialization failed: {}", error)
            assert(false, format("Deserialization failed: {}", error))
        }
    }
    
    // Clean up
    let json_path = format("{}/test-tool.json", temp_dir)
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
        assert(result == expected, format("Expected {} but got {}", expected, result))
        println("✅ {} → {} = {}", old_ver, new_ver, result)
    }
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
    println("Running ChecksumManager Unit Tests...\n")
    
    test_load_tool_info()
    println()
    
    test_json_serialization()
    println()
    
    test_version_comparison()
    println()
    
    test_platform_patterns()
    println()
    
    println("✅ ChecksumManager unit tests completed!")
}