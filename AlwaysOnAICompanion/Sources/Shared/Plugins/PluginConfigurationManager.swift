import Foundation

/// Manages plugin configurations and lifecycle
public class PluginConfigurationManager {
    
    private let configurationURL: URL
    private var configurations: [String: PluginConfigurationData] = [:]
    
    public init(configurationDirectory: URL) {
        self.configurationURL = configurationDirectory.appendingPathComponent("plugins.json")
        createConfigurationDirectoryIfNeeded(configurationDirectory)
        loadConfigurations()
    }
    
    // MARK: - Configuration Management
    
    /// Load plugin configurations from disk
    public func loadConfigurations() {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            Logger.shared.info("No plugin configuration file found, creating default configuration")
            createDefaultConfiguration()
            return
        }
        
        do {
            let data = try Data(contentsOf: configurationURL)
            let configData = try JSONDecoder().decode(PluginConfigurationFile.self, from: data)
            
            configurations = configData.plugins.reduce(into: [:]) { result, config in
                result[config.identifier] = config
            }
            
            Logger.shared.info("Loaded configurations for \(configurations.count) plugins")
        } catch {
            Logger.shared.error("Failed to load plugin configurations: \(error)")
            createDefaultConfiguration()
        }
    }
    
    /// Save plugin configurations to disk
    public func saveConfigurations() {
        do {
            let configFile = PluginConfigurationFile(
                version: "1.0",
                plugins: Array(configurations.values)
            )
            
            let data = try JSONEncoder().encode(configFile)
            try data.write(to: configurationURL)
            
            Logger.shared.info("Saved configurations for \(configurations.count) plugins")
        } catch {
            Logger.shared.error("Failed to save plugin configurations: \(error)")
        }
    }
    
    /// Get configuration for a specific plugin
    public func getConfiguration(for identifier: String) -> PluginConfigurationData? {
        return configurations[identifier]
    }
    
    /// Update configuration for a specific plugin
    public func updateConfiguration(_ config: PluginConfigurationData) {
        configurations[config.identifier] = config
        saveConfigurations()
        Logger.shared.info("Updated configuration for plugin: \(config.identifier)")
    }
    
    /// Enable or disable a plugin
    public func setPluginEnabled(_ identifier: String, enabled: Bool) {
        guard var config = configurations[identifier] else {
            Logger.shared.warning("Cannot set enabled state for unknown plugin: \(identifier)")
            return
        }
        
        config.enabled = enabled
        configurations[identifier] = config
        saveConfigurations()
        
        Logger.shared.info("Plugin \(identifier) \(enabled ? "enabled" : "disabled")")
    }
    
    /// Get all enabled plugin configurations
    public func getEnabledConfigurations() -> [PluginConfigurationData] {
        return configurations.values.filter { $0.enabled }
    }
    
    /// Get all plugin configurations
    public func getAllConfigurations() -> [PluginConfigurationData] {
        return Array(configurations.values)
    }
    
    /// Check if a plugin is enabled
    public func isPluginEnabled(_ identifier: String) -> Bool {
        return configurations[identifier]?.enabled ?? false
    }
    
    /// Add a new plugin configuration
    public func addPluginConfiguration(_ config: PluginConfigurationData) {
        configurations[config.identifier] = config
        saveConfigurations()
        Logger.shared.info("Added configuration for plugin: \(config.identifier)")
    }
    
    /// Remove a plugin configuration
    public func removePluginConfiguration(_ identifier: String) {
        configurations.removeValue(forKey: identifier)
        saveConfigurations()
        Logger.shared.info("Removed configuration for plugin: \(identifier)")
    }
    
    // MARK: - Validation
    
    /// Validate plugin configuration
    public func validateConfiguration(_ config: PluginConfigurationData) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Check identifier
        if config.identifier.isEmpty {
            errors.append(.emptyIdentifier)
        }
        
        // Check supported applications
        if config.supportedApplications.isEmpty {
            errors.append(.noSupportedApplications(config.identifier))
        }
        
        // Validate resource limits
        if config.maxMemoryUsage <= 0 {
            errors.append(.invalidMemoryLimit(config.identifier))
        }
        
        if config.maxExecutionTime <= 0 {
            errors.append(.invalidExecutionTime(config.identifier))
        }
        
        // Validate settings
        for (key, value) in config.settings {
            if let validationError = validateSetting(key: key, value: value, for: config.identifier) {
                errors.append(validationError)
            }
        }
        
        return errors
    }
    
    private func validateSetting(key: String, value: Any, for identifier: String) -> ValidationError? {
        // Add specific validation rules based on setting keys
        switch key {
        case "timeout":
            if let timeout = value as? TimeInterval, timeout <= 0 {
                return .invalidSettingValue(identifier, key, "Timeout must be positive")
            }
        case "max_results":
            if let maxResults = value as? Int, maxResults <= 0 {
                return .invalidSettingValue(identifier, key, "Max results must be positive")
            }
        case "enabled_features":
            if let features = value as? [String], features.isEmpty {
                return .invalidSettingValue(identifier, key, "At least one feature must be enabled")
            }
        default:
            break
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func createConfigurationDirectoryIfNeeded(_ directory: URL) {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    private func createDefaultConfiguration() {
        let defaultConfigs = [
            createDefaultWebPluginConfig(),
            createDefaultProductivityPluginConfig(),
            createDefaultTerminalPluginConfig()
        ]
        
        configurations = defaultConfigs.reduce(into: [:]) { result, config in
            result[config.identifier] = config
        }
        
        saveConfigurations()
    }
    
    private func createDefaultWebPluginConfig() -> PluginConfigurationData {
        return PluginConfigurationData(
            identifier: "com.alwayson.plugins.web",
            name: "Web Application Parser",
            version: "1.0.0",
            enabled: true,
            supportedApplications: [
                "com.apple.Safari",
                "com.google.Chrome",
                "com.mozilla.firefox",
                "com.microsoft.edgemac",
                "com.operasoftware.Opera"
            ],
            maxMemoryUsage: 100 * 1024 * 1024, // 100MB
            maxExecutionTime: 30.0,
            sandboxEnabled: true,
            settings: [
                "extract_forms": true,
                "detect_navigation": true,
                "parse_tables": true,
                "max_table_rows": 1000,
                "timeout": 10.0
            ]
        )
    }
    
    private func createDefaultProductivityPluginConfig() -> PluginConfigurationData {
        return PluginConfigurationData(
            identifier: "com.alwayson.plugins.productivity",
            name: "Productivity Application Parser",
            version: "1.0.0",
            enabled: true,
            supportedApplications: [
                "com.atlassian.jira",
                "com.salesforce.*",
                "com.microsoft.office.*",
                "com.google.chrome",
                "com.apple.Safari"
            ],
            maxMemoryUsage: 150 * 1024 * 1024, // 150MB
            maxExecutionTime: 45.0,
            sandboxEnabled: true,
            settings: [
                "detect_jira_issues": true,
                "parse_salesforce_records": true,
                "extract_workflow_states": true,
                "track_time_entries": true,
                "max_field_pairs": 500,
                "timeout": 15.0
            ]
        )
    }
    
    private func createDefaultTerminalPluginConfig() -> PluginConfigurationData {
        return PluginConfigurationData(
            identifier: "com.alwayson.plugins.terminal",
            name: "Terminal Application Parser",
            version: "1.0.0",
            enabled: true,
            supportedApplications: [
                "com.apple.Terminal",
                "com.googlecode.iterm2",
                "com.github.wez.wezterm",
                "org.alacritty",
                "com.microsoft.VSCode",
                "com.jetbrains.*"
            ],
            maxMemoryUsage: 75 * 1024 * 1024, // 75MB
            maxExecutionTime: 20.0,
            sandboxEnabled: true,
            settings: [
                "track_command_history": true,
                "detect_file_operations": true,
                "parse_system_info": true,
                "extract_error_messages": true,
                "max_command_length": 1000,
                "timeout": 5.0
            ]
        )
    }
}

// MARK: - Data Models

public struct PluginConfigurationFile: Codable {
    public let version: String
    public let plugins: [PluginConfigurationData]
    
    public init(version: String, plugins: [PluginConfigurationData]) {
        self.version = version
        self.plugins = plugins
    }
}

public struct PluginConfigurationData: Codable {
    public let identifier: String
    public let name: String
    public let version: String
    public var enabled: Bool
    public let supportedApplications: [String]
    public let maxMemoryUsage: Int64
    public let maxExecutionTime: TimeInterval
    public let sandboxEnabled: Bool
    public var settings: [String: Any]
    
    public init(
        identifier: String,
        name: String,
        version: String,
        enabled: Bool = true,
        supportedApplications: [String],
        maxMemoryUsage: Int64,
        maxExecutionTime: TimeInterval,
        sandboxEnabled: Bool = true,
        settings: [String: Any] = [:]
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.enabled = enabled
        self.supportedApplications = supportedApplications
        self.maxMemoryUsage = maxMemoryUsage
        self.maxExecutionTime = maxExecutionTime
        self.sandboxEnabled = sandboxEnabled
        self.settings = settings
    }
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case identifier, name, version, enabled, supportedApplications
        case maxMemoryUsage, maxExecutionTime, sandboxEnabled, settings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        identifier = try container.decode(String.self, forKey: .identifier)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        supportedApplications = try container.decode([String].self, forKey: .supportedApplications)
        maxMemoryUsage = try container.decode(Int64.self, forKey: .maxMemoryUsage)
        maxExecutionTime = try container.decode(TimeInterval.self, forKey: .maxExecutionTime)
        sandboxEnabled = try container.decodeIfPresent(Bool.self, forKey: .sandboxEnabled) ?? true
        
        // Decode settings as [String: Any]
        if let settingsData = try? container.decode([String: AnyCodable].self, forKey: .settings) {
            settings = settingsData.mapValues { $0.value }
        } else {
            settings = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(identifier, forKey: .identifier)
        try container.encode(name, forKey: .name)
        try container.encode(version, forKey: .version)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(supportedApplications, forKey: .supportedApplications)
        try container.encode(maxMemoryUsage, forKey: .maxMemoryUsage)
        try container.encode(maxExecutionTime, forKey: .maxExecutionTime)
        try container.encode(sandboxEnabled, forKey: .sandboxEnabled)
        
        // Encode settings as [String: AnyCodable]
        let encodableSettings = settings.mapValues { AnyCodable($0) }
        try container.encode(encodableSettings, forKey: .settings)
    }
}

// Helper for encoding/decoding Any values
private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            struct UnsupportedTypeError: Error {
                let description: String
            }
            throw UnsupportedTypeError(description: "Cannot encode value of type \(type(of: value))")
        }
    }
}

public enum ValidationError: Error, LocalizedError {
    case emptyIdentifier
    case noSupportedApplications(String)
    case invalidMemoryLimit(String)
    case invalidExecutionTime(String)
    case invalidSettingValue(String, String, String) // plugin, key, reason
    
    public var errorDescription: String? {
        switch self {
        case .emptyIdentifier:
            return "Plugin identifier cannot be empty"
        case .noSupportedApplications(let identifier):
            return "Plugin \(identifier) must support at least one application"
        case .invalidMemoryLimit(let identifier):
            return "Plugin \(identifier) has invalid memory limit"
        case .invalidExecutionTime(let identifier):
            return "Plugin \(identifier) has invalid execution time limit"
        case .invalidSettingValue(let plugin, let key, let reason):
            return "Plugin \(plugin) setting '\(key)': \(reason)"
        }
    }
}