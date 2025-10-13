# Always-On AI Companion - Deployment Guide

This document provides comprehensive instructions for deploying, installing, and distributing the Always-On AI Companion system.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Build Process](#build-process)
3. [Code Signing and Notarization](#code-signing-and-notarization)
4. [Installation System](#installation-system)
5. [Distribution Methods](#distribution-methods)
6. [Validation and Testing](#validation-and-testing)
7. [Troubleshooting](#troubleshooting)

## System Requirements

### Minimum Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (arm64) or Intel (x86_64)
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 2GB available space for installation, additional space for recordings
- **Development**: Xcode 15+ or Xcode Command Line Tools

### Supported Configurations

- **macOS Versions**: 14.0, 14.1, 14.2, 14.3, 14.4+
- **Hardware**: MacBook Pro, MacBook Air, iMac, Mac Studio, Mac Pro
- **Multi-Monitor**: Up to 6 displays supported
- **Network**: No network requirements for core functionality

## Build Process

### Development Build

```bash
# Clone the repository
git clone <repository-url>
cd AlwaysOnAICompanion

# Set up development environment
make dev-setup

# Build debug version
make debug

# Run tests
make test
```

### Release Build

```bash
# Build release version
make build

# Run comprehensive tests
make test
make integration-test

# Validate installation requirements
make validate-install
```

### Build Artifacts

After a successful build, the following artifacts are created:

- `.build/release/RecorderDaemon` - Background recording service
- `.build/release/MenuBarApp` - Menu bar control application
- `.build/release/LaunchAgentInstaller` - Installation helper

## Code Signing and Notarization

### Prerequisites

1. **Apple Developer Account**: Required for distribution outside the Mac App Store
2. **Developer ID Certificates**:
   - Developer ID Application (for app signing)
   - Developer ID Installer (for package signing)
3. **App-Specific Password**: For notarization

### Configuration

Create a code signing configuration file:

```bash
# Create configuration template
make codesign-config

# Edit Scripts/codesign_config.json with your credentials
```

Example configuration:

```json
{
  "developerIdApplication": "Developer ID Application: Your Name (TEAM_ID)",
  "developerIdInstaller": "Developer ID Installer: Your Name (TEAM_ID)",
  "teamId": "YOUR_TEAM_ID",
  "keychainProfile": "notarization-profile",
  "appleId": "your.email@example.com",
  "notarizationTeamId": "YOUR_TEAM_ID"
}
```

### Environment Variables (Alternative)

```bash
export CODESIGN_DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM_ID)"
export CODESIGN_DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAM_ID)"
export CODESIGN_TEAM_ID="YOUR_TEAM_ID"
export NOTARIZATION_KEYCHAIN_PROFILE="notarization-profile"
export NOTARIZATION_APPLE_ID="your.email@example.com"
export NOTARIZATION_APP_PASSWORD="app-specific-password"
export NOTARIZATION_TEAM_ID="YOUR_TEAM_ID"
```

### Signing Process

```bash
# Sign and notarize
make sign

# Create signed installer package
make package

# Create signed DMG
make dmg

# Create complete distribution
make dist
```

### Notarization Setup

1. **Create App-Specific Password**:
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Sign in and go to Security section
   - Generate an app-specific password

2. **Store Credentials in Keychain** (Recommended):
   ```bash
   xcrun notarytool store-credentials "notarization-profile" \
     --apple-id "your.email@example.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "app-specific-password"
   ```

## Installation System

### Automated Installation

The system includes a comprehensive Swift-based installer:

```bash
# Standard installation
make install

# Verbose installation with detailed output
make install-verbose

# Dry run (validation only, no changes)
make install-dry-run
```

### Manual Installation Steps

If automated installation fails, follow these manual steps:

1. **Build the Project**:
   ```bash
   swift build -c release
   ```

2. **Create LaunchAgent**:
   ```bash
   mkdir -p ~/Library/LaunchAgents
   cp Scripts/com.alwaysonai.recorderdaemon.plist ~/Library/LaunchAgents/
   ```

3. **Load LaunchAgent**:
   ```bash
   launchctl load -w ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist
   ```

4. **Grant Permissions**:
   - Open System Preferences > Privacy & Security
   - Grant Screen Recording permission
   - Grant Accessibility permission
   - Optionally grant Full Disk Access

### Installation Validation

```bash
# Validate system requirements
make validate-install

# Check installation status
make status

# Run installation tests
make test-install
```

## Distribution Methods

### 1. Direct Download (Recommended)

Create a signed DMG for direct download:

```bash
make dist
```

This creates:
- `dist/Always-On AI Companion.app` - Application bundle
- `dist/Always-On AI Companion.dmg` - Disk image for distribution
- `dist/Always-On AI Companion.pkg` - Installer package

### 2. Installer Package

Create a standalone installer package:

```bash
make package
```

The installer package includes:
- Pre-installation scripts (stop existing services)
- Post-installation scripts (set up LaunchAgent)
- Proper file permissions and ownership

### 3. App Bundle

Create a standalone app bundle:

```bash
make sign
```

### Distribution Checklist

Before distributing:

- [ ] Code signed with valid Developer ID
- [ ] Successfully notarized by Apple
- [ ] Tested on clean macOS installation
- [ ] Installation validation tests pass
- [ ] Uninstallation works correctly
- [ ] Documentation is up to date

## Validation and Testing

### Pre-Distribution Testing

1. **System Requirements Testing**:
   ```bash
   make test-install
   ```

2. **Installation Testing**:
   ```bash
   # Test on clean system
   make install-dry-run
   make install
   make status
   ```

3. **Functionality Testing**:
   ```bash
   make integration-test
   ```

4. **Uninstallation Testing**:
   ```bash
   make uninstall-keep-data
   make install  # Reinstall
   make uninstall
   ```

### Compatibility Testing

Test on multiple macOS versions and hardware configurations:

- **macOS 14.0** (minimum supported)
- **macOS 14.4+** (latest)
- **Apple Silicon** (M1, M2, M3)
- **Intel** (x86_64)
- **Single and multi-monitor setups**

### Performance Validation

Ensure the system meets performance requirements:

- CPU usage ≤ 8% during recording
- Memory usage stable over time
- Disk I/O ≤ 20MB/s sustained
- Recovery time ≤ 5 seconds after crashes

## Troubleshooting

### Common Installation Issues

#### 1. Permission Denied Errors

**Problem**: Installation fails with permission errors.

**Solution**:
```bash
# Check file permissions
ls -la Scripts/
chmod +x Scripts/*.sh Scripts/*.swift

# Run with verbose output
make install-verbose
```

#### 2. Code Signing Failures

**Problem**: Code signing fails or certificates not found.

**Solutions**:
- Verify certificates are installed in Keychain
- Check certificate validity dates
- Ensure Team ID matches certificates
- Use ad-hoc signing for development:
  ```bash
  codesign --force --deep --sign - .build/release/RecorderDaemon
  ```

#### 3. LaunchAgent Won't Load

**Problem**: LaunchAgent fails to load or start.

**Solutions**:
```bash
# Check LaunchAgent status
launchctl list | grep com.alwaysonai

# Validate plist syntax
plutil -lint ~/Library/LaunchAgents/com.alwaysonai.recorderdaemon.plist

# Check logs
tail -f ~/Library/Logs/AlwaysOnAICompanion/stderr.log
```

#### 4. Permission Requests Not Appearing

**Problem**: System doesn't prompt for screen recording permissions.

**Solutions**:
- Reset TCC database (requires restart):
  ```bash
  sudo tccutil reset ScreenCapture
  ```
- Manually add to System Preferences > Privacy & Security
- Check executable path in TCC database

#### 5. Build Failures

**Problem**: Swift build fails with dependency errors.

**Solutions**:
```bash
# Clean and rebuild
make clean
swift package reset
swift package resolve
make build

# Check Swift version
swift --version

# Update Xcode Command Line Tools
xcode-select --install
```

### System Information

Get detailed system information for troubleshooting:

```bash
make system-info
```

### Log Files

Check log files for detailed error information:

- **Installation logs**: `/tmp/alwaysonai_install_*.log`
- **Runtime logs**: `~/Library/Logs/AlwaysOnAICompanion/`
- **System logs**: Console.app (search for "alwaysonai")

### Support Information

When reporting issues, include:

1. **System Information**:
   ```bash
   make system-info
   ```

2. **Installation Log**:
   ```bash
   make install-dry-run --verbose
   ```

3. **Runtime Status**:
   ```bash
   make status
   ```

4. **Error Logs**:
   - Installation logs from `/tmp/`
   - Runtime logs from `~/Library/Logs/AlwaysOnAICompanion/`

## Security Considerations

### Code Signing

- Always use valid Developer ID certificates for distribution
- Never distribute unsigned binaries
- Verify signatures before distribution:
  ```bash
  codesign --verify --deep --strict dist/Always-On\ AI\ Companion.app
  ```

### Notarization

- All distributed binaries must be notarized
- Test notarization status:
  ```bash
  xcrun stapler validate dist/Always-On\ AI\ Companion.app
  ```

### Privacy

- Clearly document required permissions
- Provide opt-out mechanisms for data collection
- Implement secure data storage with encryption
- Follow Apple's privacy guidelines

## Deployment Automation

### CI/CD Pipeline

Example GitHub Actions workflow:

```yaml
name: Build and Deploy

on:
  push:
    tags: ['v*']

jobs:
  build-and-deploy:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up environment
        run: make dev-setup
        
      - name: Build
        run: make build
        
      - name: Test
        run: make test
        
      - name: Sign and notarize
        env:
          CODESIGN_DEVELOPER_ID_APPLICATION: ${{ secrets.DEVELOPER_ID_APPLICATION }}
          NOTARIZATION_APPLE_ID: ${{ secrets.APPLE_ID }}
          NOTARIZATION_APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
        run: make dist
        
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: distribution
          path: dist/
```

### Release Process

1. **Version Bump**: Update version numbers in code and documentation
2. **Testing**: Run full test suite on multiple configurations
3. **Build**: Create signed and notarized distribution
4. **Validation**: Test installation on clean systems
5. **Release**: Upload to distribution channels
6. **Documentation**: Update release notes and documentation

## Maintenance

### Regular Tasks

- **Certificate Renewal**: Monitor certificate expiration dates
- **Dependency Updates**: Keep Swift packages up to date
- **Security Updates**: Apply macOS security updates promptly
- **Testing**: Regular compatibility testing with new macOS versions

### Monitoring

- **Installation Success Rates**: Track installation failures
- **Performance Metrics**: Monitor system resource usage
- **Error Reporting**: Collect and analyze crash reports
- **User Feedback**: Monitor support channels for issues

This deployment guide ensures reliable, secure, and user-friendly distribution of the Always-On AI Companion system across various macOS configurations.