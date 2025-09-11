# Always-On AI Companion

A comprehensive system that continuously records, analyzes, summarizes, and archives all user activity across multiple monitors and applications on macOS.

## Project Structure

```
AlwaysOnAICompanion/
├── Package.swift                           # Swift Package Manager configuration
├── AlwaysOnAICompanion.xcodeproj/         # Xcode project files
├── Sources/
│   ├── RecorderDaemon/                     # Background recording daemon
│   │   └── RecorderDaemon.swift
│   ├── MenuBarApp/                         # Menu bar control application
│   │   ├── MenuBarApp.swift
│   │   ├── MenuBarController.swift
│   │   └── Info.plist
│   └── Shared/                             # Shared modules
│       ├── Shared.swift                    # Main shared module
│       ├── Recording/                      # Screen capture and recording
│       │   ├── ScreenCaptureManager.swift
│       │   └── SegmentManager.swift
│       ├── Encoding/                       # Video encoding
│       │   └── VideoEncoder.swift
│       └── Management/                     # System management
│           ├── ConfigurationManager.swift
│           ├── RecoveryManager.swift
│           └── LaunchAgentManager.swift
├── Tests/
│   └── AlwaysOnAICompanionTests.swift
└── README.md
```

## Architecture

The system is built with a modular architecture consisting of:

### Core Components

1. **RecorderDaemon** - Background service that handles continuous screen recording
2. **MenuBarApp** - User interface for system control and monitoring
3. **Shared Modules** - Common functionality used by both applications

### Shared Modules

- **Recording**: ScreenCaptureKit-based multi-monitor capture and segment management
- **Encoding**: H.264 video encoding with VideoToolbox
- **Management**: Configuration, recovery, and system integration

## Features Implemented

### ✅ Task 1: Project Structure and Core Foundation

- [x] Xcode project with proper targets for recorder daemon and menu bar app
- [x] Swift Package Manager dependencies for ScreenCaptureKit and VideoToolbox
- [x] Basic project structure with separate modules for recording, encoding, and management
- [x] Configuration management system using JSON files

### ✅ Task 5: LaunchAgent for Automatic System Startup

- [x] LaunchAgent plist configuration for background daemon startup
- [x] LaunchAgentManager for installation and management of system service
- [x] Proper permission handling for screen recording and accessibility access
- [x] Installation script that sets up all required system permissions
- [x] Automatic startup behavior across system reboots

### Key Components Created

1. **ScreenCaptureManager**: Multi-monitor capture using ScreenCaptureKit
2. **VideoEncoder**: H.264 encoding with VideoToolbox and faststart support
3. **SegmentManager**: 2-minute segment creation and file organization
4. **ConfigurationManager**: JSON-based configuration system
5. **RecoveryManager**: Automatic crash recovery within 5 seconds
6. **LaunchAgentManager**: System startup integration
7. **MenuBarController**: User interface for system control

## Requirements Addressed

- **Requirement 1.1**: ScreenCaptureKit-based multi-monitor capture
- **Requirement 1.4**: LaunchAgent for automatic system startup with proper permission handling

## Configuration

The system uses JSON-based configuration stored in:
```
~/Library/Application Support/AlwaysOnAICompanion/config.json
```

Default configuration includes:
- 30 FPS capture at 1920x1080
- 3 Mbps target bitrate
- 2-minute segment duration
- 8% max CPU usage target
- 30-day data retention
- Privacy controls and PII masking

## Building and Running

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Screen Recording permission
- Accessibility permission (for full functionality)

### Build Commands

```bash
# Build the entire project
swift build

# Build specific targets
swift build --target RecorderDaemon
swift build --target MenuBarApp
swift build --target LaunchAgentInstaller

# Run tests
swift test
```

### Installation and Setup

#### Quick Setup
```bash
# Install as system service
./Scripts/install.sh

# Check status
./Scripts/status.sh

# Uninstall
./Scripts/uninstall.sh
```

#### Manual Setup
```bash
# Install LaunchAgent
swift run LaunchAgentInstaller

# Check status and permissions
swift run LaunchAgentInstaller --status

# Request permissions
swift run LaunchAgentInstaller --permissions

# Uninstall
swift run LaunchAgentInstaller --uninstall
```

### Xcode Development

Open `AlwaysOnAICompanion.xcodeproj` in Xcode to develop with full IDE support.

## System Integration

The LaunchAgent system provides:
- Automatic startup on macOS boot
- Crash recovery and restart within 5 seconds
- Proper system permissions handling
- Background process management
- Comprehensive monitoring and logging

See `Scripts/README.md` for detailed LaunchAgent documentation.

## Next Steps

This foundation enables the implementation of subsequent tasks:

- Task 6: Rust-based keyframe indexer service
- Task 7: Scene change detection with SSIM and pHash
- Task 8: Parquet-based frame metadata storage
- Task 9: Apple Vision OCR processing engine

The modular architecture ensures clean separation of concerns and enables parallel development of different system components.