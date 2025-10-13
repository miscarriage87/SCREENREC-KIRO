import Foundation
import os.log

/// Centralized log management and viewing system
public class LogManager: ObservableObject {
    public static let shared = LogManager()
    
    // MARK: - Published Properties
    @Published public var logEntries: [LogEntry] = []
    @Published public var filteredEntries: [LogEntry] = []
    @Published public var currentFilter: LogFilter = LogFilter()
    
    // MARK: - Configuration
    public struct LogConfiguration {
        var maxEntries: Int = 10000
        var logLevel: OSLogType = .debug
        var enableFileLogging: Bool = true
        var logDirectory: URL
        var rotationSize: Int64 = 10 * 1024 * 1024 // 10MB
        var maxLogFiles: Int = 5
        
        init() {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            logDirectory = documentsPath.appendingPathComponent("AlwaysOnAI/Logs")
        }
    }
    
    public var configuration = LogConfiguration()
    
    // MARK: - Private Properties
    private let logger = os.Logger(subsystem: "com.alwaysonai.companion", category: "LogManager")
    private var logFileHandle: FileHandle?
    private var currentLogFile: URL?
    private let logQueue = DispatchQueue(label: "com.alwaysonai.logmanager", qos: .utility)
    
    private init() {
        setupLogging()
        loadRecentLogs()
    }
    
    // MARK: - Public Methods
    
    public func log(_ message: String, level: OSLogType = .default, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: URL(fileURLWithPath: file).lastPathComponent,
            function: function,
            line: line
        )
        
        logQueue.async {
            self.addLogEntry(entry)
        }
        
        // Also log to system logger
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .error:
            logger.error("\(message)")
        case .fault:
            logger.fault("\(message)")
        default:
            logger.log("\(message)")
        }
    }
    
    public func debug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    public func critical(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .fault, category: category, file: file, function: function, line: line)
    }
    
    public func applyFilter(_ filter: LogFilter) {
        currentFilter = filter
        
        DispatchQueue.main.async {
            self.filteredEntries = self.logEntries.filter { entry in
                // Level filter
                if !filter.levels.isEmpty && !filter.levels.contains(entry.level) {
                    return false
                }
                
                // Category filter
                if !filter.categories.isEmpty && !filter.categories.contains(entry.category) {
                    return false
                }
                
                // Text search
                if !filter.searchText.isEmpty {
                    let searchLower = filter.searchText.lowercased()
                    return entry.message.lowercased().contains(searchLower) ||
                           entry.category.lowercased().contains(searchLower) ||
                           entry.function.lowercased().contains(searchLower)
                }
                
                // Time range filter
                if let startDate = filter.startDate, entry.timestamp < startDate {
                    return false
                }
                
                if let endDate = filter.endDate, entry.timestamp > endDate {
                    return false
                }
                
                return true
            }
        }
    }
    
    public func clearLogs() {
        logQueue.async {
            DispatchQueue.main.async {
                self.logEntries.removeAll()
                self.filteredEntries.removeAll()
            }
            
            // Clear log files
            self.clearLogFiles()
        }
    }
    
    public func exportLogs(to url: URL, format: LogExportFormat = .json) throws {
        let entries = filteredEntries.isEmpty ? logEntries : filteredEntries
        
        switch format {
        case .json:
            let exportEntries = entries.map { LogEntryExport(from: $0) }
            let jsonData = try JSONEncoder().encode(exportEntries)
            try jsonData.write(to: url)
            
        case .csv:
            let csvContent = generateCSV(from: entries)
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
            
        case .text:
            let textContent = generateText(from: entries)
            try textContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    public func getLogStatistics() -> LogStatistics {
        let entries = logEntries
        
        let levelCounts = Dictionary(grouping: entries, by: { $0.level })
            .mapValues { $0.count }
        
        let categoryCounts = Dictionary(grouping: entries, by: { $0.category })
            .mapValues { $0.count }
        
        let errorEntries = entries.filter { $0.level == .error || $0.level == .fault }
        let recentErrors = errorEntries.filter { $0.timestamp > Date().addingTimeInterval(-3600) } // Last hour
        
        return LogStatistics(
            totalEntries: entries.count,
            levelCounts: levelCounts,
            categoryCounts: categoryCounts,
            errorCount: errorEntries.count,
            recentErrorCount: recentErrors.count,
            oldestEntry: entries.first?.timestamp,
            newestEntry: entries.last?.timestamp
        )
    }
    
    public func getAvailableCategories() -> [String] {
        return Array(Set(logEntries.map { $0.category })).sorted()
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        // Create log directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: configuration.logDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create log directory: \(error.localizedDescription)")
        }
        
        if configuration.enableFileLogging {
            setupFileLogging()
        }
    }
    
    private func setupFileLogging() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "alwaysonai_\(dateFormatter.string(from: Date())).log"
        currentLogFile = configuration.logDirectory.appendingPathComponent(filename)
        
        guard let logFile = currentLogFile else { return }
        
        // Create log file
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        
        do {
            logFileHandle = try FileHandle(forWritingTo: logFile)
        } catch {
            logger.error("Failed to open log file: \(error.localizedDescription)")
        }
    }
    
    private func addLogEntry(_ entry: LogEntry) {
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            
            // Maintain max entries limit
            if self.logEntries.count > self.configuration.maxEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.configuration.maxEntries)
            }
            
            // Update filtered entries if filter is active
            if !self.currentFilter.isEmpty {
                self.applyFilter(self.currentFilter)
            } else {
                self.filteredEntries = self.logEntries
            }
        }
        
        // Write to file if enabled
        if configuration.enableFileLogging {
            writeToFile(entry)
        }
        
        // Check for log rotation
        checkLogRotation()
    }
    
    private func writeToFile(_ entry: LogEntry) {
        guard let fileHandle = logFileHandle else { return }
        
        let logLine = formatLogEntry(entry) + "\n"
        if let data = logLine.data(using: .utf8) {
            fileHandle.write(data)
        }
    }
    
    private func formatLogEntry(_ entry: LogEntry) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        let levelString = entry.level.displayName.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
        let categoryString = entry.category.padding(toLength: 15, withPad: " ", startingAt: 0)
        
        return "[\(dateFormatter.string(from: entry.timestamp))] \(levelString) [\(categoryString)] \(entry.message) (\(entry.file):\(entry.line))"
    }
    
    private func checkLogRotation() {
        guard let logFile = currentLogFile,
              configuration.enableFileLogging else { return }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logFile.path)
            if let fileSize = attributes[.size] as? Int64,
               fileSize > configuration.rotationSize {
                rotateLogFile()
            }
        } catch {
            logger.error("Failed to check log file size: \(error.localizedDescription)")
        }
    }
    
    private func rotateLogFile() {
        // Close current file
        logFileHandle?.closeFile()
        logFileHandle = nil
        
        // Clean up old log files
        cleanupOldLogFiles()
        
        // Create new log file
        setupFileLogging()
    }
    
    private func cleanupOldLogFiles() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: configuration.logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            
            // Keep only the most recent files
            if logFiles.count > configuration.maxLogFiles {
                let filesToDelete = Array(logFiles.dropFirst(configuration.maxLogFiles))
                for file in filesToDelete {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            logger.error("Failed to cleanup old log files: \(error.localizedDescription)")
        }
    }
    
    private func clearLogFiles() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: configuration.logDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "log" }
            
            for file in logFiles {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            logger.error("Failed to clear log files: \(error.localizedDescription)")
        }
        
        // Recreate current log file
        if configuration.enableFileLogging {
            setupFileLogging()
        }
    }
    
    private func loadRecentLogs() {
        // Load recent logs from files on startup
        logQueue.async {
            self.loadLogsFromFiles()
        }
    }
    
    private func loadLogsFromFiles() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: configuration.logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            
            // Load from the most recent log files
            let filesToLoad = Array(logFiles.prefix(3)) // Load last 3 files
            
            for file in filesToLoad {
                loadEntriesFromFile(file)
            }
        } catch {
            logger.error("Failed to load logs from files: \(error.localizedDescription)")
        }
    }
    
    private func loadEntriesFromFile(_ file: URL) {
        do {
            let content = try String(contentsOf: file)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                if let entry = parseLogLine(line) {
                    DispatchQueue.main.async {
                        self.logEntries.append(entry)
                    }
                }
            }
        } catch {
            logger.error("Failed to load entries from file \(file.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    private func parseLogLine(_ line: String) -> LogEntry? {
        // Simple log line parsing - in a real implementation, this would be more robust
        // Format: [timestamp] LEVEL [category] message (file:line)
        
        guard !line.isEmpty else { return nil }
        
        // This is a simplified parser - a real implementation would use regex or proper parsing
        let components = line.components(separatedBy: "] ")
        guard components.count >= 3 else { return nil }
        
        // Extract timestamp
        let timestampString = String(components[0].dropFirst()) // Remove leading [
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = dateFormatter.date(from: timestampString) ?? Date()
        
        // Extract level and category (simplified)
        let level = OSLogType.info // Default level
        let category = "General" // Default category
        
        // Extract message
        let message = components.dropFirst(2).joined(separator: "] ")
        
        return LogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            file: "Unknown",
            function: "Unknown",
            line: 0
        )
    }
    
    private func generateCSV(from entries: [LogEntry]) -> String {
        var csv = "Timestamp,Level,Category,Message,File,Function,Line\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        for entry in entries {
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let level = entry.level.displayName
            let message = entry.message.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\"\(timestamp)\",\"\(level)\",\"\(entry.category)\",\"\(message)\",\"\(entry.file)\",\"\(entry.function)\",\(entry.line)\n"
        }
        
        return csv
    }
    
    private func generateText(from entries: [LogEntry]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        return entries.map { entry in
            formatLogEntry(entry)
        }.joined(separator: "\n")
    }
    
    deinit {
        logFileHandle?.closeFile()
    }
}

// MARK: - Data Structures

public struct LogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let level: OSLogType
    public let category: String
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    
    public init(timestamp: Date, level: OSLogType, category: String, message: String, file: String, function: String, line: Int) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
    }
}

// Simplified export structure for JSON serialization
public struct LogEntryExport: Codable {
    public let timestamp: Date
    public let level: String
    public let category: String
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    
    public init(from logEntry: LogEntry) {
        self.timestamp = logEntry.timestamp
        self.level = logEntry.level.displayName
        self.category = logEntry.category
        self.message = logEntry.message
        self.file = logEntry.file
        self.function = logEntry.function
        self.line = logEntry.line
    }
}

public struct LogFilter {
    public var levels: Set<OSLogType> = []
    public var categories: Set<String> = []
    public var searchText: String = ""
    public var startDate: Date?
    public var endDate: Date?
    
    public var isEmpty: Bool {
        return levels.isEmpty && categories.isEmpty && searchText.isEmpty && startDate == nil && endDate == nil
    }
    
    public init() {}
}

public enum LogExportFormat {
    case json
    case csv
    case text
}

public struct LogStatistics {
    public let totalEntries: Int
    public let levelCounts: [OSLogType: Int]
    public let categoryCounts: [String: Int]
    public let errorCount: Int
    public let recentErrorCount: Int
    public let oldestEntry: Date?
    public let newestEntry: Date?
}

// MARK: - Extensions

extension OSLogType {
    public var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .default: return "Default"
        case .error: return "Error"
        case .fault: return "Critical"
        default: return "Unknown"
        }
    }
}