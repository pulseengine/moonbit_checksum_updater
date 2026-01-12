// Unit Tests for HttpClient
// Tests HTTP client functionality including native MoonBit integration

import HttpClient
import Errors
import time

pub fn test_github_request() {
    println("Testing GitHub API request...")
    
    let client = HttpClient::create_http_client()
    
    // Test successful request
    let result = client.fetch_github_releases("bytecodealliance/wasm-tools")
    
    match result {
        Ok(releases) => {
            assert(len(releases) > 0, "Should fetch releases")
            assert(releases[0].tag_name.contains("1."), "Should have valid version")
            println("✅ GitHub API request successful")
        },
        Err(error) => {
            println("⚠️  GitHub API request failed (may be expected): {}", error)
            // This might fail in test environment due to network restrictions
        }
    }
}

pub fn test_sha256_computation() {
    println("Testing SHA256 computation with native crypto...")
    
    let client = HttpClient::create_http_client()
    let content = "test content for checksum"
    
    let result = client.compute_sha256(content)
    
    match result {
        Ok(hash) => {
            assert(len(hash) == 64, "SHA256 should be 64 characters")
            assert(regex::matches(hash, r"^[0-9a-fA-F]{64}$"), "Should be hex")
            println("✅ SHA256 computation successful: {}", hash)
        },
        Err(error) => {
            println("❌ SHA256 computation failed: {}", error)
            assert(false, format("SHA256 failed: {}", error))
        }
    }
}

pub fn test_rate_limit_handling() {
    println("Testing rate limit handling...")
    
    let client = HttpClient::create_http_client()
    
    // This test verifies that rate limit errors are handled properly
    // We'll simulate a rate limit response
    
    // Test that rate limit parsing works
    let headers = Dict::new()
    headers["X-RateLimit-Reset"] = "1735689600" // 2025-01-01 00:00:00 UTC
    
    let reset_time = client.parse_rate_limit_reset(headers)
    assert(!reset_time.is_empty(), "Should parse rate limit reset time")
    println("✅ Rate limit parsing successful: {}", reset_time)
}

pub fn test_asset_matching() {
    println("Testing asset pattern matching...")
    
    let patterns = Types::default_platform_patterns()
    
    let test_assets = [
        "wasm-tools-1.0.0-x86_64-linux.tar.gz",
        "wasm-tools-1.0.0-aarch64-macos.tar.gz",
        "wit-bindgen-0.1.0-x86_64-windows.zip",
        "unknown-file.txt"
    ]
    
    let assets = List::new()
    for name in test_assets {
        assets.push(HttpClient::GitHubAsset {
            name: name,
            browser_download_url: "https://example.com/" + name,
            size: 1024,
            download_count: 0
        })
    }
    
    let matched = HttpClient::match_assets_to_platforms(assets, patterns)
    
    assert(matched.contains_key("linux_amd64"), "Should match linux_amd64")
    assert(matched.contains_key("darwin_arm64"), "Should match darwin_arm64")
    assert(matched.contains_key("windows_amd64"), "Should match windows_amd64")
    assert(!matched.contains_key("unknown"), "Should not match unknown files")
    
    println("✅ Asset pattern matching successful")
}

pub fn main() {
    println("Running HttpClient Unit Tests...\n")
    
    test_github_request()
    println()
    
    test_sha256_computation()
    println()
    
    test_rate_limit_handling()
    println()
    
    test_asset_matching()
    println()
    
    println("✅ HttpClient unit tests completed!")
}