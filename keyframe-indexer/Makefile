# Keyframe Indexer Makefile

.PHONY: all build test clean install deps check fmt clippy doc run help

# Default target
all: build

# Build the project
build:
	cargo build --release

# Build for development
build-dev:
	cargo build

# Run tests
test:
	cargo test

# Run tests with output
test-verbose:
	cargo test -- --nocapture

# Run integration tests only
test-integration:
	cargo test --test integration_tests

# Clean build artifacts
clean:
	cargo clean
	rm -rf frames/
	rm -rf output/

# Install dependencies (requires FFmpeg)
deps:
	@echo "Installing system dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing FFmpeg via Homebrew..."; \
		brew install ffmpeg; \
	elif command -v port >/dev/null 2>&1; then \
		echo "Installing FFmpeg via MacPorts..."; \
		sudo port install ffmpeg; \
	else \
		echo "Please install FFmpeg manually"; \
		echo "Homebrew: brew install ffmpeg"; \
		echo "MacPorts: sudo port install ffmpeg"; \
		exit 1; \
	fi

# Check code quality
check: fmt clippy test

# Format code
fmt:
	cargo fmt

# Check formatting
fmt-check:
	cargo fmt --check

# Run clippy linter
clippy:
	cargo clippy -- -D warnings

# Generate documentation
doc:
	cargo doc --open

# Run the indexer with default config
run:
	cargo run -- --watch-dir ./test-videos --output-dir ./output

# Run with custom config
run-config:
	cargo run -- --config config.json --watch-dir ./test-videos

# Create test directories
setup-test:
	mkdir -p test-videos
	mkdir -p output
	mkdir -p frames

# Install the binary
install: build
	cargo install --path .

# Uninstall the binary
uninstall:
	cargo uninstall keyframe-indexer

# Development setup
dev-setup: deps setup-test
	@echo "Development environment ready!"
	@echo "Run 'make run' to start the indexer"

# Performance test (placeholder)
perf-test:
	@echo "Running performance tests..."
	cargo test --release test_performance_requirements

# Memory test with valgrind (if available)
memory-test:
	@if command -v valgrind >/dev/null 2>&1; then \
		echo "Running memory tests with valgrind..."; \
		valgrind --tool=memcheck --leak-check=full cargo test; \
	else \
		echo "Valgrind not available, skipping memory tests"; \
	fi

# Benchmark (requires nightly Rust)
bench:
	cargo +nightly bench

# Security audit
audit:
	cargo audit

# Update dependencies
update:
	cargo update

# Show help
help:
	@echo "Available targets:"
	@echo "  build         - Build the project in release mode"
	@echo "  build-dev     - Build the project in development mode"
	@echo "  test          - Run all tests"
	@echo "  test-verbose  - Run tests with output"
	@echo "  test-integration - Run integration tests only"
	@echo "  clean         - Clean build artifacts"
	@echo "  deps          - Install system dependencies"
	@echo "  check         - Run all code quality checks"
	@echo "  fmt           - Format code"
	@echo "  fmt-check     - Check code formatting"
	@echo "  clippy        - Run clippy linter"
	@echo "  doc           - Generate and open documentation"
	@echo "  run           - Run with default configuration"
	@echo "  run-config    - Run with custom configuration"
	@echo "  setup-test    - Create test directories"
	@echo "  install       - Install the binary"
	@echo "  uninstall     - Uninstall the binary"
	@echo "  dev-setup     - Set up development environment"
	@echo "  perf-test     - Run performance tests"
	@echo "  memory-test   - Run memory tests (requires valgrind)"
	@echo "  bench         - Run benchmarks (requires nightly)"
	@echo "  audit         - Run security audit"
	@echo "  update        - Update dependencies"
	@echo "  help          - Show this help message"

# Version information
version:
	@cargo --version
	@rustc --version
	@echo "FFmpeg version:"
	@ffmpeg -version | head -1