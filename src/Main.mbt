// MoonBit Checksum Updater CLI
// Main entry point for the checksum updater tool

import ChecksumManager
import UpdateEngine
import Validator
import Types
import os
import args

pub fn main() {
    let cli_args = parse_arguments()
    
    // Set up checksum manager
    let checksums_dir = cli_args.get("--checksums-dir").unwrap_or("./checksums")
    let manager = ChecksumManager::create_checksum_manager(checksums_dir)
    
    // Create engine and validator
    let engine = UpdateEngine::create_update_engine(manager)
    let validator = Validator::create_checksum_validator()
    
    // Execute the requested command
    let command = cli_args.get("command").unwrap_or("help")
    
    match command {
        "update" => handle_update_command(&engine, cli_args),
        "validate" => handle_validate_command(&engine, &validator, cli_args),
        "list" => handle_list_command(&engine, cli_args),
        "check" => handle_check_command(&validator, &manager, cli_args),
        _ => print_help()
    }
}

fn parse_arguments() -> Dict[String, String] {
    let mut args_dict = Dict::new()
    
    // Parse command line arguments
    let raw_args = os::args()
    
    if len(raw_args) < 2 {
        args_dict["command"] = "help"
        return args_dict
    }
    
    args_dict["command"] = raw_args[1]
    
    for i in 2..len(raw_args) {
        let arg = raw_args[i]
        
        if strings::starts_with(arg, "--") {
            let arg_name = strings::replace(arg, "--", "")
            
            if i + 1 < len(raw_args) && !strings::starts_with(raw_args[i + 1], "--") {
                args_dict[arg_name] = raw_args[i + 1]
                i += 1 // Skip next argument as it's the value
            } else {
                args_dict[arg_name] = "true"
            }
        }
    }
    
    return args_dict
}

fn handle_update_command(engine: &UpdateEngine::UpdateEngine, args: Dict[String, String]) {
    let tools_arg = args.get("--tools")
    let all_tools = args.contains_key("--all")
    let force = args.contains_key("--force")
    let dry_run = args.contains_key("--dry-run")
    let skip_errors = args.contains_key("--skip-errors")
    let output_format = args.get("--output").unwrap_or("text")
    
    let config = Types::UpdateConfig {
        force: force,
        dry_run: dry_run,
        skip_errors: skip_errors,
        parallel: true,
        timeout_seconds: 300
    }
    
    if all_tools {
        println("Updating all tools...")
        let results = engine.update_all_tools(config)
        print_update_results(results, output_format)
    } else if tools_arg.is_some() {
        let tool_names = strings::split(tools_arg.unwrap(), ",")
        println("Updating tools: {}", strings::join(tool_names, ", "))
        
        let results = engine.update_tools(tool_names, config)
        print_update_results(results, output_format)
    } else {
        println("Error: Must specify either --all or --tools")
        print_update_help()
    }
}

fn handle_validate_command(engine: &UpdateEngine::UpdateEngine, validator: &Validator::ChecksumValidator, args: Dict[String, String]) {
    let tools_arg = args.get("--tools")
    let all_tools = args.contains_key("--all")
    let fix = args.contains_key("--fix")
    let output_format = args.get("--output").unwrap_or("text")
    
    let tool_names = if all_tools {
        engine.manager.list_available_tools()
    } else if tools_arg.is_some() {
        strings::split(tools_arg.unwrap(), ",")
    } else {
        println("Error: Must specify either --all or --tools")
        print_validate_help()
        return
    }
    
    println("Validating tools: {}", strings::join(tool_names, ", "))
    
    let results = validator.validate_tools(&engine.manager, tool_names, fix)
    print_validation_results(results, output_format)
}

fn handle_list_command(engine: &UpdateEngine::UpdateEngine, args: Dict[String, String]) {
    let detailed = args.contains_key("--detailed")
    let output_format = args.get("--output").unwrap_or("text")
    
    let tools = engine.manager.list_available_tools()
    
    if output_format == "json" {
        println("{}", json::stringify(tools, indent = 2))
    } else if output_format == "markdown" {
        println("## Available Tools ({})", len(tools))
        for tool in tools {
            if detailed {
                let info_result = engine.manager.get_tool_info(tool)
                match info_result {
                    Ok(info) => {
                        println("- **{}**: latest {} ({} platforms)", tool, info.latest_version, len(info.supported_platforms))
                    },
                    Err(_) => {
                        println("- **{}**: (info unavailable)", tool)
                    }
                }
            } else {
                println("- {}", tool)
            }
        }
    } else {
        println("Available Tools ({}):", len(tools))
        for tool in tools {
            println("  - {}", tool)
        }
    }
}

fn handle_check_command(validator: &Validator::ChecksumValidator, manager: &ChecksumManager::ChecksumManager, args: Dict[String, String]) {
    let tool_name = args.get("--tool")
    
    if tool_name.is_none() {
        println("Error: Must specify --tool")
        print_check_help()
        return
    }
    
    let issues = validator.check_common_issues(manager, tool_name.unwrap())
    
    if issues.is_empty() {
        println("✅ No issues found for {}", tool_name.unwrap())
    } else {
        println("⚠️  Issues found for {}:", tool_name.unwrap())
        for issue in issues {
            println("  - {}", issue)
        }
    }
}

fn print_update_results(results: Types::UpdateResults, format: String) {
    let report = UpdateEngine::generate_update_summary(results, format)
    println("{}", report)
}

fn print_validation_results(results: Types::ValidationResults, format: String) {
    let report = Validator::generate_validation_report(results, format)
    println("{}", report)
}

fn print_help() {
    println("MoonBit Checksum Updater")
    println("Usage: checksum_updater <command> [options]")
    println()
    println("Commands:")
    println("  update      Update checksums for tools")
    println("  validate    Validate existing checksums")
    println("  list        List available tools")
    println("  check       Check for common issues")
    println()
    println("Run 'checksum_updater <command> --help' for command-specific help")
}

fn print_update_help() {
    println("Update Command")
    println("Usage: checksum_updater update [options]")
    println()
    println("Options:")
    println("  --all           Update all available tools")
    println("  --tools <list>  Comma-separated list of tools to update")
    println("  --force         Force update even if no new versions found")
    println("  --dry-run       Show what would be done without making changes")
    println("  --skip-errors   Continue with other tools if one fails")
    println("  --output <fmt>  Output format (text, json, markdown)")
    println()
    println("Examples:")
    println("  checksum_updater update --all")
    println("  checksum_updater update --tools wasm-tools,wit-bindgen")
}

fn print_validate_help() {
    println("Validate Command")
    println("Usage: checksum_updater validate [options]")
    println()
    println("Options:")
    println("  --all           Validate all available tools")
    println("  --tools <list>  Comma-separated list of tools to validate")
    println("  --fix           Attempt to fix validation errors")
    println("  --output <fmt>  Output format (text, json, markdown)")
    println()
    println("Examples:")
    println("  checksum_updater validate --all")
    println("  checksum_updater validate --tools wasm-tools --fix")
}

fn print_check_help() {
    println("Check Command")
    println("Usage: checksum_updater check --tool <tool_name>")
    println()
    println("Options:")
    println("  --tool <name>   Tool name to check for issues")
    println()
    println("Examples:")
    println("  checksum_updater check --tool wasm-tools")
}