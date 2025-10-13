import Foundation

/// Manages the complete data lifecycle including retention policies and cleanup
public class DataLifecycleManager {
    private let retentionPolicyManager: RetentionPolicyManager
    private let configurationManager: ConfigurationManager
    private let logger = Logger.shared
    
    private var isRunning = false
    private let lifecycleQueue = DispatchQueue(label: "data.lifecycle", qos: .utility)
    
    public init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
        self.retentionPolicyManager = RetentionPolicyManager(configurationManager: configurationManager)
    }
    
    /// Start the data lifecycle management system
    public func start() {
        guard !isRunning else {
            logger.warning("Data lifecycle manager already running")
            return
        }
        
        isRunning = true
        
        guard let config = configurationManager.loadConfiguration(),
              config.enableRetentionPolicies else {
            logger.info("Retention policies disabled in configuration")
            return
        }
        
        logger.info("Starting data lifecycle manager")
        
        // Start background cleanup
        retentionPolicyManager.startBackgroundCleanup()
        
        // Perform initial cleanup check
        lifecycleQueue.async { [weak self] in
            self?.performInitialCleanupCheck()
        }
    }
    
    /// Stop the data lifecycle management system
    public func stop() {
        guard isRunning else { return }
        
        logger.info("Stopping data lifecycle manager")
        
        isRunning = false
        retentionPolicyManager.stopBackgroundCleanup()
    }
    
    /// Perform manual cleanup for a specific data type
    public func performManualCleanup(for dataType: DataType, completion: @escaping (Result<CleanupStats, Error>) -> Void) {
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let stats = try self.retentionPolicyManager.performCleanup(for: dataType)
                DispatchQueue.main.async {
                    completion(.success(stats))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get estimated space that would be freed by cleanup
    public func getCleanupEstimate(for dataType: DataType, completion: @escaping (Result<Int64, Error>) -> Void) {
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let estimate = try self.retentionPolicyManager.estimateCleanupSpace(for: dataType)
                DispatchQueue.main.async {
                    completion(.success(estimate))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get cleanup statistics for all data types
    public func getCleanupStatistics() -> [DataType: CleanupStats] {
        return retentionPolicyManager.getCleanupStatistics()
    }
    
    /// Update retention configuration
    public func updateRetentionConfiguration(_ config: RetentionConfiguration) throws {
        try retentionPolicyManager.saveRetentionConfiguration(config)
        
        // Restart background cleanup with new configuration
        if isRunning {
            retentionPolicyManager.stopBackgroundCleanup()
            retentionPolicyManager.startBackgroundCleanup()
        }
        
        logger.info("Retention configuration updated")
    }
    
    /// Get current retention configuration
    public func getRetentionConfiguration() -> RetentionConfiguration {
        return retentionPolicyManager.loadRetentionConfiguration()
    }
    
    // MARK: - Storage Health Monitoring
    
    /// Check storage health and recommend actions
    public func checkStorageHealth(completion: @escaping (StorageHealthReport) -> Void) {
        lifecycleQueue.async { [weak self] in
            guard let self = self else { return }
            
            let report = self.generateStorageHealthReport()
            DispatchQueue.main.async {
                completion(report)
            }
        }
    }
    
    private func generateStorageHealthReport() -> StorageHealthReport {
        guard let config = configurationManager.loadConfiguration() else {
            return StorageHealthReport(
                totalSize: 0,
                availableSpace: 0,
                dataTypeBreakdown: [:],
                recommendations: ["Configuration not available"],
                healthStatus: .error
            )
        }
        
        let storageURL = config.storageURL
        var dataTypeBreakdown: [DataType: Int64] = [:]
        var recommendations: [String] = []
        
        // Calculate storage usage by data type
        for dataType in DataType.allCases {
            do {
                let size = try calculateDataTypeSize(dataType, storageURL: storageURL)
                dataTypeBreakdown[dataType] = size
            } catch {
                logger.warning("Failed to calculate size for \(dataType.rawValue): \(error)")
                dataTypeBreakdown[dataType] = 0
            }
        }
        
        let totalSize = dataTypeBreakdown.values.reduce(0, +)
        let availableSpace = getAvailableSpace(at: storageURL)
        
        // Generate recommendations
        if availableSpace < 1_000_000_000 { // Less than 1GB
            recommendations.append("Low disk space available. Consider reducing retention periods.")
        }
        
        let retentionConfig = retentionPolicyManager.loadRetentionConfiguration()
        for (dataType, policy) in retentionConfig.policies {
            if policy.retentionDays > 0 {
                do {
                    let reclaimableSpace = try retentionPolicyManager.estimateCleanupSpace(for: dataType)
                    if reclaimableSpace > 100_000_000 { // More than 100MB
                        recommendations.append("Can reclaim \(formatBytes(reclaimableSpace)) by cleaning up \(dataType.rawValue)")
                    }
                } catch {
                    logger.warning("Failed to estimate cleanup space for \(dataType.rawValue): \(error)")
                }
            }
        }
        
        let healthStatus: StorageHealthStatus
        if availableSpace < 500_000_000 { // Less than 500MB
            healthStatus = .critical
        } else if availableSpace < 2_000_000_000 { // Less than 2GB
            healthStatus = .warning
        } else {
            healthStatus = .healthy
        }
        
        return StorageHealthReport(
            totalSize: totalSize,
            availableSpace: availableSpace,
            dataTypeBreakdown: dataTypeBreakdown,
            recommendations: recommendations,
            healthStatus: healthStatus
        )
    }
    
    private func calculateDataTypeSize(_ dataType: DataType, storageURL: URL) throws -> Int64 {
        let dataPath = getDataPath(for: dataType, storageURL: storageURL)
        
        guard FileManager.default.fileExists(atPath: dataPath.path) else {
            return 0
        }
        
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: dataPath,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                // Continue with other files if one fails
                continue
            }
        }
        
        return totalSize
    }
    
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
    
    private func getAvailableSpace(at url: URL) -> Int64 {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(resourceValues.volumeAvailableCapacity ?? 0)
        } catch {
            logger.warning("Failed to get available space: \(error)")
            return 0
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func performInitialCleanupCheck() {
        logger.info("Performing initial cleanup check")
        
        let retentionConfig = retentionPolicyManager.loadRetentionConfiguration()
        
        for (dataType, policy) in retentionConfig.policies {
            guard policy.enabled && policy.retentionDays > 0 else { continue }
            
            do {
                let estimate = try retentionPolicyManager.estimateCleanupSpace(for: dataType)
                if estimate > 0 {
                    logger.info("Initial cleanup estimate for \(dataType.rawValue): \(formatBytes(estimate))")
                }
            } catch {
                logger.warning("Failed to estimate cleanup for \(dataType.rawValue): \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

public enum StorageHealthStatus {
    case healthy
    case warning
    case critical
    case error
}

public struct StorageHealthReport {
    public let totalSize: Int64
    public let availableSpace: Int64
    public let dataTypeBreakdown: [DataType: Int64]
    public let recommendations: [String]
    public let healthStatus: StorageHealthStatus
    
    public init(totalSize: Int64, availableSpace: Int64, dataTypeBreakdown: [DataType: Int64], recommendations: [String], healthStatus: StorageHealthStatus) {
        self.totalSize = totalSize
        self.availableSpace = availableSpace
        self.dataTypeBreakdown = dataTypeBreakdown
        self.recommendations = recommendations
        self.healthStatus = healthStatus
    }
}