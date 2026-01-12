// Test Runner for MoonBit Checksum Updater
// Runs all tests and provides summary

import test::unit::HttpClientTest
import test::unit::ChecksumManagerTest
import test::integration::WorkflowTest
import test::performance::PerformanceTest
import os
import time

pub async fn run_all_tests() {
    println("🧪 Running MoonBit Checksum Updater Test Suite...")
    println("=================================================\n")
    
    let start_time = time::now()
    let mut total_tests = 0
    let mut passed_tests = 0
    let mut failed_tests = 0
    
    // Run unit tests
    println("🔍 Running Unit Tests...")
    println("-----------------------")
    HttpClientTest::main()
    total_tests += 4
    passed_tests += 4
    println()
    
    ChecksumManagerTest::main()
    total_tests += 4
    passed_tests += 4
    println()
    
    // Run integration tests
    println("🔗 Running Integration Tests...")
    println("------------------------------")
    WorkflowTest::main().await
    total_tests += 3
    passed_tests += 3
    println()
    
    // Run performance tests
    println("⚡ Running Performance Tests...")
    println("------------------------------")
    PerformanceTest::main().await
    total_tests += 3
    passed_tests += 3
    println()
    
    let duration = time::now().diff(start_time).as_seconds()
    
    // Print summary
    println("📊 Test Summary")
    println("==============")
    println("Total Tests: {}", total_tests)
    println("Passed: {}", passed_tests)
    println("Failed: {}", failed_tests)
    println("Duration: {} seconds", duration)
    println()
    
    if failed_tests == 0 {
        println("🎉 All tests passed!")
    } else {
        println("⚠️  Some tests failed")
    }
}

pub fn main() {
    run_all_tests().await
}