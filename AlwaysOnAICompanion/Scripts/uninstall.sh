#!/bin/bash

# Always-On AI Companion Comprehensive Uninstaller
# This script completely removes all system components and data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUNDLE_ID="com.alwaysonai.recorderdaemon"
MENUBAR_BUNDLE_ID="com.alwaysonai.menubar"
LAUNCH_AGENT_NAME="com.alwaysonai.recorderdaemon.plist"
APP_NAME="Always-On AI Companion"

# Paths
HOME_DIR="$HOME"
LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$LAUNCH_AGENT_NAME"
LOG_DIR="$HOME_DIR/Library/Logs/AlwaysOnAICompanion"
CONFIG_DIR="$HOME_DIR/Library/Application Support/AlwaysOnAICompanion"
CACHE_DIR="$HOME_DIR/Library/Caches/AlwaysOnAICompanion"
PREFERENCES_DIR="$HOME_DIR/Library/Preferences"
APPLICATION_DIR="/Applications"

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

# Function to confirm uninstallation
confirm_uninstallation() {
    print_header "Always-On AI Companion Uninstaller"
    echo
    print_warning "This will completely remove Always-On AI Companion from your system."
    print_warning "The following will be removed:"
    echo "  • LaunchAgent and background services"
    echo "  • Application files and executables"
    echo "  • Configuration files and settings"
    echo "  • Log files and cached data"
    echo "  • User preferences"
    echo
    print_warning "Note: Recorded data and videos will be preserved unless explicitly removed."
    echo
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Uninstallation cancelled"
        exit 0
    fi
}

# Function to stop running services
stop_services() {
    print_header "Stopping Services"
    
    # Stop LaunchAgent
    if launchctl list | grep -q "$BUNDLE_ID"; then
        print_status "Stopping RecorderDaemon..."
        if launchctl unload -w "$PLIST_PATH" 2>/dev/null; then
            print_status "RecorderDaemon stopped successfully"
        else
            print_warning "Failed to stop RecorderDaemon (may not be running)"
        fi
    else
        print_status "RecorderDaemon is not running"
    fi
    
    # Stop MenuBar app if running
    if pgrep -f "MenuBarApp" > /dev/null; then
        print_status "Stopping MenuBar application..."
        pkill -f "MenuBarApp" || true
        sleep 2
    fi
    
    # Force kill any remaining processes
    for process in "RecorderDaemon" "MenuBarApp" "AlwaysOnAICompanion"; do
        if pgrep -f "$process" > /dev/null; then
            print_warning "Force killing $process..."
            pkill -9 -f "$process" || true
        fi
    done
    
    print_status "All services stopped"
}

# Function to remove LaunchAgent
remove_launch_agent() {
    print_header "Removing LaunchAgent"
    
    if [[ -f "$PLIST_PATH" ]]; then
        print_status "Removing LaunchAgent plist..."
        rm -f "$PLIST_PATH"
        print_status "LaunchAgent plist removed"
    else
        print_status "LaunchAgent plist not found"
    fi
    
    # Reload launchctl to ensure changes take effect
    launchctl load -w "$LAUNCH_AGENTS_DIR" 2>/dev/null || true
}

# Function to remove application files
remove_application_files() {
    print_header "Removing Application Files"
    
    # Remove from Applications directory
    local app_path="$APPLICATION_DIR/$APP_NAME.app"
    if [[ -d "$app_path" ]]; then
        print_status "Removing application bundle..."
        rm -rf "$app_path"
        print_status "Application bundle removed"
    else
        print_status "Application bundle not found in /Applications"
    fi
    
    # Remove any installer packages
    local pkg_path="$APPLICATION_DIR/$APP_NAME.pkg"
    if [[ -f "$pkg_path" ]]; then
        print_status "Removing installer package..."
        rm -f "$pkg_path"
    fi
}

# Function to remove configuration and data
remove_configuration_data() {
    print_header "Removing Configuration and Data"
    
    # Remove configuration directory
    if [[ -d "$CONFIG_DIR" ]]; then
        print_status "Removing configuration directory..."
        rm -rf "$CONFIG_DIR"
        print_status "Configuration directory removed"
    else
        print_status "Configuration directory not found"
    fi
    
    # Remove cache directory
    if [[ -d "$CACHE_DIR" ]]; then
        print_status "Removing cache directory..."
        rm -rf "$CACHE_DIR"
        print_status "Cache directory removed"
    else
        print_status "Cache directory not found"
    fi
    
    # Remove preferences
    local pref_files=(
        "$PREFERENCES_DIR/com.alwaysonai.companion.plist"
        "$PREFERENCES_DIR/com.alwaysonai.recorderdaemon.plist"
        "$PREFERENCES_DIR/com.alwaysonai.menubar.plist"
    )
    
    for pref_file in "${pref_files[@]}"; do
        if [[ -f "$pref_file" ]]; then
            print_status "Removing preference file: $(basename "$pref_file")"
            rm -f "$pref_file"
        fi
    done
}

# Function to remove log files
remove_log_files() {
    print_header "Removing Log Files"
    
    if [[ -d "$LOG_DIR" ]]; then
        print_status "Removing log directory..."
        rm -rf "$LOG_DIR"
        print_status "Log directory removed"
    else
        print_status "Log directory not found"
    fi
    
    # Remove system logs (if any)
    local system_log_patterns=(
        "/var/log/*alwaysonai*"
        "/var/log/*recorderdaemon*"
    )
    
    for pattern in "${system_log_patterns[@]}"; do
        if ls $pattern 2>/dev/null; then
            print_status "Removing system logs matching: $pattern"
            sudo rm -f $pattern 2>/dev/null || print_warning "Could not remove system logs (permission denied)"
        fi
    done
}

# Function to handle recorded data
handle_recorded_data() {
    print_header "Recorded Data"
    
    # Look for common data directories
    local data_dirs=(
        "$HOME_DIR/Documents/AlwaysOnAICompanion"
        "$HOME_DIR/Movies/AlwaysOnAICompanion"
        "$CONFIG_DIR/data"
        "$CONFIG_DIR/recordings"
    )
    
    local found_data=false
    
    for data_dir in "${data_dirs[@]}"; do
        if [[ -d "$data_dir" ]]; then
            found_data=true
            local size=$(du -sh "$data_dir" 2>/dev/null | cut -f1 || echo "unknown")
            print_warning "Found recorded data: $data_dir ($size)"
        fi
    done
    
    if [[ "$found_data" == true ]]; then
        echo
        print_warning "Recorded data directories were found."
        print_warning "These contain your screen recordings and processed data."
        echo
        read -p "Do you want to remove all recorded data? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for data_dir in "${data_dirs[@]}"; do
                if [[ -d "$data_dir" ]]; then
                    print_status "Removing data directory: $data_dir"
                    rm -rf "$data_dir"
                fi
            done
            print_status "All recorded data removed"
        else
            print_status "Recorded data preserved"
        fi
    else
        print_status "No recorded data directories found"
    fi
}

# Function to clean up system permissions
cleanup_permissions() {
    print_header "Permission Cleanup"
    
    print_warning "System permissions cannot be automatically removed."
    print_warning "You may want to manually remove the following permissions:"
    echo "  1. Open System Preferences > Privacy & Security"
    echo "  2. Go to Screen Recording and remove Always-On AI Companion entries"
    echo "  3. Go to Accessibility and remove Always-On AI Companion entries"
    echo "  4. Go to Full Disk Access and remove Always-On AI Companion entries"
    echo
    
    read -p "Would you like to open System Preferences now? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Opening System Preferences..."
        open "x-apple.systempreferences:com.apple.preference.security?Privacy"
    fi
}

# Function to verify complete removal
verify_removal() {
    print_header "Verification"
    
    local issues_found=false
    
    # Check for remaining processes
    if pgrep -f "AlwaysOnAI\|RecorderDaemon\|MenuBarApp" > /dev/null; then
        print_warning "Some processes are still running"
        issues_found=true
    fi
    
    # Check for remaining files
    local check_paths=(
        "$PLIST_PATH"
        "$CONFIG_DIR"
        "$LOG_DIR"
        "$CACHE_DIR"
        "$APPLICATION_DIR/$APP_NAME.app"
    )
    
    for path in "${check_paths[@]}"; do
        if [[ -e "$path" ]]; then
            print_warning "File/directory still exists: $path"
            issues_found=true
        fi
    done
    
    # Check LaunchAgent status
    if launchctl list | grep -q "$BUNDLE_ID"; then
        print_warning "LaunchAgent is still loaded"
        issues_found=true
    fi
    
    if [[ "$issues_found" == false ]]; then
        print_status "✅ Verification passed - all components removed"
    else
        print_warning "⚠️  Some components may still be present"
    fi
}

# Function to create uninstall log
create_uninstall_log() {
    local log_file="/tmp/alwaysonai_uninstall_$(date +%Y%m%d_%H%M%S).log"
    
    cat > "$log_file" << EOF
Always-On AI Companion Uninstallation Log
Date: $(date)
User: $(whoami)
System: $(uname -a)

Uninstallation completed successfully.

Removed components:
- LaunchAgent: $PLIST_PATH
- Configuration: $CONFIG_DIR
- Logs: $LOG_DIR
- Cache: $CACHE_DIR
- Application: $APPLICATION_DIR/$APP_NAME.app

Note: System permissions may need to be manually removed from System Preferences.
EOF
    
    print_status "Uninstall log created: $log_file"
}

# Main uninstallation function
main() {
    # Parse command line arguments
    local force=false
    local keep_data=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force=true
                shift
                ;;
            --keep-data|-k)
                keep_data=true
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
    
    # Confirm uninstallation unless forced
    if [[ "$force" != true ]]; then
        confirm_uninstallation
    fi
    
    # Execute uninstallation steps
    stop_services
    remove_launch_agent
    remove_application_files
    remove_configuration_data
    remove_log_files
    
    # Handle recorded data unless keeping it
    if [[ "$keep_data" != true ]]; then
        handle_recorded_data
    else
        print_status "Skipping recorded data removal (--keep-data specified)"
    fi
    
    cleanup_permissions
    verify_removal
    create_uninstall_log
    
    print_header "Uninstallation Complete"
    print_status "🎉 Always-On AI Companion has been successfully uninstalled"
    echo
    print_warning "Remember to manually remove system permissions if desired"
}

# Function to print usage
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --force, -f      Skip confirmation prompts
    --keep-data, -k  Preserve recorded data directories
    --help, -h       Show this help message

Examples:
    $0                    # Interactive uninstallation
    $0 --force            # Uninstall without prompts
    $0 --keep-data        # Uninstall but preserve recorded data
    $0 --force --keep-data # Force uninstall but keep data

EOF
}

# Run main function
main "$@"
