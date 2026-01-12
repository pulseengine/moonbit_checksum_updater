#!/bin/bash

# Basic test script for MoonBit Checksum Updater

echo "🧪 Testing MoonBit Checksum Updater..."

# Test 1: Check if files exist
echo "✅ Test 1: Checking file structure..."
if [ -f "src/Types.mbt" ] && [ -f "src/ChecksumManager.mbt" ] && [ -f "src/Main.mbt" ]; then
    echo "✅ All core files exist"
else
    echo "❌ Missing core files"
    exit 1
fi

# Test 2: Check JSON example
echo "✅ Test 2: Checking JSON example..."
if [ -f "example_checksums/wasm-tools.json" ]; then
    echo "✅ Example JSON file exists"
    
    # Validate JSON syntax
    if python3 -m json.tool "example_checksums/wasm-tools.json" > /dev/null 2>&1; then
        echo "✅ JSON syntax is valid"
    else
        echo "❌ Invalid JSON syntax"
        exit 1
    fi
else
    echo "❌ Example JSON file missing"
    exit 1
fi

# Test 3: Check README
echo "✅ Test 3: Checking documentation..."
if [ -f "README.md" ]; then
    echo "✅ README.md exists"
else
    echo "❌ README.md missing"
    exit 1
fi

# Test 4: Check build files
echo "✅ Test 4: Checking build configuration..."
if [ -f "BUILD.bazel" ] && [ -f "MODULE.bazel" ]; then
    echo "✅ Build files exist"
else
    echo "❌ Missing build files"
    exit 1
fi

echo ""
echo "🎉 All basic tests passed!"
echo ""
echo "Next steps:"
echo "1. Set up MoonBit toolchain with: bazel run @moonbit_toolchain//:setup"
echo "2. Build the project with: bazel build //:checksum_updater"
echo "3. Run tests with: bazel test //:checksum_tests"
echo "4. Try the CLI with: bazel run //:checksum_updater -- list"