// JSON Utilities for Checksum Updater
// Handles parsing and serialization of checksum JSON files

import json
import os
import time

pub fn load_tool_json(file_path: String) -> Result[ToolInfo, String] {
    try {
        let content = os::read_file(file_path)
        let json_data = json::parse(content)
        
        return Ok(parse_tool_info_from_json(json_data))
    } catch error {
        return Err(format("Failed to load JSON from {}: {}", file_path, error))
    }
}

pub fn save_tool_json(file_path: String, tool_info: ToolInfo) -> Result[Unit, String] {
    try {
        let json_data = tool_info_to_json(tool_info)
        let json_content = json::stringify(json_data, indent = 2)
        os::write_file(file_path, json_content)
        return Ok(())
    } catch error {
        return Err(format("Failed to save JSON to {}: {}", file_path, error))
    }
}

fn parse_tool_info_from_json(json_data: Json) -> ToolInfo {
    ToolInfo {
        tool_name: json_data["tool_name"].as_string().unwrap_or(""),
        github_repo: json_data["github_repo"].as_string().unwrap_or(""),
        latest_version: json_data["latest_version"].as_string().unwrap_or(""),
        last_checked: json_data["last_checked"].as_string().unwrap_or(get_current_timestamp()),
        build_type: json_data["build_type"].as_string().unwrap_or("binary"),
        versions: parse_versions(json_data["versions"]),
        supported_platforms: parse_platforms_list(json_data["supported_platforms"])
    }
}

fn parse_versions(versions_json: Json) -> Dict[Version, VersionInfo] {
    let mut versions = Dict::new()
    
    for (version, version_data) in versions_json.as_object().unwrap_or(Dict::new()) {
        versions[version] = VersionInfo {
            release_date: version_data["release_date"].as_string().unwrap_or(""),
            platforms: parse_platforms(version_data["platforms"])
        }
    }
    
    return versions
}

fn parse_platforms(platforms_json: Json) -> Dict[Platform, PlatformInfo] {
    let mut platforms = Dict::new()
    
    for (platform, platform_data) in platforms_json.as_object().unwrap_or(Dict::new()) {
        platforms[platform] = PlatformInfo {
            sha256: platform_data["sha256"].as_string().unwrap_or(""),
            url_suffix: platform_data["url_suffix"].as_string().unwrap_or(""),
            binaries: parse_string_list(platform_data["binaries"]),
            archive_type: platform_data["archive_type"].as_string().unwrap_or("tar.gz")
        }
    }
    
    return platforms
}

fn parse_platforms_list(platforms_json: Json) -> List[Platform] {
    let mut platforms = List::new()
    
    for platform in platforms_json.as_array().unwrap_or(List::new()) {
        platforms.push(platform.as_string().unwrap_or(""))
    }
    
    return platforms
}

fn parse_string_list(list_json: Json) -> List[String] {
    let mut strings = List::new()
    
    for item in list_json.as_array().unwrap_or(List::new()) {
        strings.push(item.as_string().unwrap_or(""))
    }
    
    return strings
}

fn tool_info_to_json(tool_info: ToolInfo) -> Json {
    let mut json_data = Json::object()
    
    json_data["tool_name"] = Json::string(tool_info.tool_name)
    json_data["github_repo"] = Json::string(tool_info.github_repo)
    json_data["latest_version"] = Json::string(tool_info.latest_version)
    json_data["last_checked"] = Json::string(tool_info.last_checked)
    json_data["build_type"] = Json::string(tool_info.build_type)
    json_data["versions"] = versions_to_json(tool_info.versions)
    json_data["supported_platforms"] = platforms_list_to_json(tool_info.supported_platforms)
    
    return json_data
}

fn versions_to_json(versions: Dict[Version, VersionInfo]) -> Json {
    let mut versions_json = Json::object()
    
    for (version, version_info) in versions {
        versions_json[version] = version_info_to_json(version_info)
    }
    
    return versions_json
}

fn version_info_to_json(version_info: VersionInfo) -> Json {
    let mut version_json = Json::object()
    
    version_json["release_date"] = Json::string(version_info.release_date)
    version_json["platforms"] = platforms_to_json(version_info.platforms)
    
    return version_json
}

fn platforms_to_json(platforms: Dict[Platform, PlatformInfo]) -> Json {
    let mut platforms_json = Json::object()
    
    for (platform, platform_info) in platforms {
        platforms_json[platform] = platform_info_to_json(platform_info)
    }
    
    return platforms_json
}

fn platform_info_to_json(platform_info: PlatformInfo) -> Json {
    let mut platform_json = Json::object()
    
    platform_json["sha256"] = Json::string(platform_info.sha256)
    platform_json["url_suffix"] = Json::string(platform_info.url_suffix)
    platform_json["binaries"] = string_list_to_json(platform_info.binaries)
    platform_json["archive_type"] = Json::string(platform_info.archive_type)
    
    return platform_json
}

fn platforms_list_to_json(platforms: List[Platform]) -> Json {
    let mut platforms_json = Json::array()
    
    for platform in platforms {
        platforms_json.push(Json::string(platform))
    }
    
    return platforms_json
}

fn string_list_to_json(strings: List[String]) -> Json {
    let mut strings_json = Json::array()
    
    for string in strings {
        strings_json.push(Json::string(string))
    }
    
    return strings_json
}

fn get_current_timestamp() -> String {
    // Return current timestamp in ISO8601 format
    return time::now().to_iso8601()
}

// Create a new empty tool info structure
pub fn create_empty_tool_info(tool_name: String, github_repo: String) -> ToolInfo {
    ToolInfo {
        tool_name: tool_name,
        github_repo: github_repo,
        latest_version: "0.0.0",
        last_checked: get_current_timestamp(),
        build_type: "binary",
        versions: Dict::new(),
        supported_platforms: common_platforms()
    }
}

// Merge new version info into existing tool info
pub fn merge_version_info(mut tool_info: ToolInfo, version: Version, version_info: VersionInfo) -> ToolInfo {
    tool_info.versions[version] = version_info
    
    // Update latest version if this is newer
    if version > tool_info.latest_version {
        tool_info.latest_version = version
    }
    
    // Update supported platforms from this version
    for platform in version_info.platforms.keys() {
        if !tool_info.supported_platforms.contains(platform) {
            tool_info.supported_platforms.push(platform)
        }
    }
    
    tool_info.last_checked = get_current_timestamp()
    
    return tool_info
}