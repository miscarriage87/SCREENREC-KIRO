import Foundation
import CoreGraphics
import AppKit

/// Manages application and screen allowlists for privacy control
public class AllowlistManager {
    private let configurationManager: ConfigurationManager
    private var currentConfiguration: RecorderConfiguration
    private let logger = Logger.shared
    
    // Application monitoring
    private var runningApplications: [NSRunningApplication] = []
    private var applicationObserver: NSObjectProtocol?
    
    // Display monitoring
    private var availableDisplays: [CGDirectDisplayID] = []
    private var displaySpecificAllowlists: [CGDirectDisplayID: DisplayAllowlist] = [:]
    
    // Allowlist change notifications
    public var onAllowlistChanged: (() -> Void)?
    
    public init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
        self.currentConfiguration = configurationManager.loadConfiguration() ?? RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info,
            enableRetentionPolicies: true,
            retentionCheckIntervalHours: 24
        )
        
        setupApplicationMonitoring()
        updateAvailableDisplays()
    }
    
    deinit {
        if let observer = applicationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - Application Allowlist Management
    
    /// Adds an application to the allowed list
    public func addAllowedApplication(_ bundleIdentifier: String) {
        var allowedApps = Set(currentConfiguration.allowedApplications)
        allowedApps.insert(bundleIdentifier)
        
        updateConfiguration(allowedApplications: Array(allowedApps))
        logger.info("Added application to allowlist: \(bundleIdentifier)")
    }
    
    /// Removes an application from the allowed list
    public func removeAllowedApplication(_ bundleIdentifier: String) {
        var allowedApps = Set(currentConfiguration.allowedApplications)
        allowedApps.remove(bundleIdentifier)
        
        updateConfiguration(allowedApplications: Array(allowedApps))
        logger.info("Removed application from allowlist: \(bundleIdentifier)")
    }
    
    /// Adds an application to the blocked list
    public func addBlockedApplication(_ bundleIdentifier: String) {
        var blockedApps = Set(currentConfiguration.blockedApplications)
        blockedApps.insert(bundleIdentifier)
        
        updateConfiguration(blockedApplications: Array(blockedApps))
        logger.info("Added application to blocklist: \(bundleIdentifier)")
    }
    
    /// Removes an application from the blocked list
    public func removeBlockedApplication(_ bundleIdentifier: String) {
        var blockedApps = Set(currentConfiguration.blockedApplications)
        blockedApps.remove(bundleIdentifier)
        
        updateConfiguration(blockedApplications: Array(blockedApps))
        logger.info("Removed application from blocklist: \(bundleIdentifier)")
    }
    
    /// Sets the complete allowed applications list
    public func setAllowedApplications(_ bundleIdentifiers: [String]) {
        updateConfiguration(allowedApplications: bundleIdentifiers)
        logger.info("Updated allowed applications list: \(bundleIdentifiers)")
    }
    
    /// Sets the complete blocked applications list
    public func setBlockedApplications(_ bundleIdentifiers: [String]) {
        updateConfiguration(blockedApplications: bundleIdentifiers)
        logger.info("Updated blocked applications list: \(bundleIdentifiers)")
    }
    
    // MARK: - Screen Allowlist Management
    
    /// Adds a display to the selected displays list
    public func addAllowedDisplay(_ displayID: CGDirectDisplayID) {
        var selectedDisplays = Set(currentConfiguration.selectedDisplays)
        selectedDisplays.insert(displayID)
        
        updateConfiguration(selectedDisplays: Array(selectedDisplays))
        logger.info("Added display to allowlist: \(displayID)")
    }
    
    /// Removes a display from the selected displays list
    public func removeAllowedDisplay(_ displayID: CGDirectDisplayID) {
        var selectedDisplays = Set(currentConfiguration.selectedDisplays)
        selectedDisplays.remove(displayID)
        
        updateConfiguration(selectedDisplays: Array(selectedDisplays))
        logger.info("Removed display from allowlist: \(displayID)")
    }
    
    /// Sets the complete allowed displays list
    public func setAllowedDisplays(_ displayIDs: [CGDirectDisplayID]) {
        updateConfiguration(selectedDisplays: displayIDs)
        logger.info("Updated allowed displays list: \(displayIDs)")
    }
    
    // MARK: - Display-Specific Allowlist Management
    
    /// Sets application allowlist for a specific display
    public func setDisplayAllowlist(_ displayID: CGDirectDisplayID, allowlist: DisplayAllowlist) {
        displaySpecificAllowlists[displayID] = allowlist
        logger.info("Updated display-specific allowlist for display \(displayID)")
        onAllowlistChanged?()
    }
    
    /// Gets application allowlist for a specific display
    public func getDisplayAllowlist(_ displayID: CGDirectDisplayID) -> DisplayAllowlist? {
        return displaySpecificAllowlists[displayID]
    }
    
    /// Removes display-specific allowlist (falls back to global allowlist)
    public func removeDisplayAllowlist(_ displayID: CGDirectDisplayID) {
        displaySpecificAllowlists.removeValue(forKey: displayID)
        logger.info("Removed display-specific allowlist for display \(displayID)")
        onAllowlistChanged?()
    }
    
    /// Adds an application to a display-specific allowlist
    public func addApplicationToDisplay(_ displayID: CGDirectDisplayID, bundleIdentifier: String) {
        var allowlist = displaySpecificAllowlists[displayID] ?? DisplayAllowlist()
        allowlist.allowedApplications.insert(bundleIdentifier)
        displaySpecificAllowlists[displayID] = allowlist
        
        logger.info("Added application \(bundleIdentifier) to display \(displayID) allowlist")
        onAllowlistChanged?()
    }
    
    /// Removes an application from a display-specific allowlist
    public func removeApplicationFromDisplay(_ displayID: CGDirectDisplayID, bundleIdentifier: String) {
        guard var allowlist = displaySpecificAllowlists[displayID] else { return }
        
        allowlist.allowedApplications.remove(bundleIdentifier)
        displaySpecificAllowlists[displayID] = allowlist
        
        logger.info("Removed application \(bundleIdentifier) from display \(displayID) allowlist")
        onAllowlistChanged?()
    }
    
    /// Blocks an application on a specific display
    public func blockApplicationOnDisplay(_ displayID: CGDirectDisplayID, bundleIdentifier: String) {
        var allowlist = displaySpecificAllowlists[displayID] ?? DisplayAllowlist()
        allowlist.blockedApplications.insert(bundleIdentifier)
        displaySpecificAllowlists[displayID] = allowlist
        
        logger.info("Blocked application \(bundleIdentifier) on display \(displayID)")
        onAllowlistChanged?()
    }
    
    /// Unblocks an application on a specific display
    public func unblockApplicationOnDisplay(_ displayID: CGDirectDisplayID, bundleIdentifier: String) {
        guard var allowlist = displaySpecificAllowlists[displayID] else { return }
        
        allowlist.blockedApplications.remove(bundleIdentifier)
        displaySpecificAllowlists[displayID] = allowlist
        
        logger.info("Unblocked application \(bundleIdentifier) on display \(displayID)")
        onAllowlistChanged?()
    }
    
    // MARK: - Allowlist Enforcement
    
    /// Checks if an application should be captured based on allowlist rules
    public func shouldCaptureApplication(_ bundleIdentifier: String) -> Bool {
        // If application is explicitly blocked globally, don't capture
        if currentConfiguration.blockedApplications.contains(bundleIdentifier) {
            return false
        }
        
        // If allowlist is empty, capture all applications (except blocked ones)
        if currentConfiguration.allowedApplications.isEmpty {
            return true
        }
        
        // If allowlist is not empty, only capture allowed applications
        return currentConfiguration.allowedApplications.contains(bundleIdentifier)
    }
    
    /// Checks if an application should be captured on a specific display
    public func shouldCaptureApplication(_ bundleIdentifier: String, onDisplay displayID: CGDirectDisplayID) -> Bool {
        // Check if display-specific allowlist exists
        if let displayAllowlist = displaySpecificAllowlists[displayID] {
            // If application is explicitly blocked on this display, don't capture
            if displayAllowlist.blockedApplications.contains(bundleIdentifier) {
                return false
            }
            
            // If display has specific allowed applications, only capture those
            if !displayAllowlist.allowedApplications.isEmpty {
                return displayAllowlist.allowedApplications.contains(bundleIdentifier)
            }
            
            // If display allowlist is empty but exists, fall back to global rules
            return shouldCaptureApplication(bundleIdentifier)
        }
        
        // No display-specific allowlist, use global rules
        return shouldCaptureApplication(bundleIdentifier)
    }
    
    /// Checks if a display should be captured based on allowlist rules
    public func shouldCaptureDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        // If no displays are selected, capture all displays
        if currentConfiguration.selectedDisplays.isEmpty {
            return true
        }
        
        // Only capture selected displays
        return currentConfiguration.selectedDisplays.contains(displayID)
    }
    
    /// Gets the list of displays that should be captured
    public func getAllowedDisplays() -> [CGDirectDisplayID] {
        if currentConfiguration.selectedDisplays.isEmpty {
            return availableDisplays
        }
        
        return currentConfiguration.selectedDisplays.filter { availableDisplays.contains($0) }
    }
    
    /// Gets the currently active application's bundle identifier
    public func getCurrentApplicationBundleID() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    /// Checks if the current application should be captured
    public func shouldCaptureCurrentApplication() -> Bool {
        guard let bundleID = getCurrentApplicationBundleID() else {
            return false
        }
        
        return shouldCaptureApplication(bundleID)
    }
    
    /// Checks if the current application should be captured on a specific display
    public func shouldCaptureCurrentApplication(onDisplay displayID: CGDirectDisplayID) -> Bool {
        guard let bundleID = getCurrentApplicationBundleID() else {
            return false
        }
        
        return shouldCaptureApplication(bundleID, onDisplay: displayID)
    }
    
    // MARK: - Application Discovery
    
    /// Gets all currently running applications
    public func getRunningApplications() -> [ApplicationInfo] {
        return runningApplications.compactMap { app in
            guard let bundleID = app.bundleIdentifier,
                  let localizedName = app.localizedName else {
                return nil
            }
            
            return ApplicationInfo(
                bundleIdentifier: bundleID,
                name: localizedName,
                isActive: app.isActive,
                processIdentifier: app.processIdentifier
            )
        }
    }
    
    /// Gets all installed applications (not just running ones)
    public func getInstalledApplications() -> [ApplicationInfo] {
        var applications: [ApplicationInfo] = []
        
        // Get applications from common directories
        let applicationDirectories = [
            "/Applications",
            "/System/Applications",
            "~/Applications"
        ]
        
        for directory in applicationDirectories {
            let expandedPath = NSString(string: directory).expandingTildeInPath
            let directoryURL = URL(fileURLWithPath: expandedPath)
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isApplicationKey],
                    options: [.skipsHiddenFiles]
                )
                
                for url in contents {
                    if url.pathExtension == "app" {
                        if let bundle = Bundle(url: url),
                           let bundleID = bundle.bundleIdentifier,
                           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                                     bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                            
                            let appInfo = ApplicationInfo(
                                bundleIdentifier: bundleID,
                                name: name,
                                isActive: false,
                                processIdentifier: 0
                            )
                            
                            applications.append(appInfo)
                        }
                    }
                }
            } catch {
                logger.warning("Failed to scan directory \(directory): \(error)")
            }
        }
        
        // Remove duplicates based on bundle identifier
        var uniqueApps: [String: ApplicationInfo] = [:]
        for app in applications {
            uniqueApps[app.bundleIdentifier] = app
        }
        
        return Array(uniqueApps.values).sorted { $0.name < $1.name }
    }
    
    // MARK: - Configuration Management
    
    private func updateConfiguration(
        selectedDisplays: [CGDirectDisplayID]? = nil,
        allowedApplications: [String]? = nil,
        blockedApplications: [String]? = nil
    ) {
        let newConfiguration = RecorderConfiguration(
            selectedDisplays: selectedDisplays ?? currentConfiguration.selectedDisplays,
            captureWidth: currentConfiguration.captureWidth,
            captureHeight: currentConfiguration.captureHeight,
            frameRate: currentConfiguration.frameRate,
            showCursor: currentConfiguration.showCursor,
            targetBitrate: currentConfiguration.targetBitrate,
            segmentDuration: currentConfiguration.segmentDuration,
            storageURL: currentConfiguration.storageURL,
            maxStorageDays: currentConfiguration.maxStorageDays,
            maxCPUUsage: currentConfiguration.maxCPUUsage,
            maxMemoryUsage: currentConfiguration.maxMemoryUsage,
            maxDiskIORate: currentConfiguration.maxDiskIORate,
            enablePIIMasking: currentConfiguration.enablePIIMasking,
            allowedApplications: allowedApplications ?? currentConfiguration.allowedApplications,
            blockedApplications: blockedApplications ?? currentConfiguration.blockedApplications,
            pauseHotkey: currentConfiguration.pauseHotkey,
            autoStart: currentConfiguration.autoStart,
            enableRecovery: currentConfiguration.enableRecovery,
            recoveryTimeoutSeconds: currentConfiguration.recoveryTimeoutSeconds,
            enableLogging: currentConfiguration.enableLogging,
            logLevel: currentConfiguration.logLevel,
            enableRetentionPolicies: currentConfiguration.enableRetentionPolicies,
            retentionCheckIntervalHours: currentConfiguration.retentionCheckIntervalHours
        )
        
        currentConfiguration = newConfiguration
        
        if configurationManager.saveConfiguration(newConfiguration) {
            onAllowlistChanged?()
        } else {
            logger.error("Failed to save configuration changes")
        }
    }
    
    // MARK: - Monitoring Setup
    
    private func setupApplicationMonitoring() {
        // Update running applications list
        updateRunningApplications()
        
        // Monitor application launches and terminations
        applicationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateRunningApplications()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateRunningApplications()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateRunningApplications()
        }
    }
    
    private func updateRunningApplications() {
        runningApplications = NSWorkspace.shared.runningApplications.filter { app in
            // Filter out system processes and background apps
            return app.activationPolicy == .regular
        }
    }
    
    private func updateAvailableDisplays() {
        var displayCount: UInt32 = 0
        var displays: [CGDirectDisplayID] = []
        
        // Get the number of active displays
        if CGGetActiveDisplayList(0, nil, &displayCount) == .success {
            displays = Array(repeating: 0, count: Int(displayCount))
            
            // Get the actual display IDs
            if CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success {
                availableDisplays = displays
            }
        }
    }
}

// MARK: - Supporting Types

/// Information about an application
public struct ApplicationInfo {
    public let bundleIdentifier: String
    public let name: String
    public let isActive: Bool
    public let processIdentifier: pid_t
    
    public init(bundleIdentifier: String, name: String, isActive: Bool, processIdentifier: pid_t) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isActive = isActive
        self.processIdentifier = processIdentifier
    }
}

/// Display-specific allowlist configuration
public struct DisplayAllowlist {
    public var allowedApplications: Set<String>
    public var blockedApplications: Set<String>
    
    public init(allowedApplications: Set<String> = [], blockedApplications: Set<String> = []) {
        self.allowedApplications = allowedApplications
        self.blockedApplications = blockedApplications
    }
}

/// Display information for allowlist management
public struct DisplayAllowlistInfo {
    public let displayID: CGDirectDisplayID
    public let name: String
    public let isMain: Bool
    public let bounds: CGRect
    public let isAllowed: Bool
    
    public init(displayID: CGDirectDisplayID, name: String, isMain: Bool, bounds: CGRect, isAllowed: Bool) {
        self.displayID = displayID
        self.name = name
        self.isMain = isMain
        self.bounds = bounds
        self.isAllowed = isAllowed
    }
}