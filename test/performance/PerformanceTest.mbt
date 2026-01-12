// Performance Tests for Checksum Updater
// Tests performance characteristics and benchmarks

import UpdateEngine
import ChecksumManager
import Types
import time
import temp
import os

pub async fn test_parallel_performance() {
    println("Testing parallel update performance...")
    
    let temp_dir = temp::create_temp_dir()
    let manager = ChecksumManager::create_checksum_manager(temp_dir)
    let engine = UpdateEngine::create_update_engine(manager)
    
    // Create multiple test tools
    let tool_names = ["tool1", "tool2", "tool3", "tool4", "tool5"]
    
    for tool_name in tool_names {
        let mut tool_info = JsonUtils::create_empty_tool_info(tool_name, format("{}/repo", tool_name))
        
        let mut version_info = Types::VersionInfo {
            release_date: "2024-01-01",
            platforms: Dict::new()
        }
        
        version_info.platforms["linux_amd64"] = Types::PlatformInfo {
            sha256: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
            url_suffix: format("{}-linux-amd64.tar.gz", tool_name),
            binaries: [tool_name],
            archive_type: "tar.gz"
        }
        
        tool_info = JsonUtils::merge_version_info(tool_info, "1.0.0", version_info)
        manager.save_tool_info(tool_info)
    }
    
    let config = Types::UpdateConfig {
        force: false,
        dry_run: true,
        skip_errors: false,
        parallel: true,
        timeout_seconds: 30
    }
    
    let start_time = time::now()
    let result = engine.update_tools(tool_names, config).await
    let duration = time::now().diff(start_time).as_milliseconds()
    
    match result {
        Ok(results) => {
            println("✅ Parallel update of {} tools took {}ms", len(tool_names), duration)
            assert(duration < 10000, "Should complete in reasonable time")
        },
        Err(error) => {
            println("⚠️  Parallel update failed: {}", error)
        }
    }
    
    // Clean up
    for tool_name in tool_names {
        let json_path = format("{}/{}.json", temp_dir, tool_name)
        os::remove_file(json_path)
    }
    temp::remove_temp_dir(temp_dir)
}

pub async fn test_sequential_performance() {
    println("Testing sequential update performance...")
    
    let temp_dir = temp::create_temp_dir()
    let manager = ChecksumManager::create_checksum_manager(temp_dir)
    let engine = UpdateEngine::create_update_engine(manager)
    
    // Create multiple test tools
    let tool_names = ["tool1", "tool2", "tool3"]
    
    for tool_name in tool_names {
        let mut tool_info = JsonUtils::create_empty_tool_info(tool_name, format("{}/repo", tool_name))
        
        let mut version_info = Types::VersionInfo {
            release_date: "2024-01-01",
            platforms: Dict::new()
        }
        
        version_info.platforms["linux_amd64"] = Types::PlatformInfo {
            sha256: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
            url_suffix: format("{}-linux-amd64.tar.gz", tool_name),
            binaries: [tool_name],
            archive_type: "tar.gz"
        }
        
        tool_info = JsonUtils::merge_version_info(tool_info, "1.0.0", version_info)
        manager.save_tool_info(tool_info)
    }
    
    let config = Types::UpdateConfig {
        force: false,
        dry_run: true,
        skip_errors: false,
        parallel: false,
        timeout_seconds: 30
    }
    
    let start_time = time::now()
    let result = engine.update_tools(tool_names, config).await
    let duration = time::now().diff(start_time).as_milliseconds()
    
    match result {
        Ok(results) => {
            println("✅ Sequential update of {} tools took {}ms", len(tool_names), duration)
            assert(duration < 15000, "Should complete in reasonable time")
        },
        Err(error) => {
            println("⚠️  Sequential update failed: {}", error)
        }
    }
    
    // Clean up
    for tool_name in tool_names {
        let json_path = format("{}/{}.json", temp_dir, tool_name)
        os::remove_file(json_path)
    }
    temp::remove_temp_dir(temp_dir)
}

pub async fn test_json_performance() {
    println("Testing JSON serialization performance...")
    
    let temp_dir = temp::create_temp_dir()
    let manager = ChecksumManager::create_checksum_manager(temp_dir)
    
    // Create a large tool info with many versions and platforms
    let mut tool_info = JsonUtils::create_empty_tool_info("large-tool", "large/repo")
    
    let start_time = time::now()
    
    // Add 10 versions
    for version_num in 1..11 {
        let version = format("1.{}.0", version_num)
        let mut version_info = Types::VersionInfo {
            release_date: "2024-01-01",
            platforms: Dict::new()
        }
        
        // Add all platforms to each version
        for platform in Types::common_platforms() {
            version_info.platforms[platform] = Types::PlatformInfo {
                sha256: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
                url_suffix: format("large-tool-{}-{}.tar.gz", version, platform),
                binaries: ["large-tool"],
                archive_type: "tar.gz"
            }
        }
        
        tool_info = JsonUtils::merge_version_info(tool_info, version, version_info)
    }
    
    let creation_duration = time::now().diff(start_time).as_milliseconds()
    
    // Test saving
    let start_time = time::now()
    let save_result = manager.save_tool_info(tool_info)
    let save_duration = time::now().diff(start_time).as_milliseconds()
    
    match save_result {
        Ok(_) => {
            println("✅ Created large tool info in {}ms", creation_duration)
            println("✅ Saved large tool info in {}ms", save_duration)
            assert(creation_duration < 1000, "Creation should be fast")
            assert(save_duration < 500, "Saving should be fast")
        },
        Err(error) => {
            println("❌ Large JSON save failed: {}", error)
            assert(false, format("Large JSON failed: {}", error))
        }
    }
    
    // Test loading
    let start_time = time::now()
    let load_result = manager.load_tool_info("large-tool")
    let load_duration = time::now().diff(start_time).as_milliseconds()
    
    match load_result {
        Ok(loaded_info) => {
            assert(len(loaded_info.versions) == 10, "Should have 10 versions")
            println("✅ Loaded large tool info in {}ms", load_duration)
            assert(load_duration < 500, "Loading should be fast")
        },
        Err(error) => {
            println("❌ Large JSON load failed: {}", error)
            assert(false, format("Large JSON load failed: {}", error))
        }
    }
    
    // Clean up
    let json_path = format("{}/large-tool.json", temp_dir)
    os::remove_file(json_path)
    temp::remove_temp_dir(temp_dir)
}

pub fn main() {
    println("Running Performance Tests...\n")
    
    test_parallel_performance().await
    println()
    
    test_sequential_performance().await
    println()
    
    test_json_performance().await
    println()
    
    println("✅ Performance tests completed!")
}