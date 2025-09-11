import Foundation
import ServiceManagement
import AppKit
import ApplicationServices

/// Manages LaunchAgent installation and system startup integration
public class LaunchAgentManager {
    private let bundleIdentifier = "com.alwaysonai.recorderdaemon"
    private let launchAgentName = "com.alwaysonai.recorderdaemon.plist"
    private let fileManager = FileManager.default
    
    private var launchAgentURL: URL {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        return homeURL
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent(launchAgentName)
    }
    
    public init() {}
    
    public func getDaemonExecutablePath() -> String? {
        // Try to find the RecorderDaemon executable
        let possiblePaths = [
            // Development build path
            ".build/debug/RecorderDaemon",
            ".build/release/RecorderDaemon",
            // Installed path in Applications
            "/Applications/AlwaysOnAICompanion.app/Contents/MacOS/RecorderDaemon",
            // User's local bin
            "\(fileManager.homeDirectoryForCurrentUser.path)/bin/RecorderDaemon",
            // System-wide installation
            "/usr/local/bin/RecorderDaemon"
        ]
        
        for path in possiblePaths {
            let fullPath = path.hasPrefix("/") ? path : "\(fileManager.currentDirectoryPath)/\(path)"
            if fileManager.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        
        // If not found, try to build it
        print("RecorderDaemon executable not found, attempting to build...")
        return buildDaemonExecutable()
    }
    
    private func buildDaemonExecutable() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/swift"
        task.arguments = ["build", "--product", "RecorderDaemon", "--configuration", "release"]
        task.currentDirectoryPath = findProjectRoot() ?? fileManager.currentDirectoryPath
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let builtPath = "\(task.currentDirectoryPath)/.build/release/RecorderDaemon"
                if fileManager.isExecutableFile(atPath: builtPath) {
                    return builtPath
                }
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown build error"
                print("Build failed: \(errorString)")
            }
        } catch {
            print("Failed to build RecorderDaemon: \(error)")
        }
        
        return nil
    }
    
    private func findProjectRoot() -> String? {
        var currentPath = fileManager.currentDirectoryPath
        
        while currentPath != "/" {
            let packageSwiftPath = "\(currentPath)/Package.swift"
            if fileManager.fileExists(atPath: packageSwiftPath) {
                return currentPath
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }
        
        return nil
    }
    
    public func installLaunchAgent(daemonPath: String? = nil) throws {
        print("Installing LaunchAgent...")
        
        // Determine daemon path
        let executablePath = daemonPath ?? getDaemonExecutablePath()
        guard let finalPath = executablePath else {
            throw LaunchAgentError.daemonNotFound
        }
        
        print("Using daemon path: \(finalPath)")
        
        // Verify the executable exists and is executable
        guard fileManager.isExecutableFile(atPath: finalPath) else {
            throw LaunchAgentError.daemonNotExecutable(finalPath)
        }
        
        // Create LaunchAgents directory if it doesn't exist
        let launchAgentsDir = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        
        // Create plist content
        let plistContent = createLaunchAgentPlist(daemonPath: finalPath)
        
        // Write plist file
        try plistContent.write(to: launchAgentURL, atomically: true, encoding: .utf8)
        
        // Set proper permissions
        try setLaunchAgentPermissions()
        
        // Load the launch agent
        try loadLaunchAgent()
        
        print("LaunchAgent installed successfully")
    }
    
    public func uninstallLaunchAgent() throws {
        print("Uninstalling LaunchAgent...")
        
        // Unload the launch agent first
        try unloadLaunchAgent()
        
        // Remove plist file
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            try fileManager.removeItem(at: launchAgentURL)
        }
        
        print("LaunchAgent uninstalled successfully")
    }
    
    public func isLaunchAgentInstalled() -> Bool {
        return fileManager.fileExists(atPath: launchAgentURL.path)
    }
    
    public func isLaunchAgentLoaded() -> Bool {
        // Check if the launch agent is currently loaded
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list", bundleIdentifier]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    public func startDaemon() throws {
        guard isLaunchAgentInstalled() else {
            throw LaunchAgentError.notInstalled
        }
        
        try loadLaunchAgent()
    }
    
    public func stopDaemon() throws {
        guard isLaunchAgentInstalled() else {
            throw LaunchAgentError.notInstalled
        }
        
        try unloadLaunchAgent()
    }
    
    private func createLaunchAgentPlist(daemonPath: String) -> String {
        let logPath = getLogPath()
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleIdentifier)</string>
            
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
            <string>\(logPath)/stdout.log</string>
            
            <key>StandardErrorPath</key>
            <string>\(logPath)/stderr.log</string>
            
            <key>WorkingDirectory</key>
            <string>\(fileManager.homeDirectoryForCurrentUser.path)</string>
            
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
    
    private func setLaunchAgentPermissions() throws {
        // Set proper permissions (readable by user only)
        let attributes = [FileAttributeKey.posixPermissions: 0o644]
        try fileManager.setAttributes(attributes, ofItemAtPath: launchAgentURL.path)
    }
    
    private func loadLaunchAgent() throws {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["load", "-w", launchAgentURL.path]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw LaunchAgentError.loadFailed(errorString)
        }
    }
    
    private func unloadLaunchAgent() throws {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["unload", "-w", launchAgentURL.path]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw LaunchAgentError.unloadFailed(errorString)
        }
    }
    
    private func getLogPath() -> String {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let logURL = homeURL
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("AlwaysOnAICompanion")
        
        // Create log directory if it doesn't exist
        try? fileManager.createDirectory(at: logURL, withIntermediateDirectories: true)
        
        return logURL.path
    }
}

// MARK: - Permission Management
extension LaunchAgentManager {
    public func checkRequiredPermissions() -> [PermissionStatus] {
        var permissions: [PermissionStatus] = []
        
        // Check screen recording permission
        permissions.append(checkScreenRecordingPermission())
        
        // Check accessibility permission
        permissions.append(checkAccessibilityPermission())
        
        // Check full disk access (optional but recommended)
        permissions.append(checkFullDiskAccessPermission())
        
        return permissions
    }
    
    public func requestPermissions() async -> Bool {
        print("Requesting required permissions...")
        
        var allGranted = true
        
        // Request screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            print("Requesting screen recording permission...")
            let granted = CGRequestScreenCaptureAccess()
            if !granted {
                print("Screen recording permission denied")
                allGranted = false
                // Open System Preferences to Privacy & Security
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                NSWorkspace.shared.open(url)
            }
        }
        
        // Request accessibility permission
        if !AXIsProcessTrusted() {
            print("Requesting accessibility permission...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)
            if !trusted {
                print("Accessibility permission denied")
                allGranted = false
            }
        }
        
        return allGranted
    }
    
    public func requestPermissionsInteractive() {
        print("Opening System Preferences for permission setup...")
        
        // Open System Preferences to Privacy & Security - Screen Recording
        let screenRecordingURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(screenRecordingURL)
        
        // Also show accessibility if needed
        if !AXIsProcessTrusted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(accessibilityURL)
            }
        }
    }
    
    private func checkScreenRecordingPermission() -> PermissionStatus {
        // Check if screen recording is allowed using ScreenCaptureKit
        let granted = CGPreflightScreenCaptureAccess()
        return PermissionStatus(
            type: .screenRecording,
            granted: granted,
            required: true
        )
    }
    
    private func checkAccessibilityPermission() -> PermissionStatus {
        // Check accessibility permission
        let trusted = AXIsProcessTrusted()
        return PermissionStatus(
            type: .accessibility,
            granted: trusted,
            required: true
        )
    }
    
    private func checkFullDiskAccessPermission() -> PermissionStatus {
        // Check full disk access by trying to read a protected file
        let protectedPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        let canRead = fileManager.isReadableFile(atPath: protectedPath)
        
        return PermissionStatus(
            type: .fullDiskAccess,
            granted: canRead,
            required: false
        )
    }
}

// MARK: - Supporting Types
public struct PermissionStatus {
    public let type: PermissionType
    public let granted: Bool
    public let required: Bool
    
    public var description: String {
        let status = granted ? "✅ Granted" : "❌ Denied"
        let requirement = required ? " (Required)" : " (Optional)"
        return "\(type.description): \(status)\(requirement)"
    }
}

public enum PermissionType {
    case screenRecording
    case accessibility
    case fullDiskAccess
    
    public var description: String {
        switch self {
        case .screenRecording:
            return "Screen Recording"
        case .accessibility:
            return "Accessibility"
        case .fullDiskAccess:
            return "Full Disk Access"
        }
    }
}

public enum LaunchAgentError: Error {
    case notInstalled
    case loadFailed(String)
    case unloadFailed(String)
    case permissionDenied
    case daemonNotFound
    case daemonNotExecutable(String)
    
    public var localizedDescription: String {
        switch self {
        case .notInstalled:
            return "LaunchAgent is not installed"
        case .loadFailed(let error):
            return "Failed to load LaunchAgent: \(error)"
        case .unloadFailed(let error):
            return "Failed to unload LaunchAgent: \(error)"
        case .permissionDenied:
            return "Permission denied for LaunchAgent operation"
        case .daemonNotFound:
            return "RecorderDaemon executable not found. Please build the project first."
        case .daemonNotExecutable(let path):
            return "RecorderDaemon at path '\(path)' is not executable"
        }
    }
}