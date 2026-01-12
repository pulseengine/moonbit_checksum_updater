// Comprehensive Error Handling for Checksum Updater
// Centralized error types and handling for the entire system

pub enum ChecksumError {
    // Network and HTTP errors
    NetworkError(String),
    HttpError(Int, String),
    ConnectionTimeout(String),
    DnsResolutionFailed(String),
    SslError(String),
    
    // GitHub API specific errors
    GitHubRateLimited(Timestamp),
    GitHubApiError(Int, String),
    GitHubAuthError(String),
    ReleaseNotFound(String),
    AssetNotFound(String),
    NoMatchingAssets(String),
    
    // File system errors
    FileNotFound(String),
    FileReadError(String),
    FileWriteError(String),
    FilePermissionError(String),
    DirectoryNotFound(String),
    
    // JSON parsing and validation errors
    JsonParseError(String),
    JsonValidationError(String),
    JsonSchemaError(String),
    InvalidJsonFormat(String),
    
    // Checksum computation and validation errors
    ChecksumComputationError(String),
    InvalidChecksumFormat(String),
    ChecksumMismatch(String, String),
    ChecksumVerificationFailed(String),
    
    // Tool and configuration errors
    ToolNotFound(String),
    ToolNotConfigured(String),
    VersionNotFound(String, String),
    PlatformNotSupported(String, String),
    ConfigurationError(String),
    
    // Platform and environment errors
    PlatformNotAvailable(String),
    EnvironmentVariableNotFound(String),
    CommandNotFound(String),
    UnsupportedPlatform(String),
    
    // System and resource errors
    OutOfMemory(String),
    TimeoutError(String),
    CancellationError(String),
    ResourceExhausted(String),
    
    // Validation and business logic errors
    ValidationError(String),
    BusinessRuleViolation(String),
    PreconditionFailed(String),
    PostconditionFailed(String),
    
    // Unknown and unexpected errors
    UnknownError(String),
    UnexpectedError(String),
    InternalError(String)
}

impl ChecksumError {
    /// Check if this error is retryable
    pub fn is_retryable(&self) -> Bool {
        match self {
            ChecksumError::NetworkError(_) => true,
            ChecksumError::ConnectionTimeout(_) => true,
            ChecksumError::DnsResolutionFailed(_) => true,
            ChecksumError::SslError(_) => true,
            ChecksumError::GitHubRateLimited(_) => true,
            ChecksumError::TimeoutError(_) => true,
            ChecksumError::ResourceExhausted(_) => true,
            _ => false
        }
    }
    
    /// Get a user-friendly error message
    pub fn user_message(&self) -> String {
        match self {
            ChecksumError::NetworkError(msg) => format("Network error: {}", msg),
            ChecksumError::HttpError(code, msg) => format("HTTP {} error: {}", code, msg),
            ChecksumError::ConnectionTimeout(url) => format("Connection timeout: {}", url),
            ChecksumError::DnsResolutionFailed(host) => format("DNS resolution failed: {}", host),
            ChecksumError::SslError(msg) => format("SSL error: {}", msg),
            
            ChecksumError::GitHubRateLimited(time) => format("GitHub API rate limited. Try again after {}", time),
            ChecksumError::GitHubApiError(code, msg) => format("GitHub API error {}: {}", code, msg),
            ChecksumError::GitHubAuthError(msg) => format("GitHub authentication failed: {}", msg),
            ChecksumError::ReleaseNotFound(repo) => format("No releases found for: {}", repo),
            ChecksumError::AssetNotFound(asset) => format("Asset not found: {}", asset),
            ChecksumError::NoMatchingAssets(tool) => format("No matching assets found for: {}", tool),
            
            ChecksumError::FileNotFound(path) => format("File not found: {}", path),
            ChecksumError::FileReadError(path) => format("Failed to read file: {}", path),
            ChecksumError::FileWriteError(path) => format("Failed to write file: {}", path),
            ChecksumError::FilePermissionError(path) => format("Permission denied: {}", path),
            ChecksumError::DirectoryNotFound(path) => format("Directory not found: {}", path),
            
            ChecksumError::JsonParseError(msg) => format("JSON parse error: {}", msg),
            ChecksumError::JsonValidationError(msg) => format("JSON validation error: {}", msg),
            ChecksumError::JsonSchemaError(msg) => format("JSON schema error: {}", msg),
            ChecksumError::InvalidJsonFormat(msg) => format("Invalid JSON format: {}", msg),
            
            ChecksumError::ChecksumComputationError(msg) => format("Checksum computation failed: {}", msg),
            ChecksumError::InvalidChecksumFormat(checksum) => format("Invalid checksum format: {}", checksum),
            ChecksumError::ChecksumMismatch(expected, actual) => format("Checksum mismatch. Expected: {}, Actual: {}", expected, actual),
            ChecksumError::ChecksumVerificationFailed(msg) => format("Checksum verification failed: {}", msg),
            
            ChecksumError::ToolNotFound(tool) => format("Tool not found: {}", tool),
            ChecksumError::ToolNotConfigured(tool) => format("Tool not configured: {}", tool),
            ChecksumError::VersionNotFound(version, tool) => format("Version {} not found for tool {}", version, tool),
            ChecksumError::PlatformNotSupported(platform, tool) => format("Platform {} not supported for tool {}", platform, tool),
            ChecksumError::ConfigurationError(msg) => format("Configuration error: {}", msg),
            
            ChecksumError::PlatformNotAvailable(platform) => format("Platform not available: {}", platform),
            ChecksumError::EnvironmentVariableNotFound(var) => format("Environment variable not found: {}", var),
            ChecksumError::CommandNotFound(cmd) => format("Command not found: {}", cmd),
            ChecksumError::UnsupportedPlatform(platform) => format("Unsupported platform: {}", platform),
            
            ChecksumError::OutOfMemory(msg) => format("Out of memory: {}", msg),
            ChecksumError::TimeoutError(operation) => format("Timeout: {}", operation),
            ChecksumError::CancellationError(operation) => format("Operation cancelled: {}", operation),
            ChecksumError::ResourceExhausted(resource) => format("Resource exhausted: {}", resource),
            
            ChecksumError::ValidationError(msg) => format("Validation error: {}", msg),
            ChecksumError::BusinessRuleViolation(rule) => format("Business rule violation: {}", rule),
            ChecksumError::PreconditionFailed(condition) => format("Precondition failed: {}", condition),
            ChecksumError::PostconditionFailed(condition) => format("Postcondition failed: {}", condition),
            
            ChecksumError::UnknownError(msg) => format("Unknown error: {}", msg),
            ChecksumError::UnexpectedError(msg) => format("Unexpected error: {}", msg),
            ChecksumError::InternalError(msg) => format("Internal error: {}", msg)
        }
    }
    
    /// Get a detailed error message with context
    pub fn detailed_message(&self, context: Option[String]) -> String {
        let base_message = self.user_message()
        
        if let Some(ctx) = context {
            return format("{} (Context: {})", base_message, ctx)
        } else {
            return base_message
        }
    }
    
    /// Get the error category for logging
    pub fn category(&self) -> String {
        match self {
            ChecksumError::NetworkError(_) => "network",
            ChecksumError::HttpError(_, _) => "http",
            ChecksumError::ConnectionTimeout(_) => "network",
            ChecksumError::DnsResolutionFailed(_) => "network",
            ChecksumError::SslError(_) => "network",
            
            ChecksumError::GitHubRateLimited(_) => "github",
            ChecksumError::GitHubApiError(_, _) => "github",
            ChecksumError::GitHubAuthError(_) => "github",
            ChecksumError::ReleaseNotFound(_) => "github",
            ChecksumError::AssetNotFound(_) => "github",
            ChecksumError::NoMatchingAssets(_) => "github",
            
            ChecksumError::FileNotFound(_) => "filesystem",
            ChecksumError::FileReadError(_) => "filesystem",
            ChecksumError::FileWriteError(_) => "filesystem",
            ChecksumError::FilePermissionError(_) => "filesystem",
            ChecksumError::DirectoryNotFound(_) => "filesystem",
            
            ChecksumError::JsonParseError(_) => "json",
            ChecksumError::JsonValidationError(_) => "json",
            ChecksumError::JsonSchemaError(_) => "json",
            ChecksumError::InvalidJsonFormat(_) => "json",
            
            ChecksumError::ChecksumComputationError(_) => "checksum",
            ChecksumError::InvalidChecksumFormat(_) => "checksum",
            ChecksumError::ChecksumMismatch(_, _) => "checksum",
            ChecksumError::ChecksumVerificationFailed(_) => "checksum",
            
            ChecksumError::ToolNotFound(_) => "configuration",
            ChecksumError::ToolNotConfigured(_) => "configuration",
            ChecksumError::VersionNotFound(_, _) => "configuration",
            ChecksumError::PlatformNotSupported(_, _) => "configuration",
            ChecksumError::ConfigurationError(_) => "configuration",
            
            ChecksumError::PlatformNotAvailable(_) => "environment",
            ChecksumError::EnvironmentVariableNotFound(_) => "environment",
            ChecksumError::CommandNotFound(_) => "environment",
            ChecksumError::UnsupportedPlatform(_) => "environment",
            
            ChecksumError::OutOfMemory(_) => "system",
            ChecksumError::TimeoutError(_) => "system",
            ChecksumError::CancellationError(_) => "system",
            ChecksumError::ResourceExhausted(_) => "system",
            
            ChecksumError::ValidationError(_) => "validation",
            ChecksumError::BusinessRuleViolation(_) => "validation",
            ChecksumError::PreconditionFailed(_) => "validation",
            ChecksumError::PostconditionFailed(_) => "validation",
            
            ChecksumError::UnknownError(_) => "unknown",
            ChecksumError::UnexpectedError(_) => "unknown",
            ChecksumError::InternalError(_) => "internal"
        }
    }
    
    /// Convert to string for logging
    pub fn to_string(&self) -> String {
        return format("[{}]: {}", self.category(), self.user_message())
    }
}

// Error handling utilities
pub fn handle_error(error: ChecksumError, context: Option[String]) -> Result<Unit, ChecksumError> {
    if error.is_retryable() {
        println("⚠️  Retryable error: {}", error.detailed_message(context))
        return Err(error)
    } else {
        println("❌ Error: {}", error.detailed_message(context))
        return Err(error)
    }
}

// Result type aliases for convenience
pub type Result<T, E> = std::result::Result<T, E>
pub type ChecksumResult<T> = Result<T, ChecksumError>

// Common error constructors
pub fn network_error(msg: String) -> ChecksumError {
    ChecksumError::NetworkError(msg)
}

pub fn github_error(code: Int, msg: String) -> ChecksumError {
    ChecksumError::GitHubApiError(code, msg)
}

pub fn file_error(path: String, operation: String) -> ChecksumError {
    ChecksumError::FileReadError(format!("{}: {}", operation, path))
}

pub fn json_error(msg: String) -> ChecksumError {
    ChecksumError::JsonParseError(msg)
}

pub fn checksum_error(msg: String) -> ChecksumError {
    ChecksumError::ChecksumComputationError(msg)
}

pub fn config_error(msg: String) -> ChecksumError {
    ChecksumError::ConfigurationError(msg)
}