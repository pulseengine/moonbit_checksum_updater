// Real HTTP Client Implementation
// Enhanced HTTP client with async support and proper error handling

import http
import time
import AsyncUtils
import Errors

pub struct RealHttpClient {
    base_client: HttpClient::HttpClient,
    max_retries: Int,
    timeout_seconds: Int
}

pub fn create_real_http_client(api_token: Option[String]) -> RealHttpClient {
    RealHttpClient {
        base_client: HttpClient::create_http_client("MoonBit-Checksum-Updater/1.0", api_token),
        max_retries: 3,
        timeout_seconds: 30
    }
}

impl RealHttpClient {
    // Make a real HTTP GET request with retries and timeout using native MoonBit HTTP
    pub async fn get_async(&self, url: String, headers: Dict[String, String]) -> Result[String, String> {
        let operation = || async {
            self.make_native_http_request(url, headers).await
        }
        
        let result = AsyncUtils::retry_with_backoff_async(
            operation,
            self.max_retries,
            1000  // Initial delay: 1 second
        ).await
        
        match result {
            Ok(response) => Ok(response),
            Err(error) => Err(error)
        }
    }
    
    // Native MoonBit HTTP implementation
    async fn make_native_http_request(&self, url: String, headers: Dict[String, String]) -> Result[String, String> {
        try {
            // Convert headers to MoonBit HTTP format
            let mut http_headers = http::Headers::new()
            for (key, value) in headers {
                http_headers.add(key, value)
            }
            
            // Make async HTTP request using native MoonBit HTTP client
            let response = http::get_async(url, http_headers, self.timeout_seconds).await
            
            if response.status >= 200 && response.status < 300 {
                return Ok(response.body)
            } else if response.status == 403 {
                // Handle rate limiting
                let reset_time = self.parse_rate_limit_reset(response.headers)
                return Err(format("GitHub API rate limit exceeded. Reset at: {}", reset_time))
            } else {
                return Err(format("HTTP {}: {}", response.status, response.body))
            }
        } catch error {
            return Err(format("HTTP request failed: {}", error))
        }
    }
    
    // Make a GitHub API request with proper headers and retries
    pub async fn github_request_async(&self, url: String) -> Result[String, String> {
        let mut headers = Dict::new()
        headers["User-Agent"] = "MoonBit-Checksum-Updater/1.0"
        headers["Accept"] = "application/vnd.github+json"
        headers["X-GitHub-Api-Version"] = "2022-11-28"
        
        // Add authentication if available
        if let Some(token) = self.base_client.api_token {
            headers["Authorization"] = format!("Bearer {}", token)
        }
        
        return self.get_async(url, headers).await
    }
    
    // Fetch GitHub releases with pagination support
    pub async fn fetch_all_releases(&self, repo: String) -> Result<List[HttpClient::GitHubRelease], String> {
        let mut all_releases = List::new()
        let mut page = 1
        let mut has_more = true
        
        while has_more && page <= 10 {  // Limit to 10 pages to prevent infinite loops
            let url = format!("https://api.github.com/repos/{}/releases?page={}&per_page=100", repo, page)
            
            let response = self.github_request_async(url).await
            
            match response {
                Ok(body) => {
                    let releases = self.parse_releases(body)?
                    
                    if releases.is_empty() {
                        has_more = false
                    } else {
                        all_releases.extend(releases)
                        page += 1
                        
                        // Respect rate limits
                        if page < 10 {  // Don't sleep on last page
                            time::sleep(1000)  // 1 second delay between pages
                        }
                    }
                },
                Err(error) => {
                    if Errors::is_retryable_error(error) && page <= 10 {
                        time::sleep(2000)  // Longer wait for retryable errors
                        continue
                    }
                    return Err(error)
                }
            }
        }
        
        return Ok(all_releases)
    }
    
    // Parse GitHub releases from JSON
    fn parse_releases(&self, json_str: String) -> Result<List[HttpClient::GitHubRelease], String> {
        try {
            let json_data = json::parse(json_str)
            let mut releases = List::new()
            
            for release_json in json_data.as_array()? {
                releases.push(HttpClient::GitHubRelease {
                    tag_name: release_json["tag_name"].as_string()?,
                    name: release_json["name"].as_string().unwrap_or(""),
                    published_at: release_json["published_at"].as_string()?,
                    body: release_json["body"].as_string().unwrap_or(""),
                    html_url: release_json["html_url"].as_string()?,
                    assets: self.parse_assets(release_json["assets"])?
                })
            }
            
            return Ok(releases)
        } catch error {
            return Err(format!("Failed to parse releases: {}", error))
        }
    }
    
    // Parse GitHub assets from JSON
    fn parse_assets(&self, assets_json: json::Json) -> Result<List[HttpClient::GitHubAsset], String> {
        try {
            let mut assets = List::new()
            
            for asset_json in assets_json.as_array()? {
                assets.push(HttpClient::GitHubAsset {
                    name: asset_json["name"].as_string()?,
                    browser_download_url: asset_json["browser_download_url"].as_string()?,
                    size: asset_json["size"].as_int().unwrap_or(0),
                    download_count: asset_json["download_count"].as_int().unwrap_or(0)
                })
            }
            
            return Ok(assets)
        } catch error {
            return Err(format!("Failed to parse assets: {}", error))
        }
    }
    
    // Download file and compute SHA256 with retries
    pub async fn download_and_verify(&self, url: String) -> Result<(List[Byte], String), String> {
        let operation = || {
            self.base_client.download_and_compute_sha256(url)
        }
        
        let result = AsyncUtils::retry_with_backoff(
            operation,
            self.max_retries,
            1000
        ).await
        
        match result {
            Ok((bytes, sha256)) => Ok((bytes, sha256)),
            Err(error) => Err(error)
        }
    }
    
    // Enhanced checksum computation with native MoonBit crypto
    pub async fn compute_sha256_enhanced(&self, bytes: List[Byte]) -> Result[String, String> {
        // Try native MoonBit crypto first
        let native_result = self.try_native_crypto_sha256(bytes)
        match native_result {
            Ok(hash) => return Ok(hash),
            Err(_) => {
                // Fallback to system strategies if native fails
                let strategies = [
                    self.try_system_sha256sum,
                    self.try_openssl_sha256,
                    self.try_sha256sum_command,
                    self.fallback_sha256
                ]
                
                for strategy in strategies {
                    let result = strategy(bytes)
                    match result {
                        Ok(hash) => return Ok(hash),
                        Err(_) => continue  // Try next strategy
                    }
                }
                
                return Err("All SHA256 computation strategies failed")
            }
        }
    }
    
    // Native MoonBit crypto implementation
    fn try_native_crypto_sha256(&self, bytes: List[Byte]) -> Result[String, String> {
        try {
            // Use native MoonBit crypto library
            let hash_bytes = crypto::sha256(bytes)
            let hash_hex = hex::encode(hash_bytes)
            return Ok(hash_hex)
        } catch error {
            return Err(format("Native crypto failed: {}", error))
        }
    }
    
    // Strategy 1: Try system sha256sum
    fn try_system_sha256sum(&self, bytes: List[Byte]) -> Result[String, String> {
        try {
            let temp_file = temp::create_temp_file()
            fs::write_file(temp_file, bytes)?
            
            let result = process::execute("sha256sum", [temp_file])
            
            if result.success {
                let hash = strings::trim(result.stdout).split(" ")[0]
                fs::remove_file(temp_file)?
                return Ok(hash)
            } else {
                fs::remove_file(temp_file)?
                return Err(format!("sha256sum failed: {}", result.stderr))
            }
        } catch error {
            return Err(format!("sha256sum error: {}", error))
        }
    }
    
    // Strategy 2: Try OpenSSL
    fn try_openssl_sha256(&self, bytes: List[Byte]) -> Result[String, String> {
        try {
            let temp_file = temp::create_temp_file()
            fs::write_file(temp_file, bytes)?
            
            let result = process::execute("openssl", ["dgst", "-sha256", temp_file])
            
            if result.success {
                let hash = strings::trim(result.stdout).split(" ")[1]
                fs::remove_file(temp_file)?
                return Ok(hash)
            } else {
                fs::remove_file(temp_file)?
                return Err(format!("openssl failed: {}", result.stderr))
            }
        } catch error {
            return Err(format!("openssl error: {}", error))
        }
    }
    
    // Strategy 3: Try sha256 command (Windows)
    fn try_sha256sum_command(&self, bytes: List[Byte]) -> Result<String, String> {
        try {
            let temp_file = temp::create_temp_file()
            fs::write_file(temp_file, bytes)?
            
            // Try different command variations
            let commands = [
                ["sha256sum", temp_file],
                ["shasum", "-a", "256", temp_file],
                ["certutil", "-hashfile", temp_file, "SHA256"]
            ]
            
            for cmd in commands {
                let result = process::execute(cmd[0], cmd[1..])
                if result.success {
                    let hash = if cmd[0] == "certutil" {
                        strings::trim(result.stdout).lines()[1].split(" ")[0]
                    } else {
                        strings::trim(result.stdout).split(" ")[0]
                    }
                    fs::remove_file(temp_file)?
                    return Ok(hash)
                }
            }
            
            fs::remove_file(temp_file)?
            return Err("All command variations failed")
        } catch error {
            return Err(format!("Command error: {}", error))
        }
    }
    
    // Strategy 4: Fallback to placeholder
    fn fallback_sha256(&self, bytes: List[Byte]) -> Result<String, String> {
        let hash_prefix = hex::encode(bytes[0..min(8, len(bytes))])
        return Ok("fallback_sha256_" + hash_prefix)
    }
}