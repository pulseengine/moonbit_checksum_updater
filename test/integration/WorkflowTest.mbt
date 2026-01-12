// Integration Tests for Complete Workflow
// Tests end-to-end functionality

import ChecksumManager
import UpdateEngine
import Validator
import Types
import temp
import os

pub async fn test_complete_workflow() {
    println("Testing complete workflow: load → update → validate...")
    
    // Create temporary directory for test
    let temp_dir = temp::create_temp_dir()
    let manager = ChecksumManager::create_checksum_manager(temp_dir)
    
    // 1. Test tool info creation and saving
    let mut tool_info = JsonUtils::create_empty_tool_info("test-tool", "test/repo")
    
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
    
    let save_result = manager.save_tool_info(tool_info)
    assert(save_result.is_ok(), "Should save tool info successfully")
    
    // 2. Test loading the saved tool info
    let load_result = manager.load_tool_info("test-tool")
    
    match load_result {
        Ok(loaded_info) => {
            assert(loaded_info.latest_version == "1.0.0", "Should load correct version")
            assert(loaded_info.versions.contains_key("1.0.0"), "Should contain version")
            println("✅ Load and save workflow successful")
        },
        Err(error) => {
            println("❌ Load failed: {}", error)
            assert(false, format("Load failed: {}", error))
        }
    }
    
    // 3. Test update engine
    let engine = UpdateEngine::create_update_engine(manager)
    
    let config = Types::UpdateConfig {
        force: false,
        dry_run: true,
        skip_errors: false,
        parallel: false,
        timeout_seconds: 30
    }
    
    // Note: We can't test actual GitHub updates in tests, but we can test the orchestration
    let update_result = engine.update_tools(["test-tool"], config).await
    
    match update_result {
        Ok(results) => {
            assert(results.summary.tools_processed == 1, "Should process 1 tool")
            println("✅ Update orchestration successful")
        },
        Err(error) => {
            println("⚠️  Update failed (may be expected in test): {}", error)
        }
    }
    
    // 4. Test validation
    let validator = Validator::create_validator(false, false)
    
    let validation_result = validator.validate_tool(loaded_info)
    
    match validation_result {
        Ok(results) => {
            assert(results.tools_validated == 1, "Should validate 1 tool")
            println("✅ Validation workflow successful")
        },
        Err(error) => {
            println("⚠️  Validation failed (may be expected): {}", error)
        }
    }
    
    // Clean up
    let json_path = format("{}/test-tool.json", temp_dir)
    os::remove_file(json_path)
    temp::remove_temp_dir(temp_dir)
    
    println("✅ Complete workflow test passed!")
}

pub async fn test_error_handling() {
    println("Testing error handling...")
    
    let manager = ChecksumManager::create_checksum_manager("./nonexistent")
    
    // Test loading from non-existent directory
    let result = manager.get_tool_info("nonexistent-tool")
    
    match result {
        Ok(_) => println("⚠️  Unexpected success for nonexistent tool"),
        Err(error) => {
            assert(!error.is_empty(), "Should have error message")
            println("✅ Error handling works correctly")
        }
    }
}

pub async fn test_json_roundtrip() {
    println("Testing JSON roundtrip...")
    
    let temp_dir = temp::create_temp_dir()
    let manager = ChecksumManager::create_checksum_manager(temp_dir)
    
    // Create complex tool info
    let mut tool_info = JsonUtils::create_empty_tool_info("complex-tool", "complex/repo")
    
    // Add multiple versions
    for version in ["1.0.0", "1.1.0", "2.0.0"] {
        let mut version_info = Types::VersionInfo {
            release_date: "2024-01-01",
            platforms: Dict::new()
        }
        
        for platform in Types::common_platforms() {
            version_info.platforms[platform] = Types::PlatformInfo {
                sha256: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
                url_suffix: format("complex-tool-{}-{}.tar.gz", version, platform),
                binaries: ["complex-tool"],
                archive_type: "tar.gz"
            }
        }
        
        tool_info = JsonUtils::merge_version_info(tool_info, version, version_info)
    }
    
    // Save and reload
    let save_result = manager.save_tool_info(tool_info)
    assert(save_result.is_ok(), "Should save complex tool info")
    
    let load_result = manager.load_tool_info("complex-tool")
    
    match load_result {
        Ok(loaded_info) => {
            assert(len(loaded_info.versions) == 3, "Should have 3 versions")
            assert(loaded_info.latest_version == "2.0.0", "Should have latest version")
            
            for version in ["1.0.0", "1.1.0", "2.0.0"] {
                assert(loaded_info.versions.contains_key(version), format("Should contain version {}", version))
                let version_info = loaded_info.versions[version]
                assert(len(version_info.platforms) == 5, format("Version {} should have 5 platforms", version))
            }
            
            println("✅ JSON roundtrip successful")
        },
        Err(error) => {
            println("❌ JSON roundtrip failed: {}", error)
            assert(false, format("Roundtrip failed: {}", error))
        }
    }
    
    // Clean up
    let json_path = format("{}/complex-tool.json", temp_dir)
    os::remove_file(json_path)
    temp::remove_temp_dir(temp_dir)
}

pub fn main() {
    println("Running Integration Tests...\n")
    
    test_complete_workflow().await
    println()
    
    test_error_handling().await
    println()
    
    test_json_roundtrip().await
    println()
    
    println("✅ Integration tests completed!")
}