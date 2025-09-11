#!/bin/bash

# Always-On AI Companion Installation Script
# This script sets up the LaunchAgent and requests necessary permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUNDLE_ID="com.alwaysonai.recorderdaemon"
LAUNCH_AGENT_NAME="com.alwaysonai.recorderdaemon.plist"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}Always-On AI Companion Installation Script${NC}"
echo "=========================================="

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

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only"
    exit 1
fi

# Check macOS version (requires macOS 14+)
macos_version=$(sw_vers -productVersion)
major_version=$(echo "$macos_version" | cut -d. -f1)
minor_version=$(echo "$macos_version" | cut -d. -f2)

if [[ $major_version -lt 14 ]]; then
    print_error "macOS 14 or later is required. Current version: $macos_version"
    exit 1
fi

print_status "macOS version check passed: $macos_version"

# Check if Xcode command line tools are installed
if ! command -v swift &> /dev/null; then
    print_error "Swift is not installed. Please install Xcode or Xcode Command Line Tools"
    exit 1
fi

print_status "Swift compiler found"

# Build the project
print_status "Building RecorderDaemon..."
cd "$PROJECT_ROOT"

if ! swift build --product RecorderDaemon --configuration release; then
    print_error "Failed to build RecorderDaemon"
    exit 1
fi

print_status "Build completed successfully"

# Check if the executable was created
DAEMON_PATH="$PROJECT_ROOT/.build/release/RecorderDaemon"
if [[ ! -x "$DAEMON_PATH" ]]; then
    print_error "RecorderDaemon executable not found at $DAEMON_PATH"
    exit 1
fi

print_status "RecorderDaemon executable verified"

# Create LaunchAgents directory if it doesn't exist
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Create the LaunchAgent plist
PLIST_PATH="$LAUNCH_AGENTS_DIR/$LAUNCH_AGENT_NAME"
LOG_DIR="$HOME/Library/Logs/AlwaysOnAICompanion"
mkdir -p "$LOG_DIR"

print_status "Creating LaunchAgent plist..."

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$DAEMON_PATH</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$LOG_DIR/stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/stderr.log</string>
    
    <key>WorkingDirectory</key>
    <string>$HOME</string>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>LowPriorityIO</key>
    <true/>
    
    <key>Nice</key>
    <integer>1</integer>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
    
    <key>ExitTimeOut</key>
    <integer>30</integer>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
EOF

# Set proper permissions
chmod 644 "$PLIST_PATH"

print_status "LaunchAgent plist created at $PLIST_PATH"

# Function to check if a permission is granted
check_screen_recording_permission() {
    # This is a simplified check - the actual permission check happens in the Swift code
    # We'll just check if the app is in the TCC database
    local app_path="$DAEMON_PATH"
    local tcc_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
    
    if [[ -f "$tcc_db" ]]; then
        # Try to query the TCC database (this might not work due to SIP)
        sqlite3 "$tcc_db" "SELECT * FROM access WHERE service='kTCCServiceScreenCapture' AND client='$app_path';" 2>/dev/null | grep -q "$app_path"
        return $?
    fi
    
    return 1
}

# Request permissions
print_status "Checking system permissions..."

print_warning "The following permissions are required:"
echo "  1. Screen Recording - Required for capturing screen content"
echo "  2. Accessibility - Required for monitoring system events"
echo "  3. Full Disk Access - Optional but recommended for better performance"
echo ""

read -p "Would you like to open System Preferences to grant these permissions? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Opening System Preferences..."
    
    # Open Screen Recording preferences
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    
    echo ""
    print_warning "Please follow these steps:"
    echo "  1. In the Screen Recording section, click the '+' button"
    echo "  2. Navigate to and select: $DAEMON_PATH"
    echo "  3. Check the box next to the RecorderDaemon entry"
    echo "  4. Go to the Accessibility section and repeat the process"
    echo "  5. Optionally, add the daemon to Full Disk Access as well"
    echo ""
    
    read -p "Press Enter after granting the permissions..."
    
    # Give a moment for the user to grant permissions
    sleep 2
    
    # Open Accessibility preferences
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    
    read -p "Press Enter after granting accessibility permissions..."
fi

# Load the LaunchAgent
print_status "Loading LaunchAgent..."

# Unload first if it's already loaded
launchctl unload -w "$PLIST_PATH" 2>/dev/null || true

# Load the LaunchAgent
if launchctl load -w "$PLIST_PATH"; then
    print_status "LaunchAgent loaded successfully"
else
    print_error "Failed to load LaunchAgent"
    exit 1
fi

# Verify the daemon is running
sleep 3
if launchctl list | grep -q "$BUNDLE_ID"; then
    print_status "RecorderDaemon is running"
else
    print_warning "RecorderDaemon may not be running. Check the logs at $LOG_DIR"
fi

# Create a simple status check script
STATUS_SCRIPT="$PROJECT_ROOT/Scripts/status.sh"
cat > "$STATUS_SCRIPT" << 'EOF'
#!/bin/bash

BUNDLE_ID="com.alwaysonai.recorderdaemon"
LOG_DIR="$HOME/Library/Logs/AlwaysOnAICompanion"

echo "Always-On AI Companion Status"
echo "============================="

if launchctl list | grep -q "$BUNDLE_ID"; then
    echo "✅ RecorderDaemon is running"
else
    echo "❌ RecorderDaemon is not running"
fi

echo ""
echo "Recent logs:"
echo "------------"
if [[ -f "$LOG_DIR/stdout.log" ]]; then
    tail -5 "$LOG_DIR/stdout.log"
else
    echo "No stdout logs found"
fi

if [[ -f "$LOG_DIR/stderr.log" ]]; then
    echo ""
    echo "Recent errors:"
    echo "--------------"
    tail -5 "$LOG_DIR/stderr.log"
fi
EOF

chmod +x "$STATUS_SCRIPT"

# Create an uninstall script
UNINSTALL_SCRIPT="$PROJECT_ROOT/Scripts/uninstall.sh"
cat > "$UNINSTALL_SCRIPT" << EOF
#!/bin/bash

BUNDLE_ID="$BUNDLE_ID"
LAUNCH_AGENT_NAME="$LAUNCH_AGENT_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/\$LAUNCH_AGENT_NAME"

echo "Uninstalling Always-On AI Companion..."

# Unload the LaunchAgent
if launchctl list | grep -q "\$BUNDLE_ID"; then
    echo "Stopping RecorderDaemon..."
    launchctl unload -w "\$PLIST_PATH"
fi

# Remove the plist file
if [[ -f "\$PLIST_PATH" ]]; then
    echo "Removing LaunchAgent plist..."
    rm "\$PLIST_PATH"
fi

echo "Uninstallation completed"
echo "Note: You may want to manually remove permissions from System Preferences > Privacy & Security"
EOF

chmod +x "$UNINSTALL_SCRIPT"

print_status "Installation completed successfully!"
echo ""
echo "Additional scripts created:"
echo "  - Status check: $STATUS_SCRIPT"
echo "  - Uninstall: $UNINSTALL_SCRIPT"
echo ""
echo "The RecorderDaemon will now start automatically on system boot."
echo "You can check its status by running: $STATUS_SCRIPT"
echo ""
print_warning "Important: Make sure you have granted the required permissions in System Preferences!"