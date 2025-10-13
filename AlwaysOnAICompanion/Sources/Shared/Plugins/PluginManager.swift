import Foundation
import CoreGraphics

/// Manages plugin loading, lifecycle, and execution with sandboxing
public class PluginManager {
    
    private var loadedPlugins: [String: PluginContainer] = [:]
    private var pluginConfigurations: [String: PluginConfiguration] = [:]
    private let pluginDirectory: URL
    private let sandboxEnabled: Bool
    
    public init(pluginDirectory: URL, sandboxEnabled: Bool = true) {
        self.pluginDirectory = pluginDirectory
        self.sandboxEnabled = sandboxEnabled
        createPluginDirectoryIfNeeded()
    }
    
    // MARK: - Plugin Loading
    
    /// Load all plugins from the plugin directory
    public func loadAllPlugins() throws {
        Logger.shared.info("Loading plugins from directory: \(pluginDirectory.path)")
        
        let pluginURLs = try FileManager.default.contentsOfDirectory(
            at: pluginDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            return isDirectory.boolValue && url.pathExtension == "plugin"
        }
        
        for pluginURL in pluginURLs {
            do {
                try loadPlugin(at: pluginURL)
            } catch {
                Logger.shared.error("Failed to load plugin at \(pluginURL.path): \(error)")
            }
        }
        
        Logger.shared.info("Loaded \(loadedPlugins.count) plugins successfully")
    }
    
    /// Load a specific plugin from a URL
    public func loadPlugin(at url: URL) throws {
        let manifestURL = url.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PluginError.missingManifest(url)
        }
        
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)
        
        // Check if plugin is already loaded
        if loadedPlugins[manifest.identifier] != nil {
            Logger.shared.warning("Plugin \(manifest.identifier) is already loaded")
            return
        }
        
        // Load plugin configuration
        let configuration = try loadPluginConfiguration(for: manifest, at: url)
        
        // Create plugin instance
        let plugin = try createPluginInstance(manifest: manifest, at: url)
        
        // Initialize plugin in sandbox
        let container = PluginContainer(
            plugin: plugin,
            manifest: manifest,
            configuration: configuration,
            pluginURL: url
        )
        
        try container.initialize()
        
        loadedPlugins[manifest.identifier] = container
        pluginConfigurations[manifest.identifier] = configuration
        
        Logger.shared.info("Successfully loaded plugin: \(manifest.identifier) v\(manifest.version)")
    }
    
    /// Unload a specific plugin
    public func unloadPlugin(identifier: String) {
        guard let container = loadedPlugins[identifier] else {
            Logger.shared.warning("Plugin \(identifier) is not loaded")
            return
        }
        
        container.cleanup()
        loadedPlugins.removeValue(forKey: identifier)
        pluginConfigurations.removeValue(forKey: identifier)
        
        Logger.shared.info("Unloaded plugin: \(identifier)")
    }
    
    /// Unload all plugins
    public func unloadAllPlugins() {
        for identifier in loadedPlugins.keys {
            unloadPlugin(identifier: identifier)
        }
    }
    
    // MARK: - Plugin Execution
    
    /// Get all parsing plugins that can handle the given context
    public func getParsingPlugins(for context: ApplicationContext) -> [ParsingPluginProtocol] {
        return loadedPlugins.values.compactMap { container in
            guard let parsingPlugin = container.plugin as? ParsingPluginProtocol,
                  container.plugin.canHandle(context: context) else {
                return nil
            }
            return parsingPlugin
        }
    }
    
    /// Get all event detection plugins that can handle the given context
    public func getEventDetectionPlugins(for context: ApplicationContext) -> [EventDetectionPluginProtocol] {
        return loadedPlugins.values.compactMap { container in
            guard let eventPlugin = container.plugin as? EventDetectionPluginProtocol,
                  container.plugin.canHandle(context: context) else {
                return nil
            }
            return eventPlugin
        }
    }
    
    /// Execute parsing enhancement with timeout and error handling
    public func enhanceOCRResults(
        _ results: [OCRResult],
        context: ApplicationContext,
        frame: CGImage
    ) async -> [EnhancedOCRResult] {
        let plugins = getParsingPlugins(for: context)
        var allEnhancedResults: [EnhancedOCRResult] = []
        
        for plugin in plugins {
            do {
                let enhancedResults = try await withTimeout(
                    seconds: pluginConfigurations[plugin.identifier]?.maxExecutionTime ?? 30.0
                ) {
                    try await plugin.enhanceOCRResults(results, context: context, frame: frame)
                }
                allEnhancedResults.append(contentsOf: enhancedResults)
            } catch {
                Logger.shared.error("Plugin \(plugin.identifier) failed to enhance OCR results: \(error)")
            }
        }
        
        return allEnhancedResults
    }
    
    /// Execute event detection with timeout and error handling
    public func detectEvents(
        from ocrDelta: OCRDelta,
        context: ApplicationContext
    ) async -> [DetectedEvent] {
        let plugins = getEventDetectionPlugins(for: context)
        var allEvents: [DetectedEvent] = []
        
        for plugin in plugins {
            do {
                let events = try await withTimeout(
                    seconds: pluginConfigurations[plugin.identifier]?.maxExecutionTime ?? 30.0
                ) {
                    try await plugin.detectEvents(from: ocrDelta, context: context)
                }
                allEvents.append(contentsOf: events)
            } catch {
                Logger.shared.error("Plugin \(plugin.identifier) failed to detect events: \(error)")
            }
        }
        
        return allEvents
    }
    
    // MARK: - Plugin Information
    
    /// Get information about all loaded plugins
    public func getLoadedPlugins() -> [PluginInfo] {
        return loadedPlugins.values.map { container in
            PluginInfo(
                identifier: container.plugin.identifier,
                name: container.plugin.name,
                version: container.plugin.version,
                description: container.plugin.description,
                supportedApplications: container.plugin.supportedApplications,
                isEnabled: true
            )
        }
    }
    
    /// Check if a plugin is loaded
    public func isPluginLoaded(_ identifier: String) -> Bool {
        return loadedPlugins[identifier] != nil
    }
    
    // MARK: - Private Methods
    
    private func createPluginDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: pluginDirectory.path) {
            try? FileManager.default.createDirectory(
                at: pluginDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    private func loadPluginConfiguration(for manifest: PluginManifest, at url: URL) throws -> PluginConfiguration {
        let configURL = url.appendingPathComponent("config.json")
        var configData: [String: Any] = [:]
        
        if FileManager.default.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            configData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        }
        
        return PluginConfiguration(
            pluginDirectory: url,
            configurationData: configData,
            sandboxEnabled: sandboxEnabled,
            maxMemoryUsage: manifest.maxMemoryUsage ?? 100 * 1024 * 1024,
            maxExecutionTime: manifest.maxExecutionTime ?? 30.0
        )
    }
    
    private func createPluginInstance(manifest: PluginManifest, at url: URL) throws -> PluginProtocol {
        // For now, we'll use a factory pattern to create built-in plugins
        // In a full implementation, this would load dynamic libraries
        switch manifest.type {
        case "web":
            return WebParsingPlugin()
        case "productivity":
            return ProductivityParsingPlugin()
        case "terminal":
            return TerminalParsingPlugin()
        default:
            throw PluginError.unsupportedPluginType(manifest.type)
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw PluginError.executionTimeout
            }
            
            guard let result = try await group.next() else {
                throw PluginError.executionTimeout
            }
            
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Supporting Types

private class PluginContainer {
    let plugin: PluginProtocol
    let manifest: PluginManifest
    let configuration: PluginConfiguration
    let pluginURL: URL
    
    init(plugin: PluginProtocol, manifest: PluginManifest, configuration: PluginConfiguration, pluginURL: URL) {
        self.plugin = plugin
        self.manifest = manifest
        self.configuration = configuration
        self.pluginURL = pluginURL
    }
    
    func initialize() throws {
        try plugin.initialize(configuration: configuration)
    }
    
    func cleanup() {
        plugin.cleanup()
    }
}

public struct PluginManifest: Codable {
    public let identifier: String
    public let name: String
    public let version: String
    public let description: String
    public let type: String
    public let supportedApplications: [String]
    public let maxMemoryUsage: Int64?
    public let maxExecutionTime: TimeInterval?
    public let author: String?
    public let website: String?
    
    public init(
        identifier: String,
        name: String,
        version: String,
        description: String,
        type: String,
        supportedApplications: [String],
        maxMemoryUsage: Int64? = nil,
        maxExecutionTime: TimeInterval? = nil,
        author: String? = nil,
        website: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.type = type
        self.supportedApplications = supportedApplications
        self.maxMemoryUsage = maxMemoryUsage
        self.maxExecutionTime = maxExecutionTime
        self.author = author
        self.website = website
    }
}

public struct PluginInfo {
    public let identifier: String
    public let name: String
    public let version: String
    public let description: String
    public let supportedApplications: [String]
    public let isEnabled: Bool
    
    public init(
        identifier: String,
        name: String,
        version: String,
        description: String,
        supportedApplications: [String],
        isEnabled: Bool
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.supportedApplications = supportedApplications
        self.isEnabled = isEnabled
    }
}

public enum PluginError: Error, LocalizedError {
    case missingManifest(URL)
    case unsupportedPluginType(String)
    case executionTimeout
    case initializationFailed(String)
    case sandboxViolation(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingManifest(let url):
            return "Plugin manifest not found at \(url.path)"
        case .unsupportedPluginType(let type):
            return "Unsupported plugin type: \(type)"
        case .executionTimeout:
            return "Plugin execution timed out"
        case .initializationFailed(let reason):
            return "Plugin initialization failed: \(reason)"
        case .sandboxViolation(let reason):
            return "Plugin sandbox violation: \(reason)"
        }
    }
}