#!/bin/bash

# Always-On AI Companion Code Signing and Notarization Script
# This script handles code signing and notarization for macOS distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/release"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="Always-On AI Companion"
BUNDLE_ID="com.alwaysonai.companion"

# Code signing configuration
DEVELOPER_ID_APPLICATION=""
DEVELOPER_ID_INSTALLER=""
TEAM_ID=""
KEYCHAIN_PROFILE=""

# Notarization configuration
APPLE_ID=""
APP_SPECIFIC_PASSWORD=""
NOTARIZATION_TEAM_ID=""

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "$(printf '=%.0s' $(seq 1 ${#1}))"
}

# Function to check if required tools are available
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed or not in PATH"
        exit 1
    fi
    
    # Check if codesign is available
    if ! command -v codesign &> /dev/null; then
        print_error "codesign tool is not available"
        exit 1
    fi
    
    # Check if notarytool is available (Xcode 13+)
    if ! command -v xcrun &> /dev/null; then
        print_error "xcrun is not available"
        exit 1
    fi
    
    # Check if altool is available (fallback for older Xcode)
    if ! xcrun altool --help &> /dev/null && ! xcrun notarytool --help &> /dev/null; then
        print_error "Neither notarytool nor altool is available"
        exit 1
    fi
    
    print_status "All prerequisites are available"
}

# Function to load configuration
load_configuration() {
    print_header "Loading Configuration"
    
    local config_file="$PROJECT_ROOT/Scripts/codesign_config.json"
    
    if [[ -f "$config_file" ]]; then
        print_status "Loading configuration from $config_file"
        
        # Parse JSON configuration (requires jq)
        if command -v jq &> /dev/null; then
            DEVELOPER_ID_APPLICATION=$(jq -r '.developerIdApplication // empty' "$config_file")
            DEVELOPER_ID_INSTALLER=$(jq -r '.developerIdInstaller // empty' "$config_file")
            TEAM_ID=$(jq -r '.teamId // empty' "$config_file")
            KEYCHAIN_PROFILE=$(jq -r '.keychainProfile // empty' "$config_file")
            APPLE_ID=$(jq -r '.appleId // empty' "$config_file")
            NOTARIZATION_TEAM_ID=$(jq -r '.notarizationTeamId // empty' "$config_file")
        else
            print_warning "jq not found, using environment variables"
        fi
    else
        print_warning "Configuration file not found, using environment variables"
    fi
    
    # Use environment variables as fallback
    DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-$CODESIGN_DEVELOPER_ID_APPLICATION}"
    DEVELOPER_ID_INSTALLER="${DEVELOPER_ID_INSTALLER:-$CODESIGN_DEVELOPER_ID_INSTALLER}"
    TEAM_ID="${TEAM_ID:-$CODESIGN_TEAM_ID}"
    KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-$NOTARIZATION_KEYCHAIN_PROFILE}"
    APPLE_ID="${APPLE_ID:-$NOTARIZATION_APPLE_ID}"
    APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-$NOTARIZATION_APP_PASSWORD}"
    NOTARIZATION_TEAM_ID="${NOTARIZATION_TEAM_ID:-$NOTARIZATION_TEAM_ID}"
    
    # Validate required configuration
    if [[ -z "$DEVELOPER_ID_APPLICATION" ]]; then
        print_warning "Developer ID Application certificate not specified"
        print_warning "Code signing will use ad-hoc signatures"
    fi
    
    if [[ -z "$APPLE_ID" ]] || [[ -z "$APP_SPECIFIC_PASSWORD" ]]; then
        print_warning "Apple ID or App-Specific Password not specified"
        print_warning "Notarization will be skipped"
    fi
}

# Function to create configuration template
create_config_template() {
    local config_file="$PROJECT_ROOT/Scripts/codesign_config.json"
    
    if [[ ! -f "$config_file" ]]; then
        print_status "Creating configuration template at $config_file"
        
        cat > "$config_file" << 'EOF'
{
  "developerIdApplication": "Developer ID Application: Your Name (TEAM_ID)",
  "developerIdInstaller": "Developer ID Installer: Your Name (TEAM_ID)",
  "teamId": "YOUR_TEAM_ID",
  "keychainProfile": "notarization-profile",
  "appleId": "your.email@example.com",
  "notarizationTeamId": "YOUR_TEAM_ID"
}
EOF
        
        print_warning "Please edit $config_file with your actual signing credentials"
        print_warning "You can also use environment variables instead"
    fi
}

# Function to build the project
build_project() {
    print_header "Building Project"
    
    cd "$PROJECT_ROOT"
    
    print_status "Building release configuration..."
    swift build -c release
    
    print_status "Build completed successfully"
}

# Function to create app bundle structure
create_app_bundle() {
    print_header "Creating App Bundle"
    
    local app_bundle="$DIST_DIR/$APP_NAME.app"
    local contents_dir="$app_bundle/Contents"
    local macos_dir="$contents_dir/MacOS"
    local resources_dir="$contents_dir/Resources"
    
    # Clean and create distribution directory
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"
    
    # Create app bundle structure
    mkdir -p "$macos_dir"
    mkdir -p "$resources_dir"
    
    # Copy executables
    cp "$BUILD_DIR/MenuBarApp" "$macos_dir/$APP_NAME"
    cp "$BUILD_DIR/RecorderDaemon" "$macos_dir/RecorderDaemon"
    
    # Create Info.plist
    create_info_plist "$contents_dir/Info.plist"
    
    # Copy resources (if any)
    if [[ -d "$PROJECT_ROOT/Resources" ]]; then
        cp -R "$PROJECT_ROOT/Resources/"* "$resources_dir/"
    fi
    
    print_status "App bundle created at $app_bundle"
}

# Function to create Info.plist
create_info_plist() {
    local plist_path="$1"
    
    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    
    <key>CFBundleSignature</key>
    <string>????</string>
    
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    
    <key>LSUIElement</key>
    <true/>
    
    <key>NSHighResolutionCapable</key>
    <true/>
    
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    
    <key>NSCameraUsageDescription</key>
    <string>This app requires camera access for screen recording functionality.</string>
    
    <key>NSMicrophoneUsageDescription</key>
    <string>This app requires microphone access for audio recording functionality.</string>
    
    <key>NSScreenCaptureDescription</key>
    <string>This app requires screen recording access to capture and analyze your screen activity.</string>
    
    <key>NSSystemAdministrationUsageDescription</key>
    <string>This app requires system administration access to install and manage the recording daemon.</string>
</dict>
</plist>
EOF
}

# Function to sign the app bundle
sign_app_bundle() {
    print_header "Code Signing"
    
    local app_bundle="$DIST_DIR/$APP_NAME.app"
    
    if [[ -z "$DEVELOPER_ID_APPLICATION" ]]; then
        print_warning "No Developer ID specified, using ad-hoc signing"
        
        # Sign with ad-hoc signature
        codesign --force --deep --sign - "$app_bundle"
        
        print_status "Ad-hoc signing completed"
        return
    fi
    
    print_status "Signing with Developer ID: $DEVELOPER_ID_APPLICATION"
    
    # Sign all executables first
    find "$app_bundle" -type f -perm +111 -exec codesign --force --options runtime --sign "$DEVELOPER_ID_APPLICATION" {} \;
    
    # Sign the app bundle
    codesign --force --deep --options runtime --sign "$DEVELOPER_ID_APPLICATION" "$app_bundle"
    
    # Verify signature
    if codesign --verify --deep --strict "$app_bundle"; then
        print_status "Code signing completed successfully"
    else
        print_error "Code signing verification failed"
        exit 1
    fi
    
    # Display signature information
    print_status "Signature information:"
    codesign --display --verbose=2 "$app_bundle"
}

# Function to create installer package
create_installer_package() {
    print_header "Creating Installer Package"
    
    local app_bundle="$DIST_DIR/$APP_NAME.app"
    local pkg_path="$DIST_DIR/$APP_NAME.pkg"
    local scripts_dir="$DIST_DIR/scripts"
    
    # Create scripts directory
    mkdir -p "$scripts_dir"
    
    # Create preinstall script
    cat > "$scripts_dir/preinstall" << 'EOF'
#!/bin/bash
# Stop any running instances
launchctl unload -w "$HOME/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist" 2>/dev/null || true
exit 0
EOF
    
    # Create postinstall script
    cat > "$scripts_dir/postinstall" << 'EOF'
#!/bin/bash
# Set up LaunchAgent and permissions
/Applications/Always-On\ AI\ Companion.app/Contents/MacOS/RecorderDaemon --install
exit 0
EOF
    
    chmod +x "$scripts_dir/preinstall"
    chmod +x "$scripts_dir/postinstall"
    
    # Build the package
    pkgbuild --root "$DIST_DIR" \
             --identifier "$BUNDLE_ID.pkg" \
             --version "1.0.0" \
             --install-location "/Applications" \
             --scripts "$scripts_dir" \
             "$pkg_path"
    
    # Sign the package if installer certificate is available
    if [[ -n "$DEVELOPER_ID_INSTALLER" ]]; then
        print_status "Signing installer package..."
        productsign --sign "$DEVELOPER_ID_INSTALLER" "$pkg_path" "$pkg_path.signed"
        mv "$pkg_path.signed" "$pkg_path"
        
        print_status "Installer package signed successfully"
    else
        print_warning "No installer certificate specified, package is unsigned"
    fi
    
    print_status "Installer package created at $pkg_path"
}

# Function to create DMG
create_dmg() {
    print_header "Creating DMG"
    
    local app_bundle="$DIST_DIR/$APP_NAME.app"
    local dmg_path="$DIST_DIR/$APP_NAME.dmg"
    local temp_dmg="$DIST_DIR/temp.dmg"
    local mount_point="/tmp/$APP_NAME-dmg"
    
    # Calculate size needed
    local size=$(du -sm "$app_bundle" | cut -f1)
    size=$((size + 50)) # Add 50MB padding
    
    # Create temporary DMG
    hdiutil create -size "${size}m" -fs HFS+ -volname "$APP_NAME" "$temp_dmg"
    
    # Mount the DMG
    hdiutil attach "$temp_dmg" -mountpoint "$mount_point"
    
    # Copy app to DMG
    cp -R "$app_bundle" "$mount_point/"
    
    # Create Applications symlink
    ln -s /Applications "$mount_point/Applications"
    
    # Unmount the DMG
    hdiutil detach "$mount_point"
    
    # Convert to compressed DMG
    hdiutil convert "$temp_dmg" -format UDZO -o "$dmg_path"
    
    # Clean up
    rm "$temp_dmg"
    
    print_status "DMG created at $dmg_path"
}

# Function to notarize the app
notarize_app() {
    print_header "Notarization"
    
    if [[ -z "$APPLE_ID" ]] || [[ -z "$APP_SPECIFIC_PASSWORD" ]]; then
        print_warning "Apple ID or App-Specific Password not specified, skipping notarization"
        return
    fi
    
    local app_bundle="$DIST_DIR/$APP_NAME.app"
    local zip_path="$DIST_DIR/$APP_NAME.zip"
    
    # Create zip for notarization
    print_status "Creating zip for notarization..."
    cd "$DIST_DIR"
    zip -r "$APP_NAME.zip" "$APP_NAME.app"
    cd - > /dev/null
    
    # Submit for notarization
    print_status "Submitting for notarization..."
    
    # Try notarytool first (Xcode 13+)
    if xcrun notarytool --help &> /dev/null; then
        if [[ -n "$KEYCHAIN_PROFILE" ]]; then
            # Use keychain profile
            local request_id=$(xcrun notarytool submit "$zip_path" --keychain-profile "$KEYCHAIN_PROFILE" --wait --output-format json | jq -r '.id')
        else
            # Use credentials directly
            local request_id=$(xcrun notarytool submit "$zip_path" --apple-id "$APPLE_ID" --password "$APP_SPECIFIC_PASSWORD" --team-id "$NOTARIZATION_TEAM_ID" --wait --output-format json | jq -r '.id')
        fi
        
        if [[ "$request_id" != "null" ]] && [[ -n "$request_id" ]]; then
            print_status "Notarization completed with ID: $request_id"
            
            # Staple the notarization
            xcrun stapler staple "$app_bundle"
            print_status "Notarization stapled to app bundle"
        else
            print_error "Notarization failed"
            exit 1
        fi
    else
        # Fallback to altool (deprecated but still works)
        print_warning "Using deprecated altool for notarization"
        
        xcrun altool --notarize-app \
                     --primary-bundle-id "$BUNDLE_ID" \
                     --username "$APPLE_ID" \
                     --password "$APP_SPECIFIC_PASSWORD" \
                     --file "$zip_path"
        
        print_status "Notarization submitted (check status manually with altool)"
    fi
    
    # Clean up zip
    rm "$zip_path"
}

# Function to validate the final product
validate_distribution() {
    print_header "Validation"
    
    local app_bundle="$DIST_DIR/$APP_NAME.app"
    
    # Verify code signature
    print_status "Verifying code signature..."
    if codesign --verify --deep --strict "$app_bundle"; then
        print_status "✅ Code signature is valid"
    else
        print_error "❌ Code signature verification failed"
    fi
    
    # Check notarization status
    print_status "Checking notarization status..."
    if xcrun stapler validate "$app_bundle" &> /dev/null; then
        print_status "✅ Notarization is valid"
    else
        print_warning "⚠️  Notarization not found or invalid"
    fi
    
    # Verify Gatekeeper acceptance
    print_status "Testing Gatekeeper acceptance..."
    if spctl --assess --type execute "$app_bundle" &> /dev/null; then
        print_status "✅ Gatekeeper will accept this app"
    else
        print_warning "⚠️  Gatekeeper may reject this app"
    fi
    
    # Display final information
    print_status "Distribution files created:"
    ls -la "$DIST_DIR"
}

# Function to clean up
cleanup() {
    print_header "Cleanup"
    
    # Remove temporary files but keep distribution artifacts
    find "$DIST_DIR" -name "*.zip" -delete 2>/dev/null || true
    find "$DIST_DIR" -name "scripts" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_status "Cleanup completed"
}

# Main execution
main() {
    print_header "Always-On AI Companion - Code Signing and Notarization"
    
    # Parse command line arguments
    local skip_build=false
    local skip_notarization=false
    local create_pkg=false
    local create_dmg_file=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                skip_build=true
                shift
                ;;
            --skip-notarization)
                skip_notarization=true
                shift
                ;;
            --create-pkg)
                create_pkg=true
                shift
                ;;
            --create-dmg)
                create_dmg_file=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Execute steps
    check_prerequisites
    load_configuration
    create_config_template
    
    if [[ "$skip_build" != true ]]; then
        build_project
    fi
    
    create_app_bundle
    sign_app_bundle
    
    if [[ "$create_pkg" == true ]]; then
        create_installer_package
    fi
    
    if [[ "$create_dmg_file" == true ]]; then
        create_dmg
    fi
    
    if [[ "$skip_notarization" != true ]]; then
        notarize_app
    fi
    
    validate_distribution
    cleanup
    
    print_status "🎉 Code signing and distribution completed successfully!"
}

# Function to print usage
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --skip-build         Skip the build step
    --skip-notarization  Skip notarization
    --create-pkg         Create installer package
    --create-dmg         Create DMG file
    --help, -h           Show this help message

Environment Variables:
    CODESIGN_DEVELOPER_ID_APPLICATION    Developer ID Application certificate
    CODESIGN_DEVELOPER_ID_INSTALLER      Developer ID Installer certificate
    CODESIGN_TEAM_ID                     Apple Developer Team ID
    NOTARIZATION_KEYCHAIN_PROFILE        Keychain profile for notarization
    NOTARIZATION_APPLE_ID                Apple ID for notarization
    NOTARIZATION_APP_PASSWORD            App-specific password
    NOTARIZATION_TEAM_ID                 Team ID for notarization

Examples:
    $0                                   # Full build, sign, and notarize
    $0 --skip-build                      # Sign existing build
    $0 --skip-notarization               # Build and sign only
    $0 --create-pkg --create-dmg         # Create all distribution formats

EOF
}

# Run main function
main "$@"