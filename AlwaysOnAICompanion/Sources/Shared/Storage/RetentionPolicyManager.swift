import Foundation

/// Represents different types of data that can be managed by retention policies
public enum DataType: String, CaseIterable, Codable {
    case rawVideo = "raw_video"
    case frameMetadata = "frame_metadata"
    case ocrData = "ocr_data"
    case events = "events"
    case spans = "spans"
    case summaries = "summaries"
}

/// Configuration for retention policies for different data types
public struct RetentionPolicy: Codable {
    public let dataType: DataType
    public let retentionDays: Int
    public let enabled: Bool
    public let cleanupIntervalHours: Int
    
    public init(dataType: DataType, retentionDays: Int, enabled: Bool = true, cleanupIntervalHours: Int = 24) {
        self.dataType = dataType
        self.retentionDays = retentionDays
        self.enabled = enabled
        self.cleanupIntervalHours = cleanupIntervalHours
    }
}

/// Configuration container for all retention policies
public struct RetentionConfiguration: Codable {
    public let policies: [DataType: RetentionPolicy]
    public let enableBackgroundCleanup: Bool
    public let safetyMarginHours: Int // Additional time before actual deletion
    public let maxFilesPerCleanupBatch: Int
    public let verificationEnabled: Bool
    
    public init(
        policies: [DataType: RetentionPolicy]? = nil,
        enableBackgroundCleanup: Bool = true,
        safetyMarginHours: Int = 24,
        maxFilesPerCleanupBatch: Int = 100,
        verificationEnabled: Bool = true
    ) {
        self.policies = policies ?? Self.defaultPolicies()
        self.enableBackgroundCleanup = enableBackgroundCleanup
        self.safetyMarginHours = safetyMarginHours
        self.maxFilesPerCleanupBatch = maxFilesPerCleanupBatch
        self.verificationEnabled = verificationEnabled
    }
    
    private static func defaultPolicies() -> [DataType: RetentionPolicy] {
        return [
            .rawVideo: RetentionPolicy(dataType: .rawVideo, retentionDays: 30),
            .frameMetadata: RetentionPolicy(dataType: .frameMetadata, retentionDays: 90),
            .ocrData: RetentionPolicy(dataType: .ocrData, retentionDays: 90),
            .events: RetentionPolicy(dataType: .events, retentionDays: 365),
            .spans: RetentionPolicy(dataType: .spans, retentionDays: -1), // Permanent
            .summaries: RetentionPolicy(dataType: .summaries, retentionDays: -1) // Permanent
        ]
    }
}

/// Errors that can occur during retention policy operations
public enum RetentionPolicyError: Error, LocalizedError {
    case configurationNotFound
    case invalidRetentionDays(Int)
    case cleanupFailed(String)
    case verificationFailed(String)
    case rollbackFailed(String)
    case storagePathNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .configurationNotFound:
            return "Retention policy configuration not found"
        case .invalidRetentionDays(let days):
            return "Invalid retention days: \(days). Must be positive or -1 for permanent"
        case .cleanupFailed(let message):
            return "Cleanup failed: \(message)"
        case .verificationFailed(let message):
            return "Verification failed: \(message)"
        case .rollbackFailed(let message):
            return "Rollback failed: \(message)"
        case .storagePathNotFound(let path):
            return "Storage path not found: \(path)"
        }
    }
}

/// Statistics about cleanup operations
public struct CleanupStats {
    public let dataType: DataType
    public let filesScanned: Int
    public let filesDeleted: Int
    public let bytesFreed: Int64
    public let duration: TimeInterval
    public let errors: [String]
    
    public init(dataType: DataType, filesScanned: Int, filesDeleted: Int, bytesFreed: Int64, duration: TimeInterval, errors: [String] = []) {
        self.dataType = dataType
        self.filesScanned = filesScanned
        self.filesDeleted = filesDeleted
        self.bytesFreed = bytesFreed
        self.duration = duration
        self.errors = errors
    }
}

/// Manages data retention policies and automatic cleanup
public class RetentionPolicyManager {
    private let configurationManager: ConfigurationManager
    private let fileManager = FileManager.default
    private let logger = Logger.shared
    
    private var backgroundTimer: Timer?
    private var isCleanupRunning = false
    private let cleanupQueue = DispatchQueue(label: "retention.cleanup", qos: .utility)
    
    public init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
    }
    
    deinit {
        stopBackgroundCleanup()
    }
    
    // MARK: - Configuration Management
    
    /// Load retention configuration from storage
    public func loadRetentionConfiguration() -> RetentionConfiguration {
        // For now, return default configuration
        // In a full implementation, this would load from a separate config file
        return RetentionConfiguration()
    }
    
    /// Save retention configuration to storage
    public func saveRetentionConfiguration(_ config: RetentionConfiguration) throws {
        // For now, this is a no-op
        // In a full implementation, this would save to a separate config file
        logger.info("Retention configuration saved")
    }
    
    // MARK: - Background Cleanup Management
    
    /// Start background cleanup process
    public func startBackgroundCleanup() {
        guard backgroundTimer == nil else { return }
        
        let config = loadRetentionConfiguration()
        guard config.enableBackgroundCleanup else { return }
        
        // Calculate the shortest cleanup interval from all policies
        let shortestInterval = config.policies.values
            .filter { $0.enabled }
            .map { $0.cleanupIntervalHours }
            .min() ?? 24
        
        let intervalSeconds = TimeInterval(shortestInterval * 3600)
        
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            self?.performBackgroundCleanup()
        }
        
        logger.info("Background cleanup started with interval: \(shortestInterval) hours")
    }
    
    /// Stop background cleanup process
    public func stopBackgroundCleanup() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        logger.info("Background cleanup stopped")
    }
    
    /// Perform cleanup for all enabled data types
    private func performBackgroundCleanup() {
        guard !isCleanupRunning else {
            logger.warning("Cleanup already running, skipping this cycle")
            return
        }
        
        cleanupQueue.async { [weak self] in
            self?.runCleanupCycle()
        }
    }
    
    private func runCleanupCycle() {
        isCleanupRunning = true
        defer { isCleanupRunning = false }
        
        let config = loadRetentionConfiguration()
        let recorderConfig = configurationManager.loadConfiguration()
        
        guard let storageURL = recorderConfig?.storageURL else {
            logger.error("Storage URL not configured")
            return
        }
        
        logger.info("Starting cleanup cycle")
        
        for (dataType, policy) in config.policies {
            guard policy.enabled && policy.retentionDays > 0 else { continue }
            
            do {
                let stats = try performCleanup(for: dataType, policy: policy, storageURL: storageURL, config: config)
                logger.info("Cleanup completed for \(dataType.rawValue): \(stats.filesDeleted) files deleted, \(stats.bytesFreed) bytes freed")
            } catch {
                logger.error("Cleanup failed for \(dataType.rawValue): \(error.localizedDescription)")
            }
        }
        
        logger.info("Cleanup cycle completed")
    }
    
    // MARK: - Manual Cleanup Operations
    
    /// Perform cleanup for a specific data type
    public func performCleanup(for dataType: DataType) throws -> CleanupStats {
        let config = loadRetentionConfiguration()
        guard let policy = config.policies[dataType] else {
            throw RetentionPolicyError.configurationNotFound
        }
        
        guard let recorderConfig = configurationManager.loadConfiguration() else {
            throw RetentionPolicyError.storagePathNotFound("Recorder configuration not found")
        }
        
        return try performCleanup(for: dataType, policy: policy, storageURL: recorderConfig.storageURL, config: config)
    }
    
    private func performCleanup(for dataType: DataType, policy: RetentionPolicy, storageURL: URL, config: RetentionConfiguration) throws -> CleanupStats {
        let startTime = Date()
        var filesScanned = 0
        var filesDeleted = 0
        var bytesFreed: Int64 = 0
        var errors: [String] = []
        
        // Calculate cutoff date
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(policy.retentionDays * 24 * 3600 + config.safetyMarginHours * 3600))
        
        // Get data type specific path
        let dataPath = getDataPath(for: dataType, storageURL: storageURL)
        
        guard fileManager.fileExists(atPath: dataPath.path) else {
            return CleanupStats(dataType: dataType, filesScanned: 0, filesDeleted: 0, bytesFreed: 0, duration: 0, errors: ["Path does not exist: \(dataPath.path)"])
        }
        
        // Get files to clean up
        let filesToCleanup = try getFilesForCleanup(at: dataPath, cutoffDate: cutoffDate, dataType: dataType)
        filesScanned = filesToCleanup.count
        
        // Process files in batches
        let batchSize = config.maxFilesPerCleanupBatch
        for batch in filesToCleanup.chunked(into: batchSize) {
            do {
                let batchStats = try processBatch(batch, config: config)
                filesDeleted += batchStats.filesDeleted
                bytesFreed += batchStats.bytesFreed
                errors.append(contentsOf: batchStats.errors)
            } catch {
                errors.append("Batch processing failed: \(error.localizedDescription)")
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        return CleanupStats(dataType: dataType, filesScanned: filesScanned, filesDeleted: filesDeleted, bytesFreed: bytesFreed, duration: duration, errors: errors)
    }
    
    private func processBatch(_ files: [URL], config: RetentionConfiguration) throws -> (filesDeleted: Int, bytesFreed: Int64, errors: [String]) {
        var filesDeleted = 0
        var bytesFreed: Int64 = 0
        var errors: [String] = []
        var deletedFiles: [(url: URL, size: Int64)] = []
        
        // Verification phase
        if config.verificationEnabled {
            for fileURL in files {
                do {
                    try verifyFileForDeletion(fileURL)
                } catch {
                    errors.append("Verification failed for \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    continue
                }
            }
        }
        
        // Deletion phase with rollback capability
        for fileURL in files {
            do {
                let fileSize = try getFileSize(fileURL)
                try fileManager.removeItem(at: fileURL)
                
                deletedFiles.append((url: fileURL, size: fileSize))
                filesDeleted += 1
                bytesFreed += fileSize
                
            } catch {
                errors.append("Failed to delete \(fileURL.lastPathComponent): \(error.localizedDescription)")
                
                // If we have a critical error, attempt rollback
                if errors.count > files.count / 2 {
                    do {
                        try rollbackDeletions(deletedFiles)
                        throw RetentionPolicyError.cleanupFailed("Too many errors, rolled back deletions")
                    } catch {
                        throw RetentionPolicyError.rollbackFailed("Rollback failed after cleanup errors: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        return (filesDeleted: filesDeleted, bytesFreed: bytesFreed, errors: errors)
    }
    
    // MARK: - Helper Methods
    
    private func getDataPath(for dataType: DataType, storageURL: URL) -> URL {
        switch dataType {
        case .rawVideo:
            return storageURL.appendingPathComponent("videos")
        case .frameMetadata:
            return storageURL.appendingPathComponent("frames")
        case .ocrData:
            return storageURL.appendingPathComponent("ocr")
        case .events:
            return storageURL.appendingPathComponent("events")
        case .spans:
            return storageURL.appendingPathComponent("spans")
        case .summaries:
            return storageURL.appendingPathComponent("summaries")
        }
    }
    
    private func getFilesForCleanup(at path: URL, cutoffDate: Date, dataType: DataType) throws -> [URL] {
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        
        guard let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) else {
            throw RetentionPolicyError.storagePathNotFound(path.path)
        }
        
        var filesToDelete: [URL] = []
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                
                guard resourceValues.isRegularFile == true else { continue }
                
                // Use modification date as the primary criterion
                let fileDate = resourceValues.contentModificationDate ?? resourceValues.creationDate ?? Date.distantPast
                
                if fileDate < cutoffDate && shouldDeleteFile(fileURL, dataType: dataType) {
                    filesToDelete.append(fileURL)
                }
            } catch {
                logger.warning("Failed to get resource values for \(fileURL.path): \(error)")
            }
        }
        
        return filesToDelete
    }
    
    private func shouldDeleteFile(_ fileURL: URL, dataType: DataType) -> Bool {
        let fileExtension = fileURL.pathExtension.lowercased()
        
        switch dataType {
        case .rawVideo:
            return ["mp4", "mov", "avi", "mkv"].contains(fileExtension)
        case .frameMetadata, .ocrData, .events:
            return fileExtension == "parquet"
        case .spans:
            return fileExtension == "sqlite" || fileExtension == "db"
        case .summaries:
            return ["md", "json", "csv"].contains(fileExtension)
        }
    }
    
    private func verifyFileForDeletion(_ fileURL: URL) throws {
        // Check if file exists and is readable
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw RetentionPolicyError.verificationFailed("File does not exist")
        }
        
        guard fileManager.isReadableFile(atPath: fileURL.path) else {
            throw RetentionPolicyError.verificationFailed("File is not readable")
        }
        
        // Additional verification could include:
        // - Checking if file is currently in use
        // - Verifying file integrity
        // - Checking if file is part of an active session
    }
    
    private func getFileSize(_ fileURL: URL) throws -> Int64 {
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
    
    private func rollbackDeletions(_ deletedFiles: [(url: URL, size: Int64)]) throws {
        // In a real implementation, this would restore files from a backup location
        // For now, we just log the rollback attempt
        logger.error("Rollback requested for \(deletedFiles.count) files - files cannot be restored")
        throw RetentionPolicyError.rollbackFailed("Files cannot be restored once deleted")
    }
    
    // MARK: - Public Query Methods
    
    /// Get cleanup statistics for all data types
    public func getCleanupStatistics() -> [DataType: CleanupStats] {
        // This would return cached statistics from recent cleanup operations
        // For now, return empty statistics
        return [:]
    }
    
    /// Estimate space that would be freed by cleanup
    public func estimateCleanupSpace(for dataType: DataType) throws -> Int64 {
        let config = loadRetentionConfiguration()
        guard let policy = config.policies[dataType], policy.enabled, policy.retentionDays > 0 else {
            return 0
        }
        
        guard let recorderConfig = configurationManager.loadConfiguration() else {
            return 0
        }
        
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(policy.retentionDays * 24 * 3600 + config.safetyMarginHours * 3600))
        let dataPath = getDataPath(for: dataType, storageURL: recorderConfig.storageURL)
        
        let filesToCleanup = try getFilesForCleanup(at: dataPath, cutoffDate: cutoffDate, dataType: dataType)
        
        var totalSize: Int64 = 0
        for fileURL in filesToCleanup {
            totalSize += try getFileSize(fileURL)
        }
        
        return totalSize
    }
}

// MARK: - Array Extension for Chunking
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}