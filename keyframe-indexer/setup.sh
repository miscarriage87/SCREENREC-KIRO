#!/bin/bash

set -e

echo "🚀 Setting up Keyframe Indexer Service"
echo "======================================"

# Validate project structure
echo "1. Validating project structure..."
./validate-project.sh

echo ""
echo "2. Checking system dependencies..."

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "Rust not found. Installing..."
    ./install-rust.sh
    source ~/.cargo/env
else
    echo "✓ Rust is already installed"
    rustc --version
    cargo --version
fi

# Check if FFmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "FFmpeg not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install ffmpeg
    else
        echo "❌ Homebrew not found. Please install FFmpeg manually:"
        echo "   brew install ffmpeg"
        echo "   or"
        echo "   sudo port install ffmpeg"
        exit 1
    fi
else
    echo "✓ FFmpeg is already installed"
    ffmpeg -version | head -1
fi

echo ""
echo "3. Setting up project directories..."
mkdir -p test-videos
mkdir -p output
mkdir -p frames
echo "✓ Created directories: test-videos, output, frames"

echo ""
echo "4. Building project..."
cargo build --release

echo ""
echo "5. Running tests..."
cargo test

echo ""
echo "✅ Setup complete!"
echo ""
echo "Usage:"
echo "  Start indexer: make run"
echo "  Run tests:     make test"
echo "  View help:     make help"
echo ""
echo "The indexer will watch for video files in ./test-videos/"
echo "and output frame metadata to ./output/"