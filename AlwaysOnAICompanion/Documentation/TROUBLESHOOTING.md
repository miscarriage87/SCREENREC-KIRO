# Always-On AI Companion - Troubleshooting Guide

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Installation Issues](#installation-issues)
3. [Recording Problems](#recording-problems)
4. [Performance Issues](#performance-issues)
5. [OCR and Analysis Problems](#ocr-and-analysis-problems)
6. [Privacy and Security Issues](#privacy-and-security-issues)
7. [Storage and Data Issues](#storage-and-data-issues)
8. [Plugin Problems](#plugin-problems)
9. [System Integration Issues](#system-integration-issues)
10. [Advanced Troubleshooting](#advanced-troubleshooting)

## Quick Diagnostics

### System Health Check

Run the comprehensive system diagnostic:

```bash
# Navigate to the application directory
cd /Applications/AlwaysOnAICompanion.app/Contents/Resources/Scripts

# Run full system diagnostic
./diagnose.sh --comprehensive

# Quick health check
./diagnose.sh --quick
```

### Status Verification

```bash
# Check if all services are running
./status.sh --all

# Check specific components
./status.sh --recorder
./status.sh --indexer
./status.sh --ocr
./status.sh --events
```

### Log Analysis

```bash
# View recent system logs
tail -f ~/.alwaysonaicompanion/logs/system.log

# Check for errors in the last hour
grep -i error ~/.alwaysonaicompanion/logs/*.log | grep "$(date -v-1H '+%Y-%m-%d %H')"

# View component-specific logs
tail -f ~/.alwaysonaicompanion/logs/recorder.log
tail -f ~/.alwaysonaicompanion/logs/ocr.log
tail -f ~/.alwaysonaicompanion/logs/events.log
```

## Installation Issues

### Permission Problems

#### Screen Recording Permission Not Granted

**Symptoms**:
- "Permission Denied" errors in logs
- Recording status shows "Not Recording"
- Menu bar app shows red warning icon

**Solutions**:

1. **Manual Permission Grant**:
   ```
   System Settings → Privacy & Security → Screen Recording
   → Add "Always-On AI Companion" and enable
   ```

2. **Reset Permissions**:
   ```bash
   # Reset all privacy permissions
   sudo tccutil reset ScreenCapture
   sudo tccutil reset Accessibility
   
   # Restart the application
   killall "Always-On AI Companion"
   open -a "Always-On AI Companion"
   ```

3. **Verify Permission Status**:
   ```bash
   ./Scripts/check-permissions.sh --verbose
   ```

#### Accessibility Permission Issues

**Symptoms**:
- Hotkeys not working
- Cannot detect window titles
- Application context missing in logs

**Solutions**:

1. **Grant Accessibility Permission**:
   ```
   System Settings → Privacy & Security → Accessibility
   → Add "Always-On AI Companion" and enable
   ```

2. **Test Accessibility Features**:
   ```bash
   ./Scripts/test-accessibility.sh
   ```

### LaunchAgent Installation Problems

#### Service Not Starting Automatically

**Symptoms**:
- Application doesn't start on login
- No background recording after restart
- LaunchAgent not loaded

**Solutions**:

1. **Reinstall LaunchAgent**:
   ```bash
   # Unload existing agent
   launchctl unload ~/Library/LaunchAgents/com.yourorg.alwaysonaicompanion.plist
   
   # Remove old plist
   rm ~/Library/LaunchAgents/com.yourorg.alwaysonaicompanion.plist
   
   # Reinstall
   ./Scripts/install.sh --launchagent-only
   ```

2. **Verify LaunchAgent Status**:
   ```bash
   # Check if loaded
   launchctl list | grep com.yourorg.alwaysonaicompanion
   
   # Check plist syntax
   plutil -lint ~/Library/LaunchAgents/com.yourorg.alwaysonaicompanion.plist
   ```

3. **Manual LaunchAgent Load**:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.yourorg.alwaysonaicompanion.plist
   launchctl start com.yourorg.alwaysonaicompanion
   ```

### Code Signing and Notarization Issues

#### "App is damaged" Error

**Symptoms**:
- macOS prevents app from opening
- "App is damaged and can't be opened" message
- Gatekeeper blocking execution

**Solutions**:

1. **Bypass Gatekeeper (Development Only)**:
   ```bash
   sudo spctl --master-disable
   # Re-enable after testing: sudo spctl --master-enable
   ```

2. **Remove Quarantine Attribute**:
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/AlwaysOnAICompanion.app
   ```

3. **Verify Code Signature**:
   ```bash
   codesign -vvv --deep --strict /Applications/AlwaysOnAICompanion.app
   spctl -a -vvv /Applications/AlwaysOnAICompanion.app
   ```

## Recording Problems

### Recording Not Starting

#### ScreenCaptureKit Session Failures

**Symptoms**:
- "Failed to start capture session" in logs
- Menu bar shows "Error" status
- No video segments being created

**Diagnostic Steps**:

1. **Check Display Configuration**:
   ```bash
   # List available displays
   ./Scripts/list-displays.sh
   
   # Test capture on each display
   ./Scripts/test-capture.sh --display 1
   ./Scripts/test-capture.sh --display 2
   ```

2. **Verify System Resources**:
   ```bash
   # Check CPU usage
   top -l 1 | grep "CPU usage"
   
   # Check memory availability
   vm_stat | grep "Pages free"
   
   # Check disk space
   df -h ~/.alwaysonaicompanion/data
   ```

**Solutions**:

1. **Restart ScreenCaptureKit**:
   ```bash
   # Kill existing capture processes
   sudo pkill -f ScreenCaptureKit
   
   # Restart recorder daemon
   launchctl stop com.yourorg.alwaysonaicompanion
   launchctl start com.yourorg.alwaysonaicompanion
   ```

2. **Reduce Capture Quality**:
   ```bash
   # Edit configuration to reduce load
   ./Scripts/configure.sh --quality balanced --fps 15
   ```

3. **Single Display Mode**:
   ```bash
   # Temporarily record only primary display
   ./Scripts/configure.sh --displays primary-only
   ```

### Multi-Monitor Issues

#### Secondary Displays Not Recording

**Symptoms**:
- Only primary display being recorded
- Missing segments for external monitors
- Partial screen capture in reports

**Solutions**:

1. **Verify Display Detection**:
   ```bash
   # Check detected displays
   ./Scripts/list-displays.sh --detailed
   
   # Test individual display capture
   ./Scripts/test-capture.sh --display-id 69733382
   ```

2. **Update Display Configuration**:
   ```bash
   # Reconfigure for all displays
   ./Scripts/configure.sh --displays all --refresh-config
   ```

3. **Check Display Permissions**:
   ```bash
   # Some displays may require additional permissions
   ./Scripts/check-display-permissions.sh
   ```

### Video Encoding Problems

#### H.264 Encoding Failures

**Symptoms**:
- "Encoding failed" errors in logs
- Corrupted or missing video segments
- High CPU usage during encoding

**Solutions**:

1. **Check VideoToolbox Availability**:
   ```bash
   # Test hardware encoding support
   ./Scripts/test-encoding.sh --hardware
   
   # Fallback to software encoding if needed
   ./Scripts/configure.sh --encoding software
   ```

2. **Adjust Encoding Settings**:
   ```bash
   # Reduce bitrate and quality
   ./Scripts/configure.sh --bitrate 2000000 --quality medium
   ```

3. **Monitor Encoding Performance**:
   ```bash
   # Real-time encoding stats
   ./Scripts/monitor-encoding.sh --realtime
   ```

## Performance Issues

### High CPU Usage

#### CPU Usage Above 15%

**Symptoms**:
- System becomes sluggish
- Fan noise increases
- Battery drains quickly on laptops

**Diagnostic Steps**:

1. **Identify CPU Bottlenecks**:
   ```bash
   # Monitor CPU usage by component
   ./Scripts/performance-monitor.sh --cpu --breakdown
   
   # Check for runaway processes
   ps aux | grep -E "(recorder|indexer|ocr)" | sort -k3 -nr
   ```

2. **Analyze Performance Logs**:
   ```bash
   # Check performance metrics
   grep "CPU usage" ~/.alwaysonaicompanion/logs/performance.log | tail -20
   ```

**Solutions**:

1. **Optimize Recording Settings**:
   ```bash
   # Reduce frame rate
   ./Scripts/configure.sh --fps 15
   
   # Lower resolution
   ./Scripts/configure.sh --resolution 1080p
   
   # Reduce monitored displays
   ./Scripts/configure.sh --displays primary-only
   ```

2. **Adjust Processing Intervals**:
   ```bash
   # Increase OCR processing interval
   ./Scripts/configure.sh --ocr-interval 5s
   
   # Reduce event detection frequency
   ./Scripts/configure.sh --event-detection-interval 10s
   ```

3. **Enable Performance Mode**:
   ```bash
   # Switch to performance-optimized settings
   ./Scripts/configure.sh --profile performance
   ```

### Memory Issues

#### High Memory Usage

**Symptoms**:
- Memory usage above 1GB
- System swap usage increases
- Out of memory errors in logs

**Solutions**:

1. **Monitor Memory Usage**:
   ```bash
   # Check memory usage by component
   ./Scripts/performance-monitor.sh --memory --detailed
   ```

2. **Optimize Memory Settings**:
   ```bash
   # Reduce buffer sizes
   ./Scripts/configure.sh --buffer-size small
   
   # Enable aggressive garbage collection
   ./Scripts/configure.sh --gc-aggressive true
   ```

3. **Clear Memory Caches**:
   ```bash
   # Clear processing caches
   ./Scripts/clear-caches.sh --memory
   
   # Restart services to free memory
   ./Scripts/restart-services.sh --memory-cleanup
   ```

### Storage Performance

#### Slow Disk I/O

**Symptoms**:
- Delayed segment creation
- High disk usage in Activity Monitor
- "Storage bottleneck" warnings in logs

**Solutions**:

1. **Check Disk Performance**:
   ```bash
   # Test write performance
   ./Scripts/test-disk-performance.sh --write
   
   # Check available space
   df -h ~/.alwaysonaicompanion/data
   ```

2. **Optimize Storage Settings**:
   ```bash
   # Move data to faster storage
   ./Scripts/migrate-data.sh --destination /Volumes/FastSSD/AICompanion
   
   # Enable compression
   ./Scripts/configure.sh --compression enabled
   ```

3. **Clean Up Old Data**:
   ```bash
   # Aggressive cleanup
   ./Scripts/cleanup.sh --aggressive --older-than 7d
   ```

## OCR and Analysis Problems

### OCR Not Working

#### Apple Vision OCR Failures

**Symptoms**:
- No text detected in clear screenshots
- Empty OCR results in reports
- "Vision framework unavailable" errors

**Solutions**:

1. **Test OCR Components**:
   ```bash
   # Test Apple Vision OCR
   ./Scripts/test-ocr.sh --vision --sample-image
   
   # Test Tesseract fallback
   ./Scripts/test-ocr.sh --tesseract --sample-image
   ```

2. **Verify System Requirements**:
   ```bash
   # Check macOS version compatibility
   sw_vers
   
   # Verify Vision framework availability
   ./Scripts/check-frameworks.sh --vision
   ```

3. **Reset OCR Services**:
   ```bash
   # Restart OCR processing
   ./Scripts/restart-services.sh --ocr
   
   # Clear OCR caches
   ./Scripts/clear-caches.sh --ocr
   ```

### Poor OCR Accuracy

#### Low Confidence Scores

**Symptoms**:
- OCR confidence below 70%
- Incorrect text recognition
- Missing text in reports

**Solutions**:

1. **Improve Image Quality**:
   ```bash
   # Increase recording resolution
   ./Scripts/configure.sh --resolution 1440p
   
   # Enable image enhancement
   ./Scripts/configure.sh --image-enhancement enabled
   ```

2. **Adjust OCR Settings**:
   ```bash
   # Use accurate recognition mode
   ./Scripts/configure.sh --ocr-mode accurate
   
   # Enable language correction
   ./Scripts/configure.sh --language-correction enabled
   ```

3. **Configure ROI Detection**:
   ```bash
   # Optimize region of interest detection
   ./Scripts/configure.sh --roi-detection enhanced
   ```

### Event Detection Issues

#### Missing Events

**Symptoms**:
- No field change events detected
- Missing navigation events
- Empty event reports

**Solutions**:

1. **Test Event Detection**:
   ```bash
   # Test with sample data
   ./Scripts/test-event-detection.sh --sample-data
   
   # Verify event detection rules
   ./Scripts/validate-event-rules.sh
   ```

2. **Adjust Detection Sensitivity**:
   ```bash
   # Increase sensitivity
   ./Scripts/configure.sh --event-sensitivity 0.6
   
   # Enable additional event types
   ./Scripts/configure.sh --event-types all
   ```

3. **Check Event Processing Pipeline**:
   ```bash
   # Monitor event processing
   ./Scripts/monitor-events.sh --realtime
   ```

## Privacy and Security Issues

### PII Detection Problems

#### Sensitive Data Not Masked

**Symptoms**:
- Credit card numbers visible in reports
- Personal information in OCR results
- Privacy audit warnings

**Solutions**:

1. **Test PII Detection**:
   ```bash
   # Test PII detection patterns
   ./Scripts/test-pii-detection.sh --comprehensive
   
   # Validate masking rules
   ./Scripts/validate-pii-rules.sh
   ```

2. **Update PII Patterns**:
   ```bash
   # Add custom PII patterns
   ./Scripts/configure-pii.sh --add-pattern "SSN" "\d{3}-\d{2}-\d{4}"
   
   # Enable aggressive PII masking
   ./Scripts/configure.sh --pii-masking aggressive
   ```

3. **Audit Existing Data**:
   ```bash
   # Scan existing data for PII
   ./Scripts/audit-pii.sh --scan-all --fix
   ```

### Hotkey Not Working

#### Privacy Hotkey Unresponsive

**Symptoms**:
- Cmd+Shift+P doesn't pause recording
- No response to emergency hotkey
- Hotkey conflicts with other apps

**Solutions**:

1. **Test Hotkey Registration**:
   ```bash
   # Test hotkey functionality
   ./Scripts/test-hotkeys.sh --all
   
   # Check for conflicts
   ./Scripts/check-hotkey-conflicts.sh
   ```

2. **Reconfigure Hotkeys**:
   ```bash
   # Reset to default hotkeys
   ./Scripts/configure.sh --hotkeys reset
   
   # Set custom hotkeys
   ./Scripts/configure.sh --pause-hotkey "cmd+shift+x"
   ```

3. **Verify Accessibility Permissions**:
   ```bash
   # Hotkeys require accessibility access
   ./Scripts/check-permissions.sh --accessibility
   ```

### Allowlist Not Working

#### Applications Still Being Monitored

**Symptoms**:
- Blocked applications appear in reports
- Allowlist settings not taking effect
- Privacy rules ignored

**Solutions**:

1. **Verify Allowlist Configuration**:
   ```bash
   # Check current allowlist
   ./Scripts/show-allowlist.sh --detailed
   
   # Test allowlist rules
   ./Scripts/test-allowlist.sh --application "com.example.app"
   ```

2. **Update Allowlist Rules**:
   ```bash
   # Add application to blocklist
   ./Scripts/configure-allowlist.sh --block "com.example.app"
   
   # Set allowlist mode
   ./Scripts/configure.sh --allowlist-mode whitelist
   ```

3. **Restart with New Rules**:
   ```bash
   # Apply allowlist changes
   ./Scripts/restart-services.sh --apply-allowlist
   ```

## Storage and Data Issues

### Database Corruption

#### SQLite Database Errors

**Symptoms**:
- "Database is locked" errors
- Corrupted span data
- Unable to query historical data

**Solutions**:

1. **Check Database Integrity**:
   ```bash
   # Check SQLite database
   sqlite3 ~/.alwaysonaicompanion/data/spans.sqlite "PRAGMA integrity_check;"
   
   # Check Parquet files
   ./Scripts/validate-parquet.sh --all
   ```

2. **Repair Database**:
   ```bash
   # Backup current database
   cp ~/.alwaysonaicompanion/data/spans.sqlite ~/.alwaysonaicompanion/data/spans.sqlite.backup
   
   # Repair database
   ./Scripts/repair-database.sh --sqlite
   ```

3. **Restore from Backup**:
   ```bash
   # Restore from automatic backup
   ./Scripts/restore-database.sh --latest-backup
   ```

### Parquet File Issues

#### Corrupted Parquet Files

**Symptoms**:
- "Unable to read parquet file" errors
- Missing frame or OCR data
- Query failures

**Solutions**:

1. **Validate Parquet Files**:
   ```bash
   # Check all parquet files
   ./Scripts/validate-parquet.sh --comprehensive
   
   # Repair corrupted files
   ./Scripts/repair-parquet.sh --auto-fix
   ```

2. **Rebuild Parquet Files**:
   ```bash
   # Rebuild from raw data
   ./Scripts/rebuild-parquet.sh --from-segments
   ```

### Encryption Issues

#### Unable to Decrypt Data

**Symptoms**:
- "Decryption failed" errors
- Unable to access stored data
- Key management errors

**Solutions**:

1. **Check Encryption Keys**:
   ```bash
   # Verify key availability
   ./Scripts/check-encryption.sh --keys
   
   # Test encryption/decryption
   ./Scripts/test-encryption.sh --roundtrip
   ```

2. **Recover Encryption Keys**:
   ```bash
   # Attempt key recovery
   ./Scripts/recover-keys.sh --from-keychain
   
   # Reset encryption (WARNING: Data loss)
   ./Scripts/reset-encryption.sh --confirm
   ```

## Plugin Problems

### Plugin Loading Failures

#### Plugin Won't Load

**Symptoms**:
- "Failed to load plugin" errors
- Plugin not appearing in settings
- Missing plugin functionality

**Solutions**:

1. **Verify Plugin Installation**:
   ```bash
   # List installed plugins
   ./Scripts/list-plugins.sh --detailed
   
   # Validate plugin bundle
   ./Scripts/validate-plugin.sh MyPlugin.bundle
   ```

2. **Check Plugin Dependencies**:
   ```bash
   # Check plugin requirements
   ./Scripts/check-plugin-deps.sh MyPlugin.bundle
   
   # Install missing dependencies
   ./Scripts/install-plugin-deps.sh MyPlugin.bundle
   ```

3. **Reinstall Plugin**:
   ```bash
   # Remove and reinstall plugin
   ./Scripts/uninstall-plugin.sh MyPlugin
   ./Scripts/install-plugin.sh MyPlugin.bundle
   ```

### Plugin Performance Issues

#### Plugin Causing High CPU Usage

**Symptoms**:
- High CPU usage when plugin is enabled
- System slowdown with specific plugins
- Plugin timeout errors

**Solutions**:

1. **Profile Plugin Performance**:
   ```bash
   # Monitor plugin performance
   ./Scripts/profile-plugin.sh MyPlugin --duration 60s
   ```

2. **Adjust Plugin Settings**:
   ```bash
   # Reduce plugin processing frequency
   ./Scripts/configure-plugin.sh MyPlugin --interval 10s
   
   # Disable expensive features
   ./Scripts/configure-plugin.sh MyPlugin --advanced-features false
   ```

3. **Update or Replace Plugin**:
   ```bash
   # Check for plugin updates
   ./Scripts/update-plugin.sh MyPlugin
   
   # Disable problematic plugin
   ./Scripts/disable-plugin.sh MyPlugin
   ```

## System Integration Issues

### macOS Compatibility

#### Issues After macOS Update

**Symptoms**:
- System stops working after OS update
- Permission dialogs reappear
- New security restrictions

**Solutions**:

1. **Re-grant Permissions**:
   ```bash
   # Check permission status after update
   ./Scripts/check-permissions.sh --post-update
   
   # Re-request all permissions
   ./Scripts/request-permissions.sh --all
   ```

2. **Update System Integration**:
   ```bash
   # Update for new macOS version
   ./Scripts/update-system-integration.sh
   
   # Reinstall LaunchAgent if needed
   ./Scripts/reinstall-launchagent.sh
   ```

3. **Check Compatibility**:
   ```bash
   # Verify system compatibility
   ./Scripts/check-compatibility.sh --verbose
   ```

### Third-Party Software Conflicts

#### Conflicts with Other Screen Recording Software

**Symptoms**:
- Recording conflicts with other apps
- Shared resource access errors
- Performance degradation

**Solutions**:

1. **Identify Conflicts**:
   ```bash
   # Check for conflicting software
   ./Scripts/check-conflicts.sh --screen-recording
   
   # List active screen capture processes
   ps aux | grep -i "screen\|capture\|record"
   ```

2. **Configure Exclusive Access**:
   ```bash
   # Enable exclusive capture mode
   ./Scripts/configure.sh --exclusive-capture true
   
   # Set capture priority
   ./Scripts/configure.sh --capture-priority high
   ```

## Advanced Troubleshooting

### Debug Mode

#### Enable Comprehensive Logging

```bash
# Enable debug mode
export DEBUG=1
export VERBOSE_LOGGING=1

# Restart services with debug logging
./Scripts/restart-services.sh --debug

# Monitor debug logs
tail -f ~/.alwaysonaicompanion/logs/debug.log
```

### Performance Profiling

#### System Performance Analysis

```bash
# Run comprehensive performance analysis
./Scripts/performance-analysis.sh --comprehensive --duration 300s

# Generate performance report
./Scripts/generate-performance-report.sh --output ~/Desktop/performance-report.html
```

### Network Diagnostics

#### Cloud Sync Issues

```bash
# Test network connectivity
./Scripts/test-network.sh --cloud-endpoints

# Check sync status
./Scripts/sync-status.sh --detailed

# Force sync retry
./Scripts/force-sync.sh --retry-failed
```

### Recovery Procedures

#### Complete System Reset

**WARNING**: This will delete all data and reset to factory defaults.

```bash
# Create backup before reset
./Scripts/backup.sh --complete --destination ~/Desktop/AICompanion-Backup

# Stop all services
./Scripts/stop-services.sh --all

# Remove all data and configuration
./Scripts/factory-reset.sh --confirm --preserve-backups

# Reinstall system
./Scripts/install.sh --fresh-install
```

### Support Bundle Generation

#### Create Diagnostic Package

```bash
# Generate comprehensive support bundle
./Scripts/generate-support-bundle.sh \
  --include-logs \
  --include-config \
  --include-performance-data \
  --include-system-info \
  --output ~/Desktop/support-bundle-$(date +%Y%m%d).zip

# Upload to support (if available)
./Scripts/upload-support-bundle.sh ~/Desktop/support-bundle-*.zip
```

### Contact Support

If you've exhausted all troubleshooting options:

1. **Generate Support Bundle**: Use the command above
2. **Document Issue**: Include steps to reproduce
3. **System Information**: Include macOS version, hardware specs
4. **Contact Information**:
   - Email: support@yourorg.com
   - GitHub Issues: https://github.com/your-org/AlwaysOnAICompanion/issues
   - Community Forum: https://community.yourorg.com

### Emergency Procedures

#### Complete System Shutdown

If the system is causing severe performance issues:

```bash
# Emergency stop all services
sudo pkill -f "AlwaysOnAICompanion"
sudo pkill -f "recorder"
sudo pkill -f "indexer"

# Unload LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.yourorg.alwaysonaicompanion.plist

# Disable automatic startup
./Scripts/disable-autostart.sh
```

#### Data Recovery

If data appears to be lost:

```bash
# Check for automatic backups
./Scripts/list-backups.sh --all

# Attempt data recovery
./Scripts/recover-data.sh --scan-all --interactive

# Restore from Time Machine (if available)
./Scripts/restore-from-timemachine.sh --interactive
```