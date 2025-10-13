# Always-On AI Companion - User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [Initial Setup](#initial-setup)
5. [Using the Menu Bar App](#using-the-menu-bar-app)
6. [Privacy Controls](#privacy-controls)
7. [Configuration](#configuration)
8. [Data Management](#data-management)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

## Introduction

The Always-On AI Companion is a comprehensive system that continuously records, analyzes, and summarizes your screen activity across multiple monitors. It provides an AI companion with complete context of your activities through stable background recording, intelligent content analysis, and structured knowledge storage.

### Key Features

- **Multi-Monitor Recording**: Captures all connected displays simultaneously
- **Intelligent Analysis**: OCR text extraction and event detection
- **Privacy First**: Local processing with comprehensive privacy controls
- **Activity Summaries**: Automated reports and workflow documentation
- **Plugin Architecture**: Extensible parsing for specialized applications

## System Requirements

### Minimum Requirements
- macOS 14.0 (Sonoma) or later
- 8GB RAM
- 50GB available storage
- Screen Recording permission
- Accessibility permission

### Recommended Requirements
- macOS 15.0 (Sequoia) or later
- 16GB RAM
- 200GB available storage (for extended retention)
- Apple Silicon Mac (for optimal performance)

### Supported Hardware
- Intel Macs (2019 or later)
- Apple Silicon Macs (M1, M2, M3 series)
- Multiple monitor configurations supported

## Installation

### Automated Installation

1. **Download the Installer**
   - Download `AlwaysOnAICompanion-Installer.pkg` from the releases page
   - Verify the digital signature (signed by your organization)

2. **Run the Installer**
   ```bash
   sudo installer -pkg AlwaysOnAICompanion-Installer.pkg -target /
   ```

3. **Grant Permissions**
   - The installer will prompt for Screen Recording permission
   - Grant Accessibility permission when requested
   - Allow the LaunchAgent to run in the background

### Manual Installation

If you prefer manual installation or need to troubleshoot:

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-org/AlwaysOnAICompanion.git
   cd AlwaysOnAICompanion
   ```

2. **Build the Project**
   ```bash
   make build
   ```

3. **Install System Components**
   ```bash
   sudo make install
   ```

4. **Set Up LaunchAgent**
   ```bash
   ./Scripts/install.sh
   ```

### Verification

After installation, verify the system is working:

```bash
# Check if the daemon is running
launchctl list | grep com.yourorg.alwaysonaicompanion

# Verify menu bar app
ps aux | grep MenuBarApp

# Check system status
./Scripts/status.sh
```

## Initial Setup

### First Launch

1. **Launch Menu Bar App**
   - The menu bar app should start automatically after installation
   - Look for the AI Companion icon in your menu bar
   - If not visible, launch manually from Applications folder

2. **Initial Configuration Wizard**
   - Select which displays to monitor
   - Configure recording quality settings
   - Set up privacy preferences
   - Choose data retention policies

3. **Permission Verification**
   - Verify Screen Recording permission is granted
   - Confirm Accessibility permission is active
   - Test hotkey functionality

### Display Configuration

Configure which displays to monitor:

1. **Open Settings** from the menu bar app
2. **Navigate to Display Settings**
3. **Select Monitors**:
   - Check displays you want to monitor
   - Configure quality settings per display
   - Set up display-specific privacy rules

### Quality Settings

Optimize recording quality based on your needs:

- **High Quality**: 1440p@30fps (recommended for detailed analysis)
- **Balanced**: 1080p@30fps (good balance of quality and performance)
- **Performance**: 720p@15fps (minimal system impact)

## Using the Menu Bar App

### Main Interface

The menu bar app provides quick access to all system functions:

#### Status Display
- **Recording Status**: Green dot = recording, Red dot = paused
- **Performance Metrics**: CPU usage, memory consumption
- **Storage Usage**: Available space and retention status

#### Quick Actions
- **Pause/Resume**: Instantly pause or resume recording
- **Privacy Mode**: Enable temporary privacy protection
- **Settings**: Access configuration options
- **Reports**: View recent activity summaries

### Recording Controls

#### Start/Stop Recording
```
Click menu bar icon → Toggle Recording
Hotkey: Cmd+Shift+R (configurable)
```

#### Pause Recording
```
Click menu bar icon → Pause
Hotkey: Cmd+Shift+P (default)
Emergency hotkey: Cmd+Shift+Esc
```

#### Privacy Mode
```
Click menu bar icon → Privacy Mode
Hotkey: Cmd+Shift+H
```

### Status Monitoring

Monitor system health through the menu bar interface:

- **CPU Usage**: Should remain below 8% during normal operation
- **Memory Usage**: Typical usage 200-500MB
- **Storage**: Monitor available space and cleanup recommendations
- **Error Count**: Track any system errors or warnings

## Privacy Controls

### Immediate Privacy Protection

#### Pause Hotkey
The system responds to pause requests within 100ms:
- **Default Hotkey**: `Cmd+Shift+P`
- **Emergency Hotkey**: `Cmd+Shift+Esc`
- **Menu Bar**: Click icon → Pause

#### Privacy Mode
Temporarily disable all monitoring:
- **Activation**: `Cmd+Shift+H` or menu bar
- **Visual Indicator**: Menu bar icon changes to privacy mode
- **Auto-Resume**: Configurable timeout or manual resume

### Application Allowlists

Control which applications are monitored:

1. **Open Settings** → **Privacy** → **Application Allowlist**
2. **Add Applications**:
   - Click "+" to add applications
   - Browse and select applications to monitor
   - Set per-application recording rules

3. **Configure Rules**:
   - **Always Monitor**: Record all activity in this app
   - **Never Monitor**: Exclude this app completely
   - **Conditional**: Monitor based on window titles or content

### Screen-Specific Privacy

Configure privacy settings per display:

1. **Open Settings** → **Privacy** → **Display Settings**
2. **Per-Display Rules**:
   - Set different privacy levels per monitor
   - Configure sensitive screen detection
   - Set up automatic privacy triggers

### PII Protection

The system automatically detects and masks sensitive information:

- **Credit Card Numbers**: Automatically masked in OCR
- **Social Security Numbers**: Detected and filtered
- **Email Addresses**: Configurable masking
- **Phone Numbers**: Pattern-based detection
- **Custom Patterns**: Add your own sensitive data patterns

## Configuration

### Settings Overview

Access settings through: Menu Bar → Settings

#### General Settings
- **Startup Behavior**: Auto-start on login
- **Recording Quality**: Per-display quality settings
- **Performance Limits**: CPU and memory thresholds
- **Update Preferences**: Automatic update settings

#### Privacy Settings
- **PII Detection**: Configure sensitive data patterns
- **Allowlists**: Manage application and screen allowlists
- **Hotkeys**: Customize privacy and control hotkeys
- **Audit Logging**: Privacy action logging

#### Storage Settings
- **Data Location**: Choose storage directory
- **Retention Policies**: Configure data lifecycle
- **Encryption**: Manage encryption settings
- **Backup**: Configure backup preferences

#### Plugin Settings
- **Available Plugins**: Enable/disable parsing plugins
- **Plugin Configuration**: Configure plugin-specific settings
- **Custom Plugins**: Install third-party plugins

### Advanced Configuration

#### Configuration Files

The system uses JSON configuration files:

```
~/.alwaysonaicompanion/
├── config.json          # Main configuration
├── privacy.json         # Privacy settings
├── plugins.json         # Plugin configuration
└── retention.json       # Data retention policies
```

#### Example Configuration

```json
{
  "recording": {
    "quality": "high",
    "frameRate": 30,
    "displays": ["main", "secondary"],
    "maxCpuUsage": 8.0
  },
  "privacy": {
    "pauseHotkey": "cmd+shift+p",
    "emergencyHotkey": "cmd+shift+esc",
    "piiMasking": true,
    "allowlistMode": "whitelist"
  },
  "storage": {
    "dataPath": "~/.alwaysonaicompanion/data",
    "retentionDays": 30,
    "encryptionEnabled": true
  }
}
```

### Hotkey Customization

Customize system hotkeys:

1. **Open Settings** → **Hotkeys**
2. **Available Hotkeys**:
   - Pause/Resume Recording
   - Privacy Mode Toggle
   - Emergency Stop
   - Settings Access
   - Report Generation

3. **Set Custom Combinations**:
   - Click on hotkey field
   - Press desired key combination
   - Verify no conflicts with system hotkeys

## Data Management

### Storage Structure

The system organizes data in a structured hierarchy:

```
~/.alwaysonaicompanion/data/
├── segments/           # Video segments (H.264)
├── frames/            # Frame metadata (Parquet)
├── ocr/              # OCR results (Parquet)
├── events/           # Detected events (Parquet)
├── spans/            # Activity spans (SQLite)
└── reports/          # Generated reports
```

### Data Retention

Configure automatic data cleanup:

#### Retention Policies
- **Raw Video**: 14-30 days (configurable)
- **Frame Metadata**: 90 days
- **OCR Data**: 90 days
- **Events**: 1 year
- **Summaries**: Permanent (unless manually deleted)

#### Manual Cleanup
```bash
# Clean old video segments
./Scripts/cleanup.sh --videos --older-than 30d

# Clean all data older than specified date
./Scripts/cleanup.sh --all --before 2024-01-01

# Clean specific data types
./Scripts/cleanup.sh --ocr --events --older-than 90d
```

### Data Export

Export your data in various formats:

#### Through Menu Bar App
1. **Click Menu Bar Icon** → **Reports** → **Export Data**
2. **Select Date Range** and **Data Types**
3. **Choose Export Format**: JSON, CSV, or Markdown
4. **Select Destination** and click **Export**

#### Command Line Export
```bash
# Export activity summary for date range
./Scripts/export.sh --summary --from 2024-01-01 --to 2024-01-31 --format markdown

# Export raw events as CSV
./Scripts/export.sh --events --from 2024-01-15 --format csv

# Export complete dataset
./Scripts/export.sh --all --format json --output ~/my-data-export.json
```

### Backup and Restore

#### Automatic Backup
Configure automatic backups:
1. **Settings** → **Storage** → **Backup**
2. **Enable Automatic Backup**
3. **Set Backup Location** (external drive recommended)
4. **Configure Backup Schedule** (daily/weekly)

#### Manual Backup
```bash
# Backup all data
./Scripts/backup.sh --all --destination /Volumes/Backup/AICompanion

# Backup configuration only
./Scripts/backup.sh --config --destination ~/Desktop/config-backup
```

#### Restore from Backup
```bash
# Restore complete system
./Scripts/restore.sh --source /Volumes/Backup/AICompanion --all

# Restore configuration only
./Scripts/restore.sh --source ~/Desktop/config-backup --config
```

## Troubleshooting

### Common Issues

#### Recording Not Starting

**Symptoms**: Menu bar shows "Not Recording" status

**Solutions**:
1. **Check Permissions**:
   ```bash
   # Verify screen recording permission
   ./Scripts/check-permissions.sh
   ```

2. **Restart Services**:
   ```bash
   # Restart the recorder daemon
   launchctl unload ~/Library/LaunchAgents/com.yourorg.alwaysonaicompanion.plist
   launchctl load ~/Library/LaunchAgents/com.yourorg.alwaysonaicompanion.plist
   ```

3. **Check System Resources**:
   - Ensure sufficient disk space (>10GB free)
   - Verify CPU usage is not at 100%
   - Check memory availability

#### High CPU Usage

**Symptoms**: System becomes slow, CPU usage >15%

**Solutions**:
1. **Reduce Recording Quality**:
   - Settings → Recording → Quality → "Balanced" or "Performance"
   - Reduce frame rate to 15fps

2. **Limit Monitored Displays**:
   - Disable monitoring for secondary displays
   - Focus on primary display only

3. **Check for Conflicts**:
   ```bash
   # Check for other screen recording software
   ps aux | grep -i screen
   ps aux | grep -i record
   ```

#### OCR Not Working

**Symptoms**: No text detected in reports, empty OCR results

**Solutions**:
1. **Verify OCR Services**:
   ```bash
   # Test Apple Vision OCR
   ./Scripts/test-ocr.sh --vision
   
   # Test Tesseract fallback
   ./Scripts/test-ocr.sh --tesseract
   ```

2. **Check Image Quality**:
   - Increase recording resolution
   - Ensure good contrast on screen
   - Check for display scaling issues

3. **Restart OCR Services**:
   ```bash
   # Restart processing pipeline
   ./Scripts/restart-services.sh --ocr
   ```

#### Storage Issues

**Symptoms**: "Storage Full" warnings, slow performance

**Solutions**:
1. **Check Disk Usage**:
   ```bash
   # Check data directory size
   du -sh ~/.alwaysonaicompanion/data/
   
   # Check retention policy status
   ./Scripts/status.sh --storage
   ```

2. **Manual Cleanup**:
   ```bash
   # Clean old segments
   ./Scripts/cleanup.sh --videos --older-than 14d
   
   # Aggressive cleanup
   ./Scripts/cleanup.sh --all --older-than 7d
   ```

3. **Adjust Retention Policies**:
   - Settings → Storage → Retention
   - Reduce retention periods
   - Enable aggressive cleanup

### Performance Optimization

#### System Performance

1. **Monitor Resource Usage**:
   ```bash
   # Check system performance
   ./Scripts/performance-check.sh
   
   # Monitor in real-time
   ./Scripts/monitor.sh --realtime
   ```

2. **Optimize Settings**:
   - **Recording Quality**: Use "Balanced" for most users
   - **Frame Rate**: 15fps sufficient for most analysis
   - **Display Count**: Monitor only essential displays

3. **Hardware Recommendations**:
   - **SSD Storage**: Significantly improves performance
   - **16GB+ RAM**: Recommended for multi-display setups
   - **Apple Silicon**: Better performance than Intel Macs

#### Network Performance

If using cloud sync features:

1. **Bandwidth Management**:
   - Schedule sync during off-hours
   - Limit upload bandwidth
   - Use compression for uploads

2. **Sync Optimization**:
   - Sync summaries only, not raw data
   - Use incremental sync
   - Configure sync priorities

### Log Analysis

#### Accessing Logs

```bash
# View recent logs
tail -f ~/.alwaysonaicompanion/logs/system.log

# Search for errors
grep -i error ~/.alwaysonaicompanion/logs/*.log

# View specific component logs
tail -f ~/.alwaysonaicompanion/logs/recorder.log
tail -f ~/.alwaysonaicompanion/logs/ocr.log
tail -f ~/.alwaysonaicompanion/logs/events.log
```

#### Common Log Messages

**Normal Operation**:
```
[INFO] Recording started on display 1
[INFO] Segment created: segment_20240115_143022.mp4
[INFO] OCR processed 45 frames, 234 text regions detected
```

**Warnings**:
```
[WARN] High CPU usage detected: 12.3%
[WARN] Low disk space: 8.2GB remaining
[WARN] OCR confidence low for frame 12345
```

**Errors**:
```
[ERROR] Screen capture session failed: Permission denied
[ERROR] Failed to write segment: Disk full
[ERROR] OCR service unavailable, using fallback
```

### Getting Help

#### Built-in Diagnostics

```bash
# Run comprehensive system check
./Scripts/diagnose.sh

# Generate support bundle
./Scripts/support-bundle.sh --output ~/Desktop/support-bundle.zip
```

#### Community Support

- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Check online documentation for updates
- **Community Forum**: Ask questions and share tips

#### Professional Support

For enterprise users:
- **Email Support**: support@yourorg.com
- **Priority Support**: Available with enterprise licenses
- **Custom Integration**: Professional services available

## FAQ

### General Questions

**Q: How much storage space does the system use?**
A: Typical usage is 2-5GB per day depending on activity level and quality settings. With default 30-day retention, expect 60-150GB total usage.

**Q: Can I use this on multiple computers?**
A: Yes, each computer needs its own installation. Data can be synchronized between systems if desired.

**Q: Does this work with external monitors?**
A: Yes, the system supports multiple external monitors and can record them simultaneously.

### Privacy Questions

**Q: Is my data sent to the cloud?**
A: No, all processing happens locally on your Mac. Cloud sync is optional and user-controlled.

**Q: How secure is my data?**
A: All data is encrypted at rest using AES-GCM encryption. Encryption keys are stored securely in macOS Keychain.

**Q: Can I exclude specific applications?**
A: Yes, use the allowlist feature to control which applications are monitored.

### Technical Questions

**Q: Why does the system use so much CPU?**
A: Multi-display recording and real-time analysis are CPU-intensive. Reduce quality settings or monitored displays to improve performance.

**Q: Can I run this on older Macs?**
A: The system requires macOS 14+ and works best on 2019 or newer hardware. Older systems may experience performance issues.

**Q: How accurate is the OCR?**
A: Apple Vision OCR typically achieves 95%+ accuracy on clear text. Tesseract fallback provides additional coverage for challenging text.

### Troubleshooting Questions

**Q: The menu bar app disappeared, how do I get it back?**
A: Launch it manually from Applications folder or run: `open -a "Always-On AI Companion"`

**Q: Recording stopped working after a macOS update**
A: Re-grant Screen Recording permission in System Settings → Privacy & Security → Screen Recording.

**Q: How do I completely uninstall the system?**
A: Run the uninstaller: `sudo ./Scripts/uninstall.sh --complete`