import Foundation
import CoreGraphics

/// Manages system configuration using JSON files
public class ConfigurationManager {
    private let configurationURL: URL
    private let fileManager = FileManager.default
    
    public init() {
        // Create configuration directory in user's Application Support
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appURL = appSupportURL.appendingPathComponent("AlwaysOnAICompanion")
        
        try? fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        
        self.configurationURL = appURL.appendingPathComponent("config.json")
        
        // Create default configuration if it doesn't exist
        if !fileManager.fileExists(atPath: configurationURL.path) {
            saveDefaultConfiguration()
        }
    }
    
    public func loadConfiguration() -> RecorderConfiguration? {
        do {
            let data = try Data(contentsOf: configurationURL)
            let decoder = JSONDecoder()
            return try decoder.decode(RecorderConfiguration.self, from: data)
        } catch {
            print("Failed to load configuration: \(error)")
            return createDefaultConfiguration()
        }
    }
    
    public func saveConfiguration(_ configuration: RecorderConfiguration) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configuration)
            try data.write(to: configurationURL)
            return true
        } catch {
            print("Failed to save configuration: \(error)")
            return false
        }
    }
    
    public func resetToDefaults() {
        saveDefaultConfiguration()
    }
    
    private func saveDefaultConfiguration() {
        let defaultConfig = createDefaultConfiguration()
        _ = saveConfiguration(defaultConfig)
    }
    
    private func createDefaultConfiguration() -> RecorderConfiguration {
        // Get user's Documents directory for storage
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storageURL = documentsURL.appendingPathComponent("AlwaysOnAICompanion")
        
        return RecorderConfiguration(
            // Recording settings
            selectedDisplays: [], // Empty means all displays
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            
            // Encoding settings
            targetBitrate: 3_000_000, // 3 Mbps
            segmentDuration: 120, // 2 minutes
            
            // Storage settings
            storageURL: storageURL,
            maxStorageDays: 30,
            
            // Performance settings
            maxCPUUsage: 8.0, // 8% max CPU usage
            maxMemoryUsage: 512, // 512 MB max memory
            maxDiskIORate: 20.0, // 20 MB/s max disk I/O
            
            // Privacy settings
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            
            // System settings
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info
        )
    }
}

// MARK: - Configuration Data Model
public struct RecorderConfiguration: Codable {
    // Recording settings
    public let selectedDisplays: [CGDirectDisplayID]
    public let captureWidth: Int
    public let captureHeight: Int
    public let frameRate: Int
    public let showCursor: Bool
    
    // Encoding settings
    public let targetBitrate: Int
    public let segmentDuration: TimeInterval
    
    // Storage settings
    public let storageURL: URL
    public let maxStorageDays: Int
    
    // Performance settings
    public let maxCPUUsage: Double
    public let maxMemoryUsage: Int // MB
    public let maxDiskIORate: Double // MB/s
    
    // Privacy settings
    public let enablePIIMasking: Bool
    public let allowedApplications: [String]
    public let blockedApplications: [String]
    public let pauseHotkey: String
    
    // System settings
    public let autoStart: Bool
    public let enableRecovery: Bool
    public let recoveryTimeoutSeconds: Int
    public let enableLogging: Bool
    public let logLevel: ConfigLogLevel
    
    public init(
        selectedDisplays: [CGDirectDisplayID],
        captureWidth: Int,
        captureHeight: Int,
        frameRate: Int,
        showCursor: Bool,
        targetBitrate: Int,
        segmentDuration: TimeInterval,
        storageURL: URL,
        maxStorageDays: Int,
        maxCPUUsage: Double,
        maxMemoryUsage: Int,
        maxDiskIORate: Double,
        enablePIIMasking: Bool,
        allowedApplications: [String],
        blockedApplications: [String],
        pauseHotkey: String,
        autoStart: Bool,
        enableRecovery: Bool,
        recoveryTimeoutSeconds: Int,
        enableLogging: Bool,
        logLevel: ConfigLogLevel
    ) {
        self.selectedDisplays = selectedDisplays
        self.captureWidth = captureWidth
        self.captureHeight = captureHeight
        self.frameRate = frameRate
        self.showCursor = showCursor
        self.targetBitrate = targetBitrate
        self.segmentDuration = segmentDuration
        self.storageURL = storageURL
        self.maxStorageDays = maxStorageDays
        self.maxCPUUsage = maxCPUUsage
        self.maxMemoryUsage = maxMemoryUsage
        self.maxDiskIORate = maxDiskIORate
        self.enablePIIMasking = enablePIIMasking
        self.allowedApplications = allowedApplications
        self.blockedApplications = blockedApplications
        self.pauseHotkey = pauseHotkey
        self.autoStart = autoStart
        self.enableRecovery = enableRecovery
        self.recoveryTimeoutSeconds = recoveryTimeoutSeconds
        self.enableLogging = enableLogging
        self.logLevel = logLevel
    }
}

// MARK: - Supporting Types
public enum ConfigLogLevel: String, Codable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    public var description: String {
        return rawValue.capitalized
    }
}

// CGDirectDisplayID is already Codable as it's a UInt32 typealias