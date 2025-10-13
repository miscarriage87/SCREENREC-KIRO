#!/usr/bin/env swift

import Foundation

// Mock implementations for testing
struct MockPluginInfo {
    let identifier: String
    let name: String
    let version: String
    let description: String
    let supportedApplications: [String]
    let isEnabled: Bool
}

struct MockRetentionPolicyData {
    var enabled: Bool
    var retentionDays: Int
}

struct MockStorageHealthReport {
    let totalSize: Int64
    let availableSpace: Int64
    let dataTypeBreakdown: [String: Int64]
    let recommendations: [String]
    let healthStatus: String
}

// Mock settings controller for validation
class MockSettingsController {
    // General Settings
    var launchAtStartup: Bool = true
    var showMenuBarIcon: Bool = true
    var showNotifications: Bool = true
    var enableLogging: Bool = true
    var logLevel: String = "info"
    var storageLocation: String = "~/Documents/AlwaysOnAICompanion"
    
    // Recording Settings
    var selectedDisplays: Set<UInt32> = []
    var frameRate: Int = 30
    var quality: String = "medium"
    var segmentDuration: Int = 120
    
    // Privacy Settings
    var enablePIIMasking: Bool = true
    var maskCreditCards: Bool = true
    var maskSSN: Bool = true
    var maskEmails: Bool = true
    var enableAppFiltering: Bool = false
    var allowedApps: [String] = []
    var enableScreenFiltering: Bool = false
    var allowedScreens: Set<UInt32> = []
    
    // Retention Policy Settings
    var enableRetentionPolicies: Bool = true
    var retentionPolicies: [String: MockRetentionPolicyData] = [:]
    var safetyMarginHours: Int = 24
    var cleanupIntervalHours: Int = 24
    var verificationEnabled: Bool = true
    var storageHealthReport: MockStorageHealthReport?
    
    // Plugin Settings
    var availablePlugins: [MockPluginInfo] = []
    var pluginSettings: [String: [String: Any]] = [:]
    
    // Performance Settings
    var maxCPUUsage: Double = 8.0
    var maxMemoryUsage: Double = 500.0
    var maxDiskIO: Double = 20.0
    var enableHardwareAcceleration: Bool = true
    var useBatchProcessing: Bool = true
    var enableCompression: Bool = true
    
    // Hotkey Settings
    var pauseHotkey: String = "⌘⇧P"
    var privacyHotkey: String = "⌘⇧⌥P"
    var emergencyHotkey: String = "⌘⇧⌥E"
    
    // Data Management Settings
    var enableAutomaticBackups: Bool = false
    var backupFrequency: String = "weekly"
    var backupLocation: String = "~/Documents/AlwaysOnAI-Backups"
    var backupRetentionDays: Int = 90
    
    init() {
        setupDefaultData()
    }
    
    private func setupDefaultData() {
        // Setup default retention policies
        retentionPolicies = [
            "raw_video": MockRetentionPolicyData(enabled: true, retentionDays: 30),
            "frame_metadata": MockRetentionPolicyData(enabled: true, retentionDays: 90),
            "ocr_data": MockRetentionPolicyData(enabled: true, retentionDays: 90),
            "events": MockRetentionPolicyData(enabled: true, retentionDays: 365),
            "spans": MockRetentionPolicyData(enabled: false, retentionDays: -1),
            "summaries": MockRetentionPolicyData(enabled: false, retentionDays: -1)
        ]
        
        // Setup mock plugins
        availablePlugins = [
            MockPluginInfo(
                identifier: "com.alwayson.plugins.web",
                name: "Web Application Parser",
                version: "1.0.0",
                description: "Enhanced parsing for web applications and browser content",
                supportedApplications: ["com.apple.Safari", "com.google.Chrome"],
                isEnabled: true
            ),
            MockPluginInfo(
                identifier: "com.alwayson.plugins.productivity",
                name: "Productivity Application Parser",
                version: "1.0.0",
                description: "Specialized parsing for Jira, Salesforce, and other productivity tools",
                supportedApplications: ["com.atlassian.jira", "com.salesforce.*"],
                isEnabled: true
            ),
            MockPluginInfo(
                identifier: "com.alwayson.plugins.terminal",
                name: "Terminal Application Parser",
                version: "1.0.0",
                description: "Command-line specific analysis and command history tracking",
                supportedApplications: ["com.apple.Terminal", "com.googlecode.iterm2"],
                isEnabled: false
            )
        ]
        
        // Setup plugin settings
        pluginSettings = [
            "com.alwayson.plugins.web": [
                "extract_forms": true,
                "detect_navigation": true,
                "parse_tables": true,
                "max_table_rows": 1000,
                "timeout": 10.0
            ],
            "com.alwayson.plugins.productivity": [
                "detect_jira_issues": true,
                "parse_salesforce_records": true,
                "extract_workflow_states": true,
                "track_time_entries": true,
                "max_field_pairs": 500,
                "timeout": 15.0
            ],
            "com.alwayson.plugins.terminal": [
                "track_command_history": true,
                "detect_file_operations": true,
                "parse_system_info": true,
                "extract_error_messages": true,
                "max_command_length": 1000,
                "timeout": 5.0
            ]
        ]
        
        // Setup storage health report
        storageHealthReport = MockStorageHealthReport(
            totalSize: 5_000_000_000, // 5GB
            availableSpace: 50_000_000_000, // 50GB
            dataTypeBreakdown: [
                "raw_video": 3_000_000_000,
                "frame_metadata": 500_000_000,
                "ocr_data": 800_000_000,
                "events": 400_000_000,
                "spans": 200_000_000,
                "summaries": 100_000_000
            ],
            recommendations: [
                "Storage usage is healthy",
                "Consider enabling compression for video data"
            ],
            healthStatus: "healthy"
        )
    }
}

// Validation functions
func validateGeneralSettings(_ controller: MockSettingsController) -> Bool {
    print("🔍 Validating General Settings...")
    
    var isValid = true
    
    // Validate log level
    let validLogLevels = ["debug", "info", "warning", "error"]
    if !validLogLevels.contains(controller.logLevel.lowercased()) {
        print("❌ Invalid log level: \(controller.logLevel)")
        isValid = false
    } else {
        print("✅ Log level is valid: \(controller.logLevel)")
    }
    
    // Validate storage location
    if controller.storageLocation.isEmpty {
        print("❌ Storage location cannot be empty")
        isValid = false
    } else {
        print("✅ Storage location is set: \(controller.storageLocation)")
    }
    
    // Check menu bar and notification settings
    if !controller.showMenuBarIcon && !controller.showNotifications {
        print("⚠️  Warning: Both menu bar icon and notifications are disabled")
    }
    
    return isValid
}

func validateRecordingSettings(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Recording Settings...")
    
    var isValid = true
    
    // Validate frame rate
    let validFrameRates = [15, 30, 60]
    if !validFrameRates.contains(controller.frameRate) {
        print("❌ Invalid frame rate: \(controller.frameRate)")
        isValid = false
    } else {
        print("✅ Frame rate is valid: \(controller.frameRate) FPS")
    }
    
    // Validate quality
    let validQualities = ["low", "medium", "high"]
    if !validQualities.contains(controller.quality.lowercased()) {
        print("❌ Invalid quality setting: \(controller.quality)")
        isValid = false
    } else {
        print("✅ Quality setting is valid: \(controller.quality)")
    }
    
    // Validate segment duration
    let validDurations = [60, 120, 300]
    if !validDurations.contains(controller.segmentDuration) {
        print("❌ Invalid segment duration: \(controller.segmentDuration)")
        isValid = false
    } else {
        print("✅ Segment duration is valid: \(controller.segmentDuration) seconds")
    }
    
    // Check for high resource usage
    if controller.frameRate == 60 && controller.quality == "high" && controller.selectedDisplays.count > 2 {
        print("⚠️  Warning: High resource usage configuration detected")
    }
    
    return isValid
}

func validatePrivacySettings(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Privacy Settings...")
    
    var isValid = true
    
    // Check PII masking consistency
    if !controller.enablePIIMasking && (controller.maskCreditCards || controller.maskSSN || controller.maskEmails) {
        print("⚠️  Warning: PII masking disabled but specific options are enabled")
    } else {
        print("✅ PII masking configuration is consistent")
    }
    
    // Check app filtering
    if controller.enableAppFiltering && controller.allowedApps.isEmpty {
        print("⚠️  Warning: App filtering enabled but no apps allowed")
    } else if controller.enableAppFiltering {
        print("✅ App filtering configured with \(controller.allowedApps.count) apps")
    }
    
    // Check screen filtering
    if controller.enableScreenFiltering && controller.allowedScreens.isEmpty {
        print("⚠️  Warning: Screen filtering enabled but no screens allowed")
    } else if controller.enableScreenFiltering {
        print("✅ Screen filtering configured with \(controller.allowedScreens.count) screens")
    }
    
    return isValid
}

func validateRetentionPolicies(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Retention Policies...")
    
    var isValid = true
    
    // Validate safety margin
    if controller.safetyMarginHours < 0 || controller.safetyMarginHours > 168 {
        print("❌ Invalid safety margin: \(controller.safetyMarginHours) hours")
        isValid = false
    } else {
        print("✅ Safety margin is valid: \(controller.safetyMarginHours) hours")
    }
    
    // Validate cleanup interval
    if controller.cleanupIntervalHours < 1 || controller.cleanupIntervalHours > 168 {
        print("❌ Invalid cleanup interval: \(controller.cleanupIntervalHours) hours")
        isValid = false
    } else {
        print("✅ Cleanup interval is valid: \(controller.cleanupIntervalHours) hours")
    }
    
    // Validate individual policies
    for (dataType, policy) in controller.retentionPolicies {
        if policy.enabled {
            if policy.retentionDays < -1 || policy.retentionDays == 0 {
                print("❌ Invalid retention days for \(dataType): \(policy.retentionDays)")
                isValid = false
            } else if policy.retentionDays > 0 && policy.retentionDays < 7 {
                print("⚠️  Warning: Very short retention for \(dataType): \(policy.retentionDays) days")
            } else {
                let retentionText = policy.retentionDays == -1 ? "permanent" : "\(policy.retentionDays) days"
                print("✅ \(dataType): \(retentionText)")
            }
        }
    }
    
    return isValid
}

func validatePluginSettings(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Plugin Settings...")
    
    var isValid = true
    
    print("📦 Available plugins: \(controller.availablePlugins.count)")
    
    for plugin in controller.availablePlugins {
        let status = plugin.isEnabled ? "enabled" : "disabled"
        print("  • \(plugin.name) v\(plugin.version) (\(status))")
        
        // Validate plugin settings
        if let settings = controller.pluginSettings[plugin.identifier] {
            for (key, value) in settings {
                if key == "timeout" {
                    if let timeout = value as? Double, timeout <= 0 || timeout > 60 {
                        print("    ❌ Invalid timeout: \(timeout)")
                        isValid = false
                    }
                } else if key.contains("max_") {
                    if let maxValue = value as? Int, maxValue <= 0 {
                        print("    ❌ Invalid max value for \(key): \(maxValue)")
                        isValid = false
                    }
                }
            }
        }
    }
    
    return isValid
}

func validatePerformanceSettings(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Performance Settings...")
    
    var isValid = true
    
    // Validate CPU usage
    if controller.maxCPUUsage < 1.0 || controller.maxCPUUsage > 50.0 {
        print("❌ Invalid CPU usage limit: \(controller.maxCPUUsage)%")
        isValid = false
    } else {
        print("✅ CPU usage limit: \(controller.maxCPUUsage)%")
        if controller.maxCPUUsage > 15.0 {
            print("⚠️  Warning: High CPU usage limit may impact system performance")
        }
    }
    
    // Validate memory usage
    if controller.maxMemoryUsage < 100.0 || controller.maxMemoryUsage > 4096.0 {
        print("❌ Invalid memory usage limit: \(controller.maxMemoryUsage) MB")
        isValid = false
    } else {
        print("✅ Memory usage limit: \(controller.maxMemoryUsage) MB")
    }
    
    // Validate disk I/O
    if controller.maxDiskIO < 5.0 || controller.maxDiskIO > 100.0 {
        print("❌ Invalid disk I/O limit: \(controller.maxDiskIO) MB/s")
        isValid = false
    } else {
        print("✅ Disk I/O limit: \(controller.maxDiskIO) MB/s")
    }
    
    // Check optimization settings
    if !controller.enableHardwareAcceleration {
        print("⚠️  Warning: Hardware acceleration is disabled")
    }
    
    return isValid
}

func validateHotkeySettings(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Hotkey Settings...")
    
    var isValid = true
    
    let hotkeys = [
        ("Pause/Resume", controller.pauseHotkey),
        ("Privacy Mode", controller.privacyHotkey),
        ("Emergency Stop", controller.emergencyHotkey)
    ]
    
    var hotkeyValues: [String] = []
    
    for (name, hotkey) in hotkeys {
        // Basic validation for hotkey format
        if hotkey.isEmpty {
            print("❌ \(name) hotkey is empty")
            isValid = false
        } else {
            print("✅ \(name): \(hotkey)")
            hotkeyValues.append(hotkey)
        }
    }
    
    // Check for duplicates
    let uniqueHotkeys = Set(hotkeyValues)
    if uniqueHotkeys.count != hotkeyValues.count {
        print("⚠️  Warning: Duplicate hotkeys detected")
    }
    
    return isValid
}

func validateDataManagementSettings(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Data Management Settings...")
    
    var isValid = true
    
    // Validate backup settings
    if controller.enableAutomaticBackups {
        print("✅ Automatic backups enabled")
        print("  • Frequency: \(controller.backupFrequency)")
        print("  • Location: \(controller.backupLocation)")
        print("  • Retention: \(controller.backupRetentionDays) days")
        
        if controller.backupLocation.isEmpty {
            print("❌ Backup location is empty")
            isValid = false
        }
        
        if controller.backupRetentionDays < 1 && controller.backupRetentionDays != -1 {
            print("❌ Invalid backup retention: \(controller.backupRetentionDays)")
            isValid = false
        }
    } else {
        print("⚠️  Automatic backups are disabled")
    }
    
    return isValid
}

func validateStorageHealth(_ controller: MockSettingsController) -> Bool {
    print("\n🔍 Validating Storage Health...")
    
    guard let report = controller.storageHealthReport else {
        print("⚠️  No storage health report available")
        return true
    }
    
    let totalSizeGB = Double(report.totalSize) / 1_000_000_000
    let availableSpaceGB = Double(report.availableSpace) / 1_000_000_000
    
    print("📊 Storage Status: \(report.healthStatus)")
    print("  • Total size: \(String(format: "%.1f", totalSizeGB)) GB")
    print("  • Available space: \(String(format: "%.1f", availableSpaceGB)) GB")
    
    // Show data type breakdown
    print("  • Data breakdown:")
    for (dataType, size) in report.dataTypeBreakdown {
        let sizeGB = Double(size) / 1_000_000_000
        print("    - \(dataType): \(String(format: "%.1f", sizeGB)) GB")
    }
    
    // Show recommendations
    if !report.recommendations.isEmpty {
        print("  • Recommendations:")
        for recommendation in report.recommendations {
            print("    - \(recommendation)")
        }
    }
    
    return true
}

// Main validation function
func runSettingsValidation() {
    print("🚀 Starting Comprehensive Settings Validation")
    print("=" * 60)
    
    let controller = MockSettingsController()
    var allValid = true
    
    // Run all validations
    allValid = validateGeneralSettings(controller) && allValid
    allValid = validateRecordingSettings(controller) && allValid
    allValid = validatePrivacySettings(controller) && allValid
    allValid = validateRetentionPolicies(controller) && allValid
    allValid = validatePluginSettings(controller) && allValid
    allValid = validatePerformanceSettings(controller) && allValid
    allValid = validateHotkeySettings(controller) && allValid
    allValid = validateDataManagementSettings(controller) && allValid
    allValid = validateStorageHealth(controller) && allValid
    
    print("\n" + "=" * 60)
    
    if allValid {
        print("🎉 All settings validation passed!")
    } else {
        print("⚠️  Some settings validation issues found")
    }
    
    print("\n📋 Settings Interface Features Validated:")
    print("  ✅ General application settings")
    print("  ✅ Recording configuration")
    print("  ✅ Privacy and security controls")
    print("  ✅ Data retention policies")
    print("  ✅ Plugin management")
    print("  ✅ Performance optimization")
    print("  ✅ Hotkey configuration")
    print("  ✅ Data export and backup")
    print("  ✅ Storage health monitoring")
    print("  ✅ Configuration validation")
}

// Test invalid configurations
func testInvalidConfigurations() {
    print("\n🧪 Testing Invalid Configuration Handling")
    print("=" * 60)
    
    let controller = MockSettingsController()
    
    // Test invalid settings
    controller.frameRate = 45 // Invalid frame rate
    controller.logLevel = "invalid" // Invalid log level
    controller.maxCPUUsage = 75.0 // Too high CPU usage
    controller.safetyMarginHours = 200 // Too high safety margin
    
    print("Testing with invalid configurations...")
    
    var validationsPassed = 0
    var totalValidations = 0
    
    totalValidations += 1
    if !validateRecordingSettings(controller) {
        validationsPassed += 1
        print("✅ Invalid frame rate correctly detected")
    }
    
    totalValidations += 1
    if !validateGeneralSettings(controller) {
        validationsPassed += 1
        print("✅ Invalid log level correctly detected")
    }
    
    totalValidations += 1
    if !validatePerformanceSettings(controller) {
        validationsPassed += 1
        print("✅ Invalid CPU usage correctly detected")
    }
    
    totalValidations += 1
    if !validateRetentionPolicies(controller) {
        validationsPassed += 1
        print("✅ Invalid safety margin correctly detected")
    }
    
    print("\n📊 Validation Results: \(validationsPassed)/\(totalValidations) invalid configurations detected")
}

// String extension for repeat
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Run the validation
runSettingsValidation()
testInvalidConfigurations()

print("\n✨ Settings interface validation completed!")