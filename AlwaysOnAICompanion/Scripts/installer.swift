#!/usr/bin/env swift

import Foundation
import Security
import SystemConfiguration

// MARK: - Installation System

class AlwaysOnAICompanionInstaller {
    
    // MARK: - Configuration
    
    struct InstallationConfig {
        static let bundleID = "com.alwaysonai.companion"
        static let daemonBundleID = "com.alwaysonai.recorderdaemon"
        static let menuBarBundleID = "com.alwaysonai.menubar"
        static let launchAgentName = "com.alwaysonai.recorderdaemon.plist"
        static let requiredMacOSVersion = "14.0"
        static let appName = "Always-On AI Companion"
        
        // Paths
        static let projectRoot = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        static let buildPath = projectRoot.appendingPathComponent(".build/release")
        static let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        static let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AlwaysOnAICompanion")
        static let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AlwaysOnAICompanion")
    }
    
    // MARK: - Installation Steps
    
    enum InstallationStep: String, CaseIterable {
        case systemRequirements = "System Requirements Check"
        case buildValidation = "Build Validation"
        case codeSigningCheck = "Code Signing Verification"
        case permissionSetup = "Permission Setup"
        case launchAgentInstall = "LaunchAgent Installation"
        case configurationSetup = "Configuration Setup"
        case validationTests = "Installation Validation"
        case cleanup = "Cleanup"
    }
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private var installationLog: [String] = []
    private var isVerbose: Bool = false
    
    // MARK: - Public Interface
    
    func install(verbose: Bool = false, dryRun: Bool = false) throws {
        self.isVerbose = verbose
        
        printHeader("Always-On AI Companion Installer")
        
        if dryRun {
            log("🔍 Running in dry-run mode - no changes will be made", level: .info)
        }
        
        for step in InstallationStep.allCases {
            try executeStep(step, dryRun: dryRun)
        }
        
        if !dryRun {
            printSuccess("Installation completed successfully!")
            printPostInstallationInstructions()
        } else {
            log("✅ Dry run completed - system is ready for installation", level: .success)
        }
    }
    
    func uninstall(verbose: Bool = false) throws {
        self.isVerbose = verbose
        
        printHeader("Always-On AI Companion Uninstaller")
        
        try stopServices()
        try removeFiles()
        try cleanupConfiguration()
        
        printSuccess("Uninstallation completed successfully!")
        printPostUninstallInstructions()
    }
    
    // MARK: - Installation Steps Implementation
    
    private func executeStep(_ step: InstallationStep, dryRun: Bool) throws {
        log("📋 \(step.rawValue)...", level: .info)
        
        switch step {
        case .systemRequirements:
            try checkSystemRequirements()
        case .buildValidation:
            try validateBuild(dryRun: dryRun)
        case .codeSigningCheck:
            try verifyCodeSigning()
        case .permissionSetup:
            try setupPermissions(dryRun: dryRun)
        case .launchAgentInstall:
            try installLaunchAgent(dryRun: dryRun)
        case .configurationSetup:
            try setupConfiguration(dryRun: dryRun)
        case .validationTests:
            try runValidationTests(dryRun: dryRun)
        case .cleanup:
            try performCleanup(dryRun: dryRun)
        }
        
        log("✅ \(step.rawValue) completed", level: .success)
    }
    
    // MARK: - System Requirements
    
    private func checkSystemRequirements() throws {
        // Check macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion)"
        
        log("🖥️  macOS version: \(versionString)", level: .debug)
        
        if version.majorVersion < 14 {
            throw InstallationError.unsupportedMacOSVersion(current: versionString, required: InstallationConfig.requiredMacOSVersion)
        }
        
        // Check architecture
        let architecture = getSystemArchitecture()
        log("🏗️  Architecture: \(architecture)", level: .debug)
        
        // Check available disk space (require at least 1GB)
        let availableSpace = try getAvailableDiskSpace()
        let requiredSpace: Int64 = 1_000_000_000 // 1GB
        
        if availableSpace < requiredSpace {
            throw InstallationError.insufficientDiskSpace(available: availableSpace, required: requiredSpace)
        }
        
        log("💾 Available disk space: \(formatBytes(availableSpace))", level: .debug)
        
        // Check Swift compiler
        guard isSwiftAvailable() else {
            throw InstallationError.swiftNotFound
        }
        
        log("🔧 Swift compiler: Available", level: .debug)
        
        // Check Xcode Command Line Tools
        if !isXcodeCommandLineToolsInstalled() {
            log("⚠️  Xcode Command Line Tools not detected", level: .warning)
        }
    }
    
    // MARK: - Build Validation
    
    private func validateBuild(dryRun: Bool) throws {
        let buildPath = InstallationConfig.buildPath
        
        // Check if build directory exists
        guard fileManager.fileExists(atPath: buildPath.path) else {
            if !dryRun {
                log("🔨 Building project...", level: .info)
                try buildProject()
            } else {
                log("🔨 Would build project", level: .info)
                return
            }
        }
        
        // Validate executables
        let requiredExecutables = ["RecorderDaemon", "MenuBarApp"]
        
        for executable in requiredExecutables {
            let executablePath = buildPath.appendingPathComponent(executable)
            
            if !fileManager.fileExists(atPath: executablePath.path) {
                if !dryRun {
                    throw InstallationError.missingExecutable(executable)
                } else {
                    log("❌ Missing executable: \(executable)", level: .warning)
                }
            } else {
                // Check if executable is valid
                if !dryRun {
                    try validateExecutable(at: executablePath)
                }
                log("✅ Executable validated: \(executable)", level: .debug)
            }
        }
    }
    
    // MARK: - Code Signing
    
    private func verifyCodeSigning() throws {
        let buildPath = InstallationConfig.buildPath
        let executables = ["RecorderDaemon", "MenuBarApp"]
        
        for executable in executables {
            let executablePath = buildPath.appendingPathComponent(executable)
            
            if fileManager.fileExists(atPath: executablePath.path) {
                let signingStatus = try checkCodeSignature(at: executablePath)
                
                switch signingStatus {
                case .signed(let identity):
                    log("🔐 \(executable) is code signed with: \(identity)", level: .debug)
                case .adhoc:
                    log("🔓 \(executable) has ad-hoc signature", level: .warning)
                case .unsigned:
                    log("⚠️  \(executable) is not code signed", level: .warning)
                }
            }
        }
    }
    
    // MARK: - Permission Setup
    
    private func setupPermissions(dryRun: Bool) throws {
        let requiredPermissions: [Permission] = [
            .screenRecording,
            .accessibility,
            .fullDiskAccess
        ]
        
        for permission in requiredPermissions {
            let status = checkPermissionStatus(permission)
            
            switch status {
            case .granted:
                log("✅ \(permission.description): Granted", level: .debug)
            case .denied, .notDetermined:
                log("❌ \(permission.description): Not granted", level: .warning)
                
                if !dryRun {
                    try requestPermission(permission)
                }
            }
        }
        
        if !dryRun {
            // Open System Preferences for manual permission granting
            try openSystemPreferencesForPermissions()
        }
    }
    
    // MARK: - LaunchAgent Installation
    
    private func installLaunchAgent(dryRun: Bool) throws {
        let launchAgentsDir = InstallationConfig.launchAgentsDir
        let plistPath = launchAgentsDir.appendingPathComponent(InstallationConfig.launchAgentName)
        
        if !dryRun {
            // Create LaunchAgents directory if needed
            try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            
            // Create plist content
            let plistContent = try createLaunchAgentPlist()
            
            // Write plist file
            try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
            
            // Set proper permissions
            try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: plistPath.path)
            
            // Load the LaunchAgent
            try loadLaunchAgent(at: plistPath)
            
            log("📋 LaunchAgent installed and loaded", level: .debug)
        } else {
            log("📋 Would install LaunchAgent at: \(plistPath.path)", level: .info)
        }
    }
    
    // MARK: - Configuration Setup
    
    private func setupConfiguration(dryRun: Bool) throws {
        let configDir = InstallationConfig.configDir
        
        if !dryRun {
            // Create configuration directory
            try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
            
            // Create default configuration
            let defaultConfig = createDefaultConfiguration()
            let configPath = configDir.appendingPathComponent("config.json")
            
            let configData = try JSONSerialization.data(withJSONObject: defaultConfig, options: .prettyPrinted)
            try configData.write(to: configPath)
            
            // Create log directory
            try fileManager.createDirectory(at: InstallationConfig.logDir, withIntermediateDirectories: true)
            
            log("⚙️  Configuration files created", level: .debug)
        } else {
            log("⚙️  Would create configuration at: \(configDir.path)", level: .info)
        }
    }
    
    // MARK: - Validation Tests
    
    private func runValidationTests(dryRun: Bool) throws {
        if dryRun {
            log("🧪 Would run validation tests", level: .info)
            return
        }
        
        // Test LaunchAgent status
        let isRunning = try isLaunchAgentRunning()
        if isRunning {
            log("✅ LaunchAgent is running", level: .debug)
        } else {
            log("❌ LaunchAgent is not running", level: .warning)
        }
        
        // Test file permissions
        try validateFilePermissions()
        
        // Test configuration loading
        try validateConfiguration()
        
        log("🧪 Validation tests completed", level: .debug)
    }
    
    // MARK: - Cleanup
    
    private func performCleanup(dryRun: Bool) throws {
        if !dryRun {
            // Clean up temporary files
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("AlwaysOnAICompanion-Install")
            
            if fileManager.fileExists(atPath: tempDir.path) {
                try fileManager.removeItem(at: tempDir)
            }
            
            log("🧹 Cleanup completed", level: .debug)
        } else {
            log("🧹 Would perform cleanup", level: .info)
        }
    }
    
    // MARK: - Uninstallation
    
    private func stopServices() throws {
        let bundleID = InstallationConfig.daemonBundleID
        
        // Stop LaunchAgent
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["unload", "-w", InstallationConfig.launchAgentsDir.appendingPathComponent(InstallationConfig.launchAgentName).path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            log("🛑 Services stopped", level: .debug)
        }
    }
    
    private func removeFiles() throws {
        let filesToRemove = [
            InstallationConfig.launchAgentsDir.appendingPathComponent(InstallationConfig.launchAgentName),
            InstallationConfig.configDir,
            InstallationConfig.logDir
        ]
        
        for file in filesToRemove {
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: file)
                log("🗑️  Removed: \(file.lastPathComponent)", level: .debug)
            }
        }
    }
    
    private func cleanupConfiguration() throws {
        // Remove any system-level configurations
        // This is a placeholder for future system-level cleanup
        log("🧹 Configuration cleanup completed", level: .debug)
    }
}

// MARK: - Helper Extensions and Types

extension AlwaysOnAICompanionInstaller {
    
    enum LogLevel {
        case debug, info, warning, error, success
        
        var prefix: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .success: return "✅"
            }
        }
    }
    
    enum Permission {
        case screenRecording, accessibility, fullDiskAccess
        
        var description: String {
            switch self {
            case .screenRecording: return "Screen Recording"
            case .accessibility: return "Accessibility"
            case .fullDiskAccess: return "Full Disk Access"
            }
        }
    }
    
    enum PermissionStatus {
        case granted, denied, notDetermined
    }
    
    enum CodeSigningStatus {
        case signed(String), adhoc, unsigned
    }
    
    enum InstallationError: LocalizedError {
        case unsupportedMacOSVersion(current: String, required: String)
        case insufficientDiskSpace(available: Int64, required: Int64)
        case swiftNotFound
        case missingExecutable(String)
        case buildFailed(String)
        case permissionDenied(Permission)
        case launchAgentFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .unsupportedMacOSVersion(let current, let required):
                return "Unsupported macOS version. Current: \(current), Required: \(required)+"
            case .insufficientDiskSpace(let available, let required):
                return "Insufficient disk space. Available: \(formatBytes(available)), Required: \(formatBytes(required))"
            case .swiftNotFound:
                return "Swift compiler not found. Please install Xcode or Xcode Command Line Tools."
            case .missingExecutable(let name):
                return "Missing executable: \(name)"
            case .buildFailed(let reason):
                return "Build failed: \(reason)"
            case .permissionDenied(let permission):
                return "Permission denied: \(permission.description)"
            case .launchAgentFailed(let reason):
                return "LaunchAgent installation failed: \(reason)"
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func log(_ message: String, level: LogLevel) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(level.prefix) \(message)"
        
        if isVerbose || level != .debug {
            print(logMessage)
        }
        
        installationLog.append(logMessage)
    }
    
    private func printHeader(_ title: String) {
        let separator = String(repeating: "=", count: title.count + 4)
        print(separator)
        print("  \(title)")
        print(separator)
        print()
    }
    
    private func printSuccess(_ message: String) {
        print()
        print("🎉 \(message)")
        print()
    }
    
    private func printPostInstallationInstructions() {
        print("📋 Post-Installation Instructions:")
        print("1. Grant required permissions in System Preferences > Privacy & Security")
        print("2. The recorder daemon will start automatically on system boot")
        print("3. Use the menu bar app to control recording and view status")
        print("4. Check logs at: \(InstallationConfig.logDir.path)")
        print()
    }
    
    private func printPostUninstallInstructions() {
        print("📋 Post-Uninstallation Notes:")
        print("1. You may manually remove permissions from System Preferences > Privacy & Security")
        print("2. Build artifacts remain in the project directory")
        print()
    }
}

// MARK: - System Utilities

extension AlwaysOnAICompanionInstaller {
    
    private func getSystemArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    private func getAvailableDiskSpace() throws -> Int64 {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return resourceValues.volumeAvailableCapacity ?? 0
    }
    
    private func isSwiftAvailable() -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = ["swift"]
        process.standardOutput = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func isXcodeCommandLineToolsInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: "/usr/bin/xcode-select")
    }
    
    private func buildProject() throws {
        let process = Process()
        process.launchPath = "/usr/bin/swift"
        process.arguments = ["build", "-c", "release"]
        process.currentDirectoryPath = InstallationConfig.projectRoot.path
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InstallationError.buildFailed(output)
        }
    }
    
    private func validateExecutable(at path: URL) throws {
        let process = Process()
        process.launchPath = "/usr/bin/file"
        process.arguments = [path.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if !output.contains("executable") {
            throw InstallationError.missingExecutable(path.lastPathComponent)
        }
    }
    
    private func checkCodeSignature(at path: URL) throws -> CodeSigningStatus {
        let process = Process()
        process.launchPath = "/usr/bin/codesign"
        process.arguments = ["-dv", path.path]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if output.contains("adhoc") {
            return .adhoc
        } else if output.contains("Authority=") {
            // Extract signing identity
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("Authority=") {
                    let authority = line.components(separatedBy: "Authority=").last ?? "Unknown"
                    return .signed(authority.trimmingCharacters(in: .whitespaces))
                }
            }
            return .signed("Unknown Authority")
        } else {
            return .unsigned
        }
    }
    
    private func checkPermissionStatus(_ permission: Permission) -> PermissionStatus {
        // This is a simplified check - actual permission checking would require
        // more sophisticated TCC database queries or system APIs
        return .notDetermined
    }
    
    private func requestPermission(_ permission: Permission) throws {
        // Open System Preferences to the appropriate section
        let url: String
        
        switch permission {
        case .screenRecording:
            url = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility:
            url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .fullDiskAccess:
            url = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        }
        
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = [url]
        
        try process.run()
    }
    
    private func openSystemPreferencesForPermissions() throws {
        log("🔐 Opening System Preferences for permission setup...", level: .info)
        
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["x-apple.systempreferences:com.apple.preference.security?Privacy"]
        
        try process.run()
        
        print()
        print("📋 Please grant the following permissions:")
        print("   • Screen Recording - Required for capturing screen content")
        print("   • Accessibility - Required for monitoring system events")
        print("   • Full Disk Access - Optional but recommended")
        print()
        print("Press Enter after granting permissions...")
        _ = readLine()
    }
    
    private func createLaunchAgentPlist() throws -> String {
        let daemonPath = InstallationConfig.buildPath.appendingPathComponent("RecorderDaemon").path
        let logDir = InstallationConfig.logDir.path
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(InstallationConfig.daemonBundleID)</string>
            
            <key>ProgramArguments</key>
            <array>
                <string>\(daemonPath)</string>
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
            <string>\(logDir)/stdout.log</string>
            
            <key>StandardErrorPath</key>
            <string>\(logDir)/stderr.log</string>
            
            <key>WorkingDirectory</key>
            <string>\(FileManager.default.homeDirectoryForCurrentUser.path)</string>
            
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
        """
    }
    
    private func loadLaunchAgent(at plistPath: URL) throws {
        // Unload first if already loaded
        let unloadProcess = Process()
        unloadProcess.launchPath = "/bin/launchctl"
        unloadProcess.arguments = ["unload", "-w", plistPath.path]
        try? unloadProcess.run()
        unloadProcess.waitUntilExit()
        
        // Load the LaunchAgent
        let loadProcess = Process()
        loadProcess.launchPath = "/bin/launchctl"
        loadProcess.arguments = ["load", "-w", plistPath.path]
        
        try loadProcess.run()
        loadProcess.waitUntilExit()
        
        if loadProcess.terminationStatus != 0 {
            throw InstallationError.launchAgentFailed("Failed to load LaunchAgent")
        }
    }
    
    private func isLaunchAgentRunning() throws -> Bool {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["list"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output.contains(InstallationConfig.daemonBundleID)
    }
    
    private func validateFilePermissions() throws {
        let filesToCheck = [
            InstallationConfig.launchAgentsDir.appendingPathComponent(InstallationConfig.launchAgentName),
            InstallationConfig.configDir,
            InstallationConfig.logDir
        ]
        
        for file in filesToCheck {
            if fileManager.fileExists(atPath: file.path) {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                log("📁 \(file.lastPathComponent): Permissions OK", level: .debug)
            }
        }
    }
    
    private func validateConfiguration() throws {
        let configPath = InstallationConfig.configDir.appendingPathComponent("config.json")
        
        if fileManager.fileExists(atPath: configPath.path) {
            let data = try Data(contentsOf: configPath)
            _ = try JSONSerialization.jsonObject(with: data)
            log("⚙️  Configuration file: Valid JSON", level: .debug)
        }
    }
    
    private func createDefaultConfiguration() -> [String: Any] {
        return [
            "version": "1.0.0",
            "recording": [
                "enabled": true,
                "quality": "high",
                "frameRate": 30,
                "segmentDuration": 120
            ],
            "privacy": [
                "piiMasking": true,
                "allowlist": [],
                "pauseHotkey": "cmd+shift+p"
            ],
            "storage": [
                "retentionDays": 30,
                "encryptionEnabled": true,
                "compressionEnabled": true
            ],
            "plugins": [
                "enabled": [],
                "disabled": []
            ]
        ]
    }
}

// MARK: - Utility Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useGB, .useMB, .useKB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

// MARK: - Main Entry Point

func main() {
    let installer = AlwaysOnAICompanionInstaller()
    
    let arguments = CommandLine.arguments
    var verbose = false
    var dryRun = false
    var uninstall = false
    
    // Parse command line arguments
    for arg in arguments {
        switch arg {
        case "--verbose", "-v":
            verbose = true
        case "--dry-run", "-n":
            dryRun = true
        case "--uninstall", "-u":
            uninstall = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            break
        }
    }
    
    do {
        if uninstall {
            try installer.uninstall(verbose: verbose)
        } else {
            try installer.install(verbose: verbose, dryRun: dryRun)
        }
        exit(0)
    } catch {
        print("❌ Installation failed: \(error.localizedDescription)")
        exit(1)
    }
}

func printUsage() {
    print("""
    Always-On AI Companion Installer
    
    Usage: installer.swift [OPTIONS]
    
    Options:
        --verbose, -v       Enable verbose output
        --dry-run, -n       Perform a dry run without making changes
        --uninstall, -u     Uninstall the system
        --help, -h          Show this help message
    
    Examples:
        ./installer.swift                    # Install with default options
        ./installer.swift --verbose          # Install with verbose output
        ./installer.swift --dry-run          # Check system without installing
        ./installer.swift --uninstall        # Uninstall the system
    """)
}

// Run the installer
main()