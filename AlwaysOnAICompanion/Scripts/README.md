# Always-On AI Companion LaunchAgent Setup

This directory contains scripts and tools for setting up the Always-On AI Companion as a system service that automatically starts on macOS boot.

## Overview

The LaunchAgent system provides:
- Automatic startup of the RecorderDaemon on system boot
- Crash recovery and automatic restart within 5 seconds
- Proper permission handling for screen recording and accessibility
- System integration with macOS LaunchServices
- Comprehensive monitoring and status reporting

## Installation

### Quick Installation

Run the automated installation script:

```bash
./Scripts/install.sh
```

This script will:
1. Build the RecorderDaemon executable
2. Create the LaunchAgent plist configuration
3. Request necessary system permissions
4. Install and load the LaunchAgent
5. Verify the installation

### Manual Installation

If you prefer manual control, use the LaunchAgentInstaller tool:

```bash
# Install the LaunchAgent
swift run LaunchAgentInstaller

# Check status
swift run LaunchAgentInstaller --status

# Check and request permissions
swift run LaunchAgentInstaller --permissions

# Uninstall
swift run LaunchAgentInstaller --uninstall
```

## System Requirements

- macOS 14.0 or later
- Swift 5.9 or later
- Xcode Command Line Tools

## Required Permissions

The system requires the following macOS permissions:

### Screen Recording (Required)
- Allows capturing screen content across all displays
- Required for the core functionality
- Granted in: System Preferences > Privacy & Security > Screen Recording

### Accessibility (Required)
- Allows monitoring system events and window information
- Required for context detection
- Granted in: System Preferences > Privacy & Security > Accessibility

### Full Disk Access (Optional)
- Improves performance and reliability
- Recommended but not strictly required
- Granted in: System Preferences > Privacy & Security > Full Disk Access

## LaunchAgent Configuration

The LaunchAgent is configured with the following properties:

```xml
<key>RunAtLoad</key>
<true/>

<key>KeepAlive</key>
<dict>
    <key>SuccessfulExit</key>
    <false/>
    <key>Crashed</key>
    <true/>
</dict>

<key>ThrottleInterval</key>
<integer>10</integer>

<key>ProcessType</key>
<string>Background</string>
```

This ensures:
- Automatic startup on system boot
- Automatic restart if the daemon crashes
- Throttled restart to prevent rapid restart loops
- Background process priority for minimal system impact

## Monitoring and Management

### Status Checking

Check the current status of the system:

```bash
# Using the status script
./Scripts/status.sh

# Using the installer tool
swift run LaunchAgentInstaller --status
```

### Log Files

System logs are stored in:
- `~/Library/Logs/AlwaysOnAICompanion/stdout.log` - Standard output
- `~/Library/Logs/AlwaysOnAICompanion/stderr.log` - Error messages

### Manual Control

Control the daemon manually using launchctl:

```bash
# Check if loaded
launchctl list | grep com.alwaysonai.recorderdaemon

# Load the LaunchAgent
launchctl load -w ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist

# Unload the LaunchAgent
launchctl unload -w ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist
```

## Uninstallation

### Quick Uninstall

```bash
./Scripts/uninstall.sh
```

### Manual Uninstall

```bash
# Stop the daemon
launchctl unload -w ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist

# Remove the plist file
rm ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist
```

**Note:** After uninstalling, you may want to manually remove the granted permissions from System Preferences > Privacy & Security.

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Ensure all required permissions are granted in System Preferences
   - Try running the installer again after granting permissions

2. **Daemon Not Starting**
   - Check the error logs: `cat ~/Library/Logs/AlwaysOnAICompanion/stderr.log`
   - Verify the executable exists and is executable
   - Check system console for additional error messages

3. **Build Failures**
   - Ensure Xcode Command Line Tools are installed: `xcode-select --install`
   - Verify Swift version: `swift --version`
   - Clean and rebuild: `swift package clean && swift build`

4. **LaunchAgent Not Loading**
   - Check plist syntax: `plutil ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist`
   - Verify file permissions: `ls -la ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist`
   - Check system logs: `log show --predicate 'subsystem == "com.apple.launchd"' --last 1h`

### Debug Mode

For debugging, you can run the daemon manually:

```bash
# Build in debug mode
swift build --product RecorderDaemon

# Run manually
./.build/debug/RecorderDaemon
```

This allows you to see real-time output and debug any issues.

### Performance Monitoring

Monitor system impact:

```bash
# Check CPU usage
top -pid $(pgrep RecorderDaemon)

# Check memory usage
ps -o pid,rss,vsz,comm -p $(pgrep RecorderDaemon)

# Monitor file handles
lsof -p $(pgrep RecorderDaemon)
```

## Security Considerations

- The daemon runs with user-level privileges (not root)
- All data is stored locally with optional encryption
- Network access is not required for core functionality
- Permissions can be revoked at any time through System Preferences

## Integration with Menu Bar App

The LaunchAgent works seamlessly with the Menu Bar application:
- The Menu Bar app can start/stop the daemon
- Status is synchronized between components
- Settings changes are automatically applied

## Development and Testing

For development purposes:

```bash
# Build and test
swift test

# Build specific target
swift build --product RecorderDaemon

# Run tests for LaunchAgent functionality
swift test --filter LaunchAgentManagerTests
```

## File Locations

- **LaunchAgent plist**: `~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist`
- **Executable**: `.build/release/RecorderDaemon` (or debug version)
- **Logs**: `~/Library/Logs/AlwaysOnAICompanion/`
- **Configuration**: `~/.config/AlwaysOnAICompanion/` (if used)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the log files for error messages
3. Verify all system requirements are met
4. Ensure all required permissions are granted