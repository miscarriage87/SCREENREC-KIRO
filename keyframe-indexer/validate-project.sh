#!/bin/bash

echo "Validating Keyframe Indexer project structure..."

# Check required files
required_files=(
    "Cargo.toml"
    "src/main.rs"
    "src/lib.rs"
    "src/keyframe_extractor.rs"
    "src/scene_detector.rs"
    "src/file_watcher.rs"
    "src/metadata_collector.rs"
    "src/parquet_writer.rs"
    "src/error.rs"
    "src/config.rs"
    "config.json"
    "README.md"
    "Makefile"
    ".gitignore"
    "tests/integration_tests.rs"
)

missing_files=()

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    else
        echo "✓ $file"
    fi
done

if [[ ${#missing_files[@]} -eq 0 ]]; then
    echo ""
    echo "✅ All required files are present!"
    echo ""
    echo "Project structure validation complete."
    echo ""
    echo "Next steps:"
    echo "1. Install Rust: ./install-rust.sh"
    echo "2. Install FFmpeg: brew install ffmpeg"
    echo "3. Build project: make build"
    echo "4. Run tests: make test"
    echo "5. Start indexer: make run"
else
    echo ""
    echo "❌ Missing files:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    exit 1
fi