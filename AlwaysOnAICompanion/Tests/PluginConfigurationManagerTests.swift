import XCTest
@testable import AlwaysOnAICompanion

class PluginConfigurationManagerTests: XCTestCase {
    
    var configManager: PluginConfigurationManager!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginConfigurationManagerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        configManager = PluginConfigurationManager(configurationDirectory: tempDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Configuration Loading Tests
    
    func testLoadConfigurationsCreatesDefault() {
        // Configuration manager should create default configurations on first run
        let configurations = configManager.getAllConfigurations()
        
        XCTAssertEqual(configurations.count, 3) // Web, Productivity, Terminal
        
        let identifiers = configurations.map { $0.identifier }
        XCTAssertTrue(identifiers.contains("com.alwayson.plugins.web"))
        XCTAssertTrue(identifiers.contains("com.alwayson.plugins.productivity"))
        XCTAssertTrue(identifiers.contains("com.alwayson.plugins.terminal"))
    }
    
    func testGetConfiguration() {
        let webConfig = configManager.getConfiguration(for: "com.alwayson.plugins.web")
        
        XCTAssertNotNil(webConfig)
        XCTAssertEqual(webConfig?.identifier, "com.alwayson.plugins.web")
        XCTAssertEqual(webConfig?.name, "Web Application Parser")
        XCTAssertTrue(webConfig?.enabled ?? false)
    }
    
    func testGetNonexistentConfiguration() {
        let config = configManager.getConfiguration(for: "com.nonexistent.plugin")
        XCTAssertNil(config)
    }
    
    func testGetEnabledConfigurations() {
        let enabledConfigs = configManager.getEnabledConfigurations()
        
        // All default configurations should be enabled
        XCTAssertEqual(enabledConfigs.count, 3)
        XCTAssertTrue(enabledConfigs.allSatisfy { $0.enabled })
    }
    
    // MARK: - Configuration Management Tests
    
    func testUpdateConfiguration() {
        guard var webConfig = configManager.getConfiguration(for: "com.alwayson.plugins.web") else {
            XCTFail("Web configuration not found")
            return
        }
        
        // Modify the configuration
        webConfig.enabled = false
        webConfig.settings["new_setting"] = "test_value"
        
        configManager.updateConfiguration(webConfig)
        
        // Verify the update
        let updatedConfig = configManager.getConfiguration(for: "com.alwayson.plugins.web")
        XCTAssertNotNil(updatedConfig)
        XCTAssertFalse(updatedConfig?.enabled ?? true)
        XCTAssertEqual(updatedConfig?.settings["new_setting"] as? String, "test_value")
    }
    
    func testSetPluginEnabled() {
        configManager.setPluginEnabled("com.alwayson.plugins.web", enabled: false)
        
        let config = configManager.getConfiguration(for: "com.alwayson.plugins.web")
        XCTAssertFalse(config?.enabled ?? true)
        
        configManager.setPluginEnabled("com.alwayson.plugins.web", enabled: true)
        
        let enabledConfig = configManager.getConfiguration(for: "com.alwayson.plugins.web")
        XCTAssertTrue(enabledConfig?.enabled ?? false)
    }
    
    func testSetPluginEnabledNonexistent() {
        // Should not crash when setting enabled state for nonexistent plugin
        configManager.setPluginEnabled("com.nonexistent.plugin", enabled: true)
        
        let config = configManager.getConfiguration(for: "com.nonexistent.plugin")
        XCTAssertNil(config)
    }
    
    func testIsPluginEnabled() {
        XCTAssertTrue(configManager.isPluginEnabled("com.alwayson.plugins.web"))
        XCTAssertFalse(configManager.isPluginEnabled("com.nonexistent.plugin"))
        
        configManager.setPluginEnabled("com.alwayson.plugins.web", enabled: false)
        XCTAssertFalse(configManager.isPluginEnabled("com.alwayson.plugins.web"))
    }
    
    func testAddPluginConfiguration() {
        let newConfig = PluginConfigurationData(
            identifier: "com.test.plugin",
            name: "Test Plugin",
            version: "1.0.0",
            enabled: true,
            supportedApplications: ["com.test.app"],
            maxMemoryUsage: 50 * 1024 * 1024,
            maxExecutionTime: 15.0,
            settings: ["test_setting": true]
        )
        
        configManager.addPluginConfiguration(newConfig)
        
        let retrievedConfig = configManager.getConfiguration(for: "com.test.plugin")
        XCTAssertNotNil(retrievedConfig)
        XCTAssertEqual(retrievedConfig?.name, "Test Plugin")
        XCTAssertEqual(retrievedConfig?.settings["test_setting"] as? Bool, true)
        
        let allConfigs = configManager.getAllConfigurations()
        XCTAssertEqual(allConfigs.count, 4) // 3 default + 1 new
    }
    
    func testRemovePluginConfiguration() {
        configManager.removePluginConfiguration("com.alwayson.plugins.web")
        
        let config = configManager.getConfiguration(for: "com.alwayson.plugins.web")
        XCTAssertNil(config)
        
        let allConfigs = configManager.getAllConfigurations()
        XCTAssertEqual(allConfigs.count, 2) // 3 default - 1 removed
    }
    
    // MARK: - Validation Tests
    
    func testValidateValidConfiguration() {
        let validConfig = PluginConfigurationData(
            identifier: "com.test.valid",
            name: "Valid Plugin",
            version: "1.0.0",
            enabled: true,
            supportedApplications: ["com.test.app"],
            maxMemoryUsage: 100 * 1024 * 1024,
            maxExecutionTime: 30.0,
            settings: ["timeout": 10.0, "max_results": 100]
        )
        
        let errors = configManager.validateConfiguration(validConfig)
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testValidateInvalidConfiguration() {
        let invalidConfig = PluginConfigurationData(
            identifier: "", // Empty identifier
            name: "Invalid Plugin",
            version: "1.0.0",
            enabled: true,
            supportedApplications: [], // No supported applications
            maxMemoryUsage: -1, // Invalid memory limit
            maxExecutionTime: -5.0, // Invalid execution time
            settings: ["timeout": -1.0, "max_results": -10] // Invalid settings
        )
        
        let errors = configManager.validateConfiguration(invalidConfig)
        XCTAssertFalse(errors.isEmpty)
        
        let errorDescriptions = errors.map { $0.localizedDescription }
        XCTAssertTrue(errorDescriptions.contains { $0.contains("identifier cannot be empty") })
        XCTAssertTrue(errorDescriptions.contains { $0.contains("must support at least one application") })
        XCTAssertTrue(errorDescriptions.contains { $0.contains("invalid memory limit") })
        XCTAssertTrue(errorDescriptions.contains { $0.contains("invalid execution time") })
    }
    
    // MARK: - Persistence Tests
    
    func testSaveAndLoadConfigurations() {
        // Add a custom configuration
        let customConfig = PluginConfigurationData(
            identifier: "com.test.custom",
            name: "Custom Plugin",
            version: "2.0.0",
            enabled: false,
            supportedApplications: ["com.custom.app"],
            maxMemoryUsage: 75 * 1024 * 1024,
            maxExecutionTime: 20.0,
            settings: ["custom_setting": "custom_value"]
        )
        
        configManager.addPluginConfiguration(customConfig)
        
        // Create a new configuration manager with the same directory
        let newConfigManager = PluginConfigurationManager(configurationDirectory: tempDirectory)
        
        // Verify the custom configuration was loaded
        let loadedConfig = newConfigManager.getConfiguration(for: "com.test.custom")
        XCTAssertNotNil(loadedConfig)
        XCTAssertEqual(loadedConfig?.name, "Custom Plugin")
        XCTAssertEqual(loadedConfig?.version, "2.0.0")
        XCTAssertFalse(loadedConfig?.enabled ?? true)
        XCTAssertEqual(loadedConfig?.settings["custom_setting"] as? String, "custom_value")
    }
    
    // MARK: - Default Configuration Tests
    
    func testDefaultWebPluginConfiguration() {
        let webConfig = configManager.getConfiguration(for: "com.alwayson.plugins.web")
        
        XCTAssertNotNil(webConfig)
        XCTAssertEqual(webConfig?.identifier, "com.alwayson.plugins.web")
        XCTAssertEqual(webConfig?.name, "Web Application Parser")
        XCTAssertTrue(webConfig?.enabled ?? false)
        XCTAssertTrue(webConfig?.supportedApplications.contains("com.apple.Safari") ?? false)
        XCTAssertTrue(webConfig?.supportedApplications.contains("com.google.Chrome") ?? false)
        XCTAssertEqual(webConfig?.maxMemoryUsage, 100 * 1024 * 1024)
        XCTAssertEqual(webConfig?.maxExecutionTime, 30.0, accuracy: 0.001)
        XCTAssertTrue(webConfig?.sandboxEnabled ?? false)
        
        // Check default settings
        XCTAssertEqual(webConfig?.settings["extract_forms"] as? Bool, true)
        XCTAssertEqual(webConfig?.settings["detect_navigation"] as? Bool, true)
        XCTAssertEqual(webConfig?.settings["parse_tables"] as? Bool, true)
        XCTAssertEqual(webConfig?.settings["max_table_rows"] as? Int, 1000)
        XCTAssertEqual(webConfig?.settings["timeout"] as? Double, 10.0, accuracy: 0.001)
    }
    
    func testDefaultProductivityPluginConfiguration() {
        let productivityConfig = configManager.getConfiguration(for: "com.alwayson.plugins.productivity")
        
        XCTAssertNotNil(productivityConfig)
        XCTAssertEqual(productivityConfig?.identifier, "com.alwayson.plugins.productivity")
        XCTAssertEqual(productivityConfig?.name, "Productivity Application Parser")
        XCTAssertTrue(productivityConfig?.enabled ?? false)
        XCTAssertTrue(productivityConfig?.supportedApplications.contains("com.atlassian.jira") ?? false)
        XCTAssertTrue(productivityConfig?.supportedApplications.contains("com.salesforce.*") ?? false)
        XCTAssertEqual(productivityConfig?.maxMemoryUsage, 150 * 1024 * 1024)
        XCTAssertEqual(productivityConfig?.maxExecutionTime, 45.0, accuracy: 0.001)
        
        // Check default settings
        XCTAssertEqual(productivityConfig?.settings["detect_jira_issues"] as? Bool, true)
        XCTAssertEqual(productivityConfig?.settings["parse_salesforce_records"] as? Bool, true)
        XCTAssertEqual(productivityConfig?.settings["extract_workflow_states"] as? Bool, true)
        XCTAssertEqual(productivityConfig?.settings["track_time_entries"] as? Bool, true)
        XCTAssertEqual(productivityConfig?.settings["max_field_pairs"] as? Int, 500)
        XCTAssertEqual(productivityConfig?.settings["timeout"] as? Double, 15.0, accuracy: 0.001)
    }
    
    func testDefaultTerminalPluginConfiguration() {
        let terminalConfig = configManager.getConfiguration(for: "com.alwayson.plugins.terminal")
        
        XCTAssertNotNil(terminalConfig)
        XCTAssertEqual(terminalConfig?.identifier, "com.alwayson.plugins.terminal")
        XCTAssertEqual(terminalConfig?.name, "Terminal Application Parser")
        XCTAssertTrue(terminalConfig?.enabled ?? false)
        XCTAssertTrue(terminalConfig?.supportedApplications.contains("com.apple.Terminal") ?? false)
        XCTAssertTrue(terminalConfig?.supportedApplications.contains("com.googlecode.iterm2") ?? false)
        XCTAssertEqual(terminalConfig?.maxMemoryUsage, 75 * 1024 * 1024)
        XCTAssertEqual(terminalConfig?.maxExecutionTime, 20.0, accuracy: 0.001)
        
        // Check default settings
        XCTAssertEqual(terminalConfig?.settings["track_command_history"] as? Bool, true)
        XCTAssertEqual(terminalConfig?.settings["detect_file_operations"] as? Bool, true)
        XCTAssertEqual(terminalConfig?.settings["parse_system_info"] as? Bool, true)
        XCTAssertEqual(terminalConfig?.settings["extract_error_messages"] as? Bool, true)
        XCTAssertEqual(terminalConfig?.settings["max_command_length"] as? Int, 1000)
        XCTAssertEqual(terminalConfig?.settings["timeout"] as? Double, 5.0, accuracy: 0.001)
    }
}

// MARK: - PluginConfigurationData Tests

class PluginConfigurationDataTests: XCTestCase {
    
    func testPluginConfigurationDataCodable() throws {
        let originalConfig = PluginConfigurationData(
            identifier: "com.test.plugin",
            name: "Test Plugin",
            version: "1.0.0",
            enabled: true,
            supportedApplications: ["com.test.app1", "com.test.app2"],
            maxMemoryUsage: 100 * 1024 * 1024,
            maxExecutionTime: 30.0,
            sandboxEnabled: true,
            settings: [
                "string_setting": "test_value",
                "bool_setting": true,
                "int_setting": 42,
                "double_setting": 3.14,
                "array_setting": ["item1", "item2"],
                "dict_setting": ["key": "value"]
            ]
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConfig)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(PluginConfigurationData.self, from: data)
        
        // Verify all properties
        XCTAssertEqual(decodedConfig.identifier, originalConfig.identifier)
        XCTAssertEqual(decodedConfig.name, originalConfig.name)
        XCTAssertEqual(decodedConfig.version, originalConfig.version)
        XCTAssertEqual(decodedConfig.enabled, originalConfig.enabled)
        XCTAssertEqual(decodedConfig.supportedApplications, originalConfig.supportedApplications)
        XCTAssertEqual(decodedConfig.maxMemoryUsage, originalConfig.maxMemoryUsage)
        XCTAssertEqual(decodedConfig.maxExecutionTime, originalConfig.maxExecutionTime, accuracy: 0.001)
        XCTAssertEqual(decodedConfig.sandboxEnabled, originalConfig.sandboxEnabled)
        
        // Verify settings
        XCTAssertEqual(decodedConfig.settings["string_setting"] as? String, "test_value")
        XCTAssertEqual(decodedConfig.settings["bool_setting"] as? Bool, true)
        XCTAssertEqual(decodedConfig.settings["int_setting"] as? Int, 42)
        XCTAssertEqual(decodedConfig.settings["double_setting"] as? Double, 3.14, accuracy: 0.001)
        
        let arrayValue = decodedConfig.settings["array_setting"] as? [String]
        XCTAssertEqual(arrayValue, ["item1", "item2"])
        
        let dictValue = decodedConfig.settings["dict_setting"] as? [String: String]
        XCTAssertEqual(dictValue?["key"], "value")
    }
    
    func testPluginConfigurationFileStructure() throws {
        let configs = [
            PluginConfigurationData(
                identifier: "com.test.plugin1",
                name: "Test Plugin 1",
                version: "1.0.0",
                supportedApplications: ["com.test.app"],
                maxMemoryUsage: 50 * 1024 * 1024,
                maxExecutionTime: 15.0
            ),
            PluginConfigurationData(
                identifier: "com.test.plugin2",
                name: "Test Plugin 2",
                version: "2.0.0",
                supportedApplications: ["com.test.app2"],
                maxMemoryUsage: 75 * 1024 * 1024,
                maxExecutionTime: 25.0
            )
        ]
        
        let configFile = PluginConfigurationFile(version: "1.0", plugins: configs)
        
        // Test encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configFile)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedFile = try decoder.decode(PluginConfigurationFile.self, from: data)
        
        XCTAssertEqual(decodedFile.version, "1.0")
        XCTAssertEqual(decodedFile.plugins.count, 2)
        XCTAssertEqual(decodedFile.plugins[0].identifier, "com.test.plugin1")
        XCTAssertEqual(decodedFile.plugins[1].identifier, "com.test.plugin2")
    }
}

// MARK: - ValidationError Tests

class ValidationErrorTests: XCTestCase {
    
    func testValidationErrorDescriptions() {
        let emptyIdentifierError = ValidationError.emptyIdentifier
        XCTAssertEqual(emptyIdentifierError.errorDescription, "Plugin identifier cannot be empty")
        
        let noAppsError = ValidationError.noSupportedApplications("com.test.plugin")
        XCTAssertEqual(
            noAppsError.errorDescription,
            "Plugin com.test.plugin must support at least one application"
        )
        
        let memoryError = ValidationError.invalidMemoryLimit("com.test.plugin")
        XCTAssertEqual(
            memoryError.errorDescription,
            "Plugin com.test.plugin has invalid memory limit"
        )
        
        let timeError = ValidationError.invalidExecutionTime("com.test.plugin")
        XCTAssertEqual(
            timeError.errorDescription,
            "Plugin com.test.plugin has invalid execution time limit"
        )
        
        let settingError = ValidationError.invalidSettingValue("com.test.plugin", "timeout", "Must be positive")
        XCTAssertEqual(
            settingError.errorDescription,
            "Plugin com.test.plugin setting 'timeout': Must be positive"
        )
    }
}