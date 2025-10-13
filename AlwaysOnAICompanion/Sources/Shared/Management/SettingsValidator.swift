import Foundation
import CoreGraphics

/// Validates settings and configuration values
public class SettingsValidator {
    
    public init() {}
    
    // MARK: - Validation Results
    
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [ValidationError]
        public let warnings: [ValidationWarning]
        
        public init(isValid: Bool, errors: [ValidationError] = [], warnings: [ValidationWarning] = []) {
            self.isValid = isValid
            self.errors = errors
            self.warnings = warnings
        }
    }
    
    public struct ValidationError {
        public let field: String
        public let message: String
        public let suggestedValue: Any?
        
        public init(field: String, message: String, suggestedValue: Any? = nil) {
            self.field = field
            self.message = message
            self.suggestedValue = suggestedValue
        }
    }
    
    public struct ValidationWarning {
        public let field: String
        public let message: String
        public let recommendation: String?
        
        public init(field: String, message: String, recommendation: String? = nil) {
            self.field = field
            self.message = message
            self.recommendation = recommendation
        }
    }
    
    // MARK: - General Settings Validation
    
    public func validateGeneralSettings(
        launchAtStartup: Bool,
        showMenuBarIcon: Bool,
        showNotifications: Bool,
        enableLogging: Bool,
        logLevel: String,
        storageLocation: String
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate log level
        let validLogLevels = ["debug", "info", "warning", "error"]
        if !validLogLevels.contains(logLevel.lowercased()) {
            errors.append(ValidationError(
                field: "logLevel",
                message: "Invalid log level: \(logLevel)",
                suggestedValue: "info"
            ))
        }
        
        // Validate storage location
        if !storageLocation.isEmpty {
            let storageURL = URL(fileURLWithPath: storageLocation)
            if !FileManager.default.fileExists(atPath: storageURL.path) {
                warnings.append(ValidationWarning(
                    field: "storageLocation",
                    message: "Storage location does not exist: \(storageLocation)",
                    recommendation: "Create the directory or choose an existing location"
                ))
            }
            
            // Check if location is writable
            if !FileManager.default.isWritableFile(atPath: storageURL.path) {
                errors.append(ValidationError(
                    field: "storageLocation",
                    message: "Storage location is not writable: \(storageLocation)",
                    suggestedValue: NSHomeDirectory() + "/Documents/AlwaysOnAICompanion"
                ))
            }
        }
        
        // Validate menu bar icon setting
        if !showMenuBarIcon && !showNotifications {
            warnings.append(ValidationWarning(
                field: "showMenuBarIcon",
                message: "Both menu bar icon and notifications are disabled",
                recommendation: "Enable at least one to receive system feedback"
            ))
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Recording Settings Validation
    
    public func validateRecordingSettings(
        selectedDisplays: Set<CGDirectDisplayID>,
        frameRate: Int,
        quality: String,
        segmentDuration: Int
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate frame rate
        let validFrameRates = [15, 30, 60]
        if !validFrameRates.contains(frameRate) {
            errors.append(ValidationError(
                field: "frameRate",
                message: "Invalid frame rate: \(frameRate). Must be 15, 30, or 60 FPS",
                suggestedValue: 30
            ))
        }
        
        // Validate quality setting
        let validQualities = ["low", "medium", "high"]
        if !validQualities.contains(quality.lowercased()) {
            errors.append(ValidationError(
                field: "quality",
                message: "Invalid quality setting: \(quality)",
                suggestedValue: "medium"
            ))
        }
        
        // Validate segment duration
        let validDurations = [60, 120, 300] // 1, 2, 5 minutes
        if !validDurations.contains(segmentDuration) {
            errors.append(ValidationError(
                field: "segmentDuration",
                message: "Invalid segment duration: \(segmentDuration). Must be 60, 120, or 300 seconds",
                suggestedValue: 120
            ))
        }
        
        // Validate display selection
        if selectedDisplays.isEmpty {
            warnings.append(ValidationWarning(
                field: "selectedDisplays",
                message: "No displays selected for recording",
                recommendation: "Select at least one display to enable recording"
            ))
        }
        
        // Check for high resource usage combinations
        if frameRate == 60 && quality == "high" && selectedDisplays.count > 2 {
            warnings.append(ValidationWarning(
                field: "performance",
                message: "High resource usage configuration detected",
                recommendation: "Consider reducing frame rate or quality for better performance"
            ))
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Privacy Settings Validation
    
    public func validatePrivacySettings(
        enablePIIMasking: Bool,
        maskCreditCards: Bool,
        maskSSN: Bool,
        maskEmails: Bool,
        enableAppFiltering: Bool,
        allowedApps: [String],
        enableScreenFiltering: Bool,
        allowedScreens: Set<CGDirectDisplayID>
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate PII masking configuration
        if !enablePIIMasking && (maskCreditCards || maskSSN || maskEmails) {
            warnings.append(ValidationWarning(
                field: "enablePIIMasking",
                message: "PII masking is disabled but specific masking options are enabled",
                recommendation: "Enable PII masking or disable specific masking options"
            ))
        }
        
        // Validate app filtering
        if enableAppFiltering && allowedApps.isEmpty {
            warnings.append(ValidationWarning(
                field: "allowedApps",
                message: "App filtering is enabled but no apps are allowed",
                recommendation: "Add applications to the allowlist or disable app filtering"
            ))
        }
        
        // Validate screen filtering
        if enableScreenFiltering && allowedScreens.isEmpty {
            warnings.append(ValidationWarning(
                field: "allowedScreens",
                message: "Screen filtering is enabled but no screens are allowed",
                recommendation: "Add screens to the allowlist or disable screen filtering"
            ))
        }
        
        // Validate app bundle IDs
        for app in allowedApps {
            if !isValidBundleID(app) {
                warnings.append(ValidationWarning(
                    field: "allowedApps",
                    message: "Invalid bundle ID format: \(app)",
                    recommendation: "Use proper bundle ID format (e.g., com.company.app)"
                ))
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Retention Policy Validation
    
    public func validateRetentionPolicies(
        enableRetentionPolicies: Bool,
        policies: [String: RetentionPolicyData],
        safetyMarginHours: Int,
        cleanupIntervalHours: Int,
        verificationEnabled: Bool
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate safety margin
        if safetyMarginHours < 0 || safetyMarginHours > 168 { // Max 1 week
            errors.append(ValidationError(
                field: "safetyMarginHours",
                message: "Safety margin must be between 0 and 168 hours",
                suggestedValue: 24
            ))
        }
        
        // Validate cleanup interval
        if cleanupIntervalHours < 1 || cleanupIntervalHours > 168 {
            errors.append(ValidationError(
                field: "cleanupIntervalHours",
                message: "Cleanup interval must be between 1 and 168 hours",
                suggestedValue: 24
            ))
        }
        
        // Validate individual policies
        for (dataType, policy) in policies {
            if policy.enabled {
                if policy.retentionDays < -1 || policy.retentionDays == 0 {
                    errors.append(ValidationError(
                        field: "retentionPolicies.\(dataType)",
                        message: "Invalid retention days: \(policy.retentionDays). Must be positive or -1 for permanent",
                        suggestedValue: 30
                    ))
                }
                
                // Warn about very short retention periods
                if policy.retentionDays > 0 && policy.retentionDays < 7 {
                    warnings.append(ValidationWarning(
                        field: "retentionPolicies.\(dataType)",
                        message: "Very short retention period: \(policy.retentionDays) days",
                        recommendation: "Consider longer retention for better data analysis"
                    ))
                }
            }
        }
        
        // Warn if retention is disabled
        if !enableRetentionPolicies {
            warnings.append(ValidationWarning(
                field: "enableRetentionPolicies",
                message: "Retention policies are disabled",
                recommendation: "Enable retention policies to manage storage usage"
            ))
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Performance Settings Validation
    
    public func validatePerformanceSettings(
        maxCPUUsage: Double,
        maxMemoryUsage: Double,
        maxDiskIO: Double,
        enableHardwareAcceleration: Bool,
        useBatchProcessing: Bool,
        enableCompression: Bool
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate CPU usage limit
        if maxCPUUsage < 1.0 || maxCPUUsage > 50.0 {
            errors.append(ValidationError(
                field: "maxCPUUsage",
                message: "CPU usage limit must be between 1% and 50%",
                suggestedValue: 8.0
            ))
        }
        
        // Validate memory usage limit
        if maxMemoryUsage < 100.0 || maxMemoryUsage > 4096.0 {
            errors.append(ValidationError(
                field: "maxMemoryUsage",
                message: "Memory usage limit must be between 100MB and 4GB",
                suggestedValue: 512.0
            ))
        }
        
        // Validate disk I/O limit
        if maxDiskIO < 5.0 || maxDiskIO > 100.0 {
            errors.append(ValidationError(
                field: "maxDiskIO",
                message: "Disk I/O limit must be between 5MB/s and 100MB/s",
                suggestedValue: 20.0
            ))
        }
        
        // Performance optimization warnings
        if maxCPUUsage > 15.0 {
            warnings.append(ValidationWarning(
                field: "maxCPUUsage",
                message: "High CPU usage limit may impact system performance",
                recommendation: "Consider reducing CPU limit for better system responsiveness"
            ))
        }
        
        if !enableHardwareAcceleration {
            warnings.append(ValidationWarning(
                field: "enableHardwareAcceleration",
                message: "Hardware acceleration is disabled",
                recommendation: "Enable hardware acceleration for better performance"
            ))
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Hotkey Validation
    
    public func validateHotkeySettings(
        pauseHotkey: String,
        privacyHotkey: String,
        emergencyHotkey: String
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let hotkeys = [
            ("pauseHotkey", pauseHotkey),
            ("privacyHotkey", privacyHotkey),
            ("emergencyHotkey", emergencyHotkey)
        ]
        
        // Validate hotkey format
        for (field, hotkey) in hotkeys {
            if !isValidHotkeyFormat(hotkey) {
                errors.append(ValidationError(
                    field: field,
                    message: "Invalid hotkey format: \(hotkey)",
                    suggestedValue: "⌘⇧P"
                ))
            }
        }
        
        // Check for duplicate hotkeys
        let hotkeyValues = [pauseHotkey, privacyHotkey, emergencyHotkey]
        let uniqueHotkeys = Set(hotkeyValues)
        if uniqueHotkeys.count != hotkeyValues.count {
            warnings.append(ValidationWarning(
                field: "hotkeys",
                message: "Duplicate hotkeys detected",
                recommendation: "Use unique hotkey combinations for each function"
            ))
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Plugin Configuration Validation
    
    public func validatePluginConfiguration(
        pluginId: String,
        settings: [String: Any]
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate plugin-specific settings based on plugin type
        switch pluginId {
        case let id where id.contains("web"):
            return validateWebPluginSettings(settings)
        case let id where id.contains("productivity"):
            return validateProductivityPluginSettings(settings)
        case let id where id.contains("terminal"):
            return validateTerminalPluginSettings(settings)
        default:
            return validateGenericPluginSettings(settings)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func isValidBundleID(_ bundleID: String) -> Bool {
        let bundleIDPattern = "^[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+(\\.[a-zA-Z0-9-]+)*$"
        let regex = try? NSRegularExpression(pattern: bundleIDPattern)
        let range = NSRange(location: 0, length: bundleID.utf16.count)
        return regex?.firstMatch(in: bundleID, options: [], range: range) != nil
    }
    
    private func isValidHotkeyFormat(_ hotkey: String) -> Bool {
        // Basic validation for hotkey format (⌘, ⇧, ⌥, ⌃ + letter/number)
        let hotkeyPattern = "^[⌘⇧⌥⌃]+[A-Za-z0-9]$"
        let regex = try? NSRegularExpression(pattern: hotkeyPattern)
        let range = NSRange(location: 0, length: hotkey.utf16.count)
        return regex?.firstMatch(in: hotkey, options: [], range: range) != nil
    }
    
    private func validateWebPluginSettings(_ settings: [String: Any]) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate timeout setting
        if let timeout = settings["timeout"] as? Double {
            if timeout <= 0 || timeout > 60 {
                errors.append(ValidationError(
                    field: "timeout",
                    message: "Timeout must be between 0 and 60 seconds",
                    suggestedValue: 10.0
                ))
            }
        }
        
        // Validate max table rows
        if let maxRows = settings["max_table_rows"] as? Int {
            if maxRows < 10 || maxRows > 10000 {
                warnings.append(ValidationWarning(
                    field: "max_table_rows",
                    message: "Max table rows should be between 10 and 10,000",
                    recommendation: "Adjust for optimal performance"
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func validateProductivityPluginSettings(_ settings: [String: Any]) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate max field pairs
        if let maxPairs = settings["max_field_pairs"] as? Int {
            if maxPairs < 10 || maxPairs > 1000 {
                warnings.append(ValidationWarning(
                    field: "max_field_pairs",
                    message: "Max field pairs should be between 10 and 1,000",
                    recommendation: "Adjust based on application complexity"
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func validateTerminalPluginSettings(_ settings: [String: Any]) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Validate max command length
        if let maxLength = settings["max_command_length"] as? Int {
            if maxLength < 100 || maxLength > 10000 {
                warnings.append(ValidationWarning(
                    field: "max_command_length",
                    message: "Max command length should be between 100 and 10,000 characters",
                    recommendation: "Adjust based on typical command complexity"
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func validateGenericPluginSettings(_ settings: [String: Any]) -> ValidationResult {
        var warnings: [ValidationWarning] = []
        
        // Generic validation for unknown plugin types
        if settings.isEmpty {
            warnings.append(ValidationWarning(
                field: "settings",
                message: "No settings configured for plugin",
                recommendation: "Review plugin documentation for available settings"
            ))
        }
        
        return ValidationResult(isValid: true, errors: [], warnings: warnings)
    }
}

// MARK: - Supporting Types

public struct RetentionPolicyData {
    public var enabled: Bool
    public var retentionDays: Int
    
    public init(enabled: Bool, retentionDays: Int) {
        self.enabled = enabled
        self.retentionDays = retentionDays
    }
}