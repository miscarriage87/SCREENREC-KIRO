# Always-On AI Companion Makefile

.PHONY: build clean test install uninstall help

# Default target
all: build

# Build all targets
build:
	@echo "Building Always-On AI Companion..."
	swift build -c release

# Build debug version
debug:
	@echo "Building debug version..."
	swift build

# Run tests
test:
	@echo "Running tests..."
	swift test

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build

# Install the daemon (requires sudo for LaunchAgent)
install: build
	@echo "Installing Always-On AI Companion..."
	@echo "Note: This will require administrator privileges for LaunchAgent installation"
	# TODO: Implement installation script

# Uninstall the daemon
uninstall:
	@echo "Uninstalling Always-On AI Companion..."
	# TODO: Implement uninstallation script

# Format code
format:
	@echo "Formatting Swift code..."
	find Sources -name "*.swift" -exec swift-format -i {} \;

# Lint code
lint:
	@echo "Linting Swift code..."
	swiftlint lint Sources/

# Generate documentation
docs:
	@echo "Generating documentation..."
	swift package generate-documentation

# Show help
help:
	@echo "Available targets:"
	@echo "  build     - Build release version"
	@echo "  debug     - Build debug version"
	@echo "  test      - Run tests"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install the system (requires sudo)"
	@echo "  uninstall - Uninstall the system"
	@echo "  format    - Format Swift code"
	@echo "  lint      - Lint Swift code"
	@echo "  docs      - Generate documentation"
	@echo "  help      - Show this help message"