# Always-On AI Companion Makefile

.PHONY: build clean test install uninstall help package sign notarize dist validate-install

# Configuration
PROJECT_NAME = AlwaysOnAICompanion
SCRIPTS_DIR = Scripts
DIST_DIR = dist

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

# Run installation validation tests
test-install:
	@echo "Running installation validation tests..."
	swift test --filter InstallationValidationTests

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build
	rm -rf $(DIST_DIR)

# Install the system using the comprehensive installer
install: build
	@echo "Installing Always-On AI Companion..."
	@chmod +x $(SCRIPTS_DIR)/installer.swift
	@$(SCRIPTS_DIR)/installer.swift

# Install with verbose output
install-verbose: build
	@echo "Installing Always-On AI Companion (verbose)..."
	@chmod +x $(SCRIPTS_DIR)/installer.swift
	@$(SCRIPTS_DIR)/installer.swift --verbose

# Dry run installation (validation only)
install-dry-run: build
	@echo "Performing installation dry run..."
	@chmod +x $(SCRIPTS_DIR)/installer.swift
	@$(SCRIPTS_DIR)/installer.swift --dry-run --verbose

# Uninstall the system
uninstall:
	@echo "Uninstalling Always-On AI Companion..."
	@chmod +x $(SCRIPTS_DIR)/uninstall.sh
	@$(SCRIPTS_DIR)/uninstall.sh

# Force uninstall without prompts
uninstall-force:
	@echo "Force uninstalling Always-On AI Companion..."
	@chmod +x $(SCRIPTS_DIR)/uninstall.sh
	@$(SCRIPTS_DIR)/uninstall.sh --force

# Uninstall but keep recorded data
uninstall-keep-data:
	@echo "Uninstalling Always-On AI Companion (keeping data)..."
	@chmod +x $(SCRIPTS_DIR)/uninstall.sh
	@$(SCRIPTS_DIR)/uninstall.sh --keep-data

# Code signing and notarization
sign: build
	@echo "Code signing and notarizing..."
	@chmod +x $(SCRIPTS_DIR)/codesign_and_notarize.sh
	@$(SCRIPTS_DIR)/codesign_and_notarize.sh

# Create installer package
package: build sign
	@echo "Creating installer package..."
	@chmod +x $(SCRIPTS_DIR)/codesign_and_notarize.sh
	@$(SCRIPTS_DIR)/codesign_and_notarize.sh --create-pkg

# Create DMG distribution
dmg: build sign
	@echo "Creating DMG distribution..."
	@chmod +x $(SCRIPTS_DIR)/codesign_and_notarize.sh
	@$(SCRIPTS_DIR)/codesign_and_notarize.sh --create-dmg

# Full distribution build (app bundle, package, and DMG)
dist: build
	@echo "Creating full distribution..."
	@chmod +x $(SCRIPTS_DIR)/codesign_and_notarize.sh
	@$(SCRIPTS_DIR)/codesign_and_notarize.sh --create-pkg --create-dmg

# Notarize existing build
notarize:
	@echo "Notarizing existing build..."
	@chmod +x $(SCRIPTS_DIR)/codesign_and_notarize.sh
	@$(SCRIPTS_DIR)/codesign_and_notarize.sh --skip-build

# Validate installation requirements
validate-install:
	@echo "Validating installation requirements..."
	@chmod +x $(SCRIPTS_DIR)/installer.swift
	@$(SCRIPTS_DIR)/installer.swift --dry-run

# Check system status
status:
	@echo "Checking system status..."
	@if [ -f $(SCRIPTS_DIR)/status.sh ]; then \
		chmod +x $(SCRIPTS_DIR)/status.sh; \
		$(SCRIPTS_DIR)/status.sh; \
	else \
		echo "Status script not found. Run 'make install' first."; \
	fi

# Format code
format:
	@echo "Formatting Swift code..."
	@if command -v swift-format >/dev/null 2>&1; then \
		find Sources -name "*.swift" -exec swift-format -i {} \; ; \
	else \
		echo "swift-format not found. Install with: brew install swift-format"; \
	fi

# Lint code
lint:
	@echo "Linting Swift code..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint Sources/; \
	else \
		echo "swiftlint not found. Install with: brew install swiftlint"; \
	fi

# Generate documentation
docs:
	@echo "Generating documentation..."
	swift package generate-documentation

# Run integration tests
integration-test: build
	@echo "Running integration tests..."
	@chmod +x $(SCRIPTS_DIR)/run_integration_tests.sh
	@$(SCRIPTS_DIR)/run_integration_tests.sh

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	@echo "Installing development dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install swift-format swiftlint jq; \
	else \
		echo "Homebrew not found. Please install manually:"; \
		echo "  - swift-format"; \
		echo "  - swiftlint"; \
		echo "  - jq"; \
	fi

# Create code signing configuration template
codesign-config:
	@echo "Creating code signing configuration template..."
	@chmod +x $(SCRIPTS_DIR)/codesign_and_notarize.sh
	@$(SCRIPTS_DIR)/codesign_and_notarize.sh --help

# Show system information
system-info:
	@echo "System Information:"
	@echo "=================="
	@echo "macOS Version: $$(sw_vers -productVersion)"
	@echo "Architecture: $$(uname -m)"
	@echo "Swift Version: $$(swift --version | head -n1)"
	@echo "Xcode Version: $$(xcodebuild -version 2>/dev/null | head -n1 || echo 'Not installed')"
	@echo "Available Space: $$(df -h . | tail -n1 | awk '{print $$4}')"

# Show help
help:
	@echo "Always-On AI Companion Build System"
	@echo "==================================="
	@echo ""
	@echo "Build Targets:"
	@echo "  build              - Build release version"
	@echo "  debug              - Build debug version"
	@echo "  clean              - Clean build artifacts"
	@echo ""
	@echo "Testing:"
	@echo "  test               - Run all tests"
	@echo "  test-install       - Run installation validation tests"
	@echo "  integration-test   - Run integration tests"
	@echo ""
	@echo "Installation:"
	@echo "  install            - Install the system"
	@echo "  install-verbose    - Install with verbose output"
	@echo "  install-dry-run    - Validate installation without changes"
	@echo "  validate-install   - Check installation requirements"
	@echo ""
	@echo "Uninstallation:"
	@echo "  uninstall          - Uninstall the system"
	@echo "  uninstall-force    - Force uninstall without prompts"
	@echo "  uninstall-keep-data - Uninstall but preserve recorded data"
	@echo ""
	@echo "Distribution:"
	@echo "  sign               - Code sign and notarize"
	@echo "  package            - Create installer package"
	@echo "  dmg                - Create DMG distribution"
	@echo "  dist               - Create full distribution"
	@echo "  notarize           - Notarize existing build"
	@echo ""
	@echo "Development:"
	@echo "  format             - Format Swift code"
	@echo "  lint               - Lint Swift code"
	@echo "  docs               - Generate documentation"
	@echo "  dev-setup          - Set up development environment"
	@echo ""
	@echo "Utilities:"
	@echo "  status             - Check system status"
	@echo "  system-info        - Show system information"
	@echo "  codesign-config    - Create code signing config template"
	@echo "  help               - Show this help message"