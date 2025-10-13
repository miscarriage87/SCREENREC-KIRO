import Foundation
import CoreGraphics

/// Swift interface for OCR data storage using Parquet format
/// This bridges to the Rust-based OCR Parquet writer for efficient storage
public class OCRDataStorage {
    
    private let storageDirectory: URL
    private let rustBridgeQueue: DispatchQueue
    
    /// Configuration for OCR data storage
    public struct StorageConfiguration {
        public let batchSize: Int
        public let compressionEnabled: Bool
        public let dictionaryEncodingEnabled: Bool
        public let retentionDays: Int
        
        public init(batchSize: Int = 5000,
                   compressionEnabled: Bool = true,
                   dictionaryEncodingEnabled: Bool = true,
                   retentionDays: Int = 90) {
            self.batchSize = batchSize
            self.compressionEnabled = compressionEnabled
            self.dictionaryEncodingEnabled = dictionaryEncodingEnabled
            self.retentionDays = retentionDays
        }
    }
    
    /// Statistics about stored OCR data
    public struct StorageStatistics {
        public let totalRecords: UInt64
        public let averageConfidence: Float
        public let languageDistribution: [String: UInt64]
        public let processorDistribution: [String: UInt64]
        public let totalSizeBytes: UInt64
        public let oldestRecord: Date?
        public let newestRecord: Date?
        
        public init(totalRecords: UInt64 = 0,
                   averageConfidence: Float = 0.0,
                   languageDistribution: [String: UInt64] = [:],
                   processorDistribution: [String: UInt64] = [:],
                   totalSizeBytes: UInt64 = 0,
                   oldestRecord: Date? = nil,
                   newestRecord: Date? = nil) {
            self.totalRecords = totalRecords
            self.averageConfidence = averageConfidence
            self.languageDistribution = languageDistribution
            self.processorDistribution = processorDistribution
            self.totalSizeBytes = totalSizeBytes
            self.oldestRecord = oldestRecord
            self.newestRecord = newestRecord
        }
    }
    
    private let configuration: StorageConfiguration
    
    public init(storageDirectory: URL, configuration: StorageConfiguration = StorageConfiguration()) throws {
        self.storageDirectory = storageDirectory
        self.configuration = configuration
        self.rustBridgeQueue = DispatchQueue(label: "com.alwaysonai.ocr-storage", qos: .utility)
        
        // Create storage directory if it doesn't exist
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        // Initialize Rust-based storage backend
        try initializeRustStorage()
    }
    
    /// Store OCR results for a frame
    public func storeOCRResults(_ results: [OCRResult], for frameId: String) async throws {
        guard !results.isEmpty else { return }
        
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    // Convert Swift OCRResult to storage format
                    let storageResults = results.map { result in
                        StorageOCRResult(
                            frameId: frameId,
                            roi: StorageBoundingBox(
                                x: Float(result.boundingBox.origin.x),
                                y: Float(result.boundingBox.origin.y),
                                width: Float(result.boundingBox.size.width),
                                height: Float(result.boundingBox.size.height)
                            ),
                            text: result.text,
                            language: result.language,
                            confidence: result.confidence,
                            processedAt: Date(),
                            processor: self.getProcessorName(from: result)
                        )
                    }
                    
                    // Call Rust storage function
                    try self.writeOCRResultsToRust(storageResults)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Store a batch of OCR results efficiently
    public func storeOCRBatch(_ batch: OCRBatch) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    // Convert batch to storage format
                    let storageResults = batch.results.compactMap { (frameId, results) in
                        results.map { result in
                            StorageOCRResult(
                                frameId: frameId,
                                roi: StorageBoundingBox(
                                    x: Float(result.boundingBox.origin.x),
                                    y: Float(result.boundingBox.origin.y),
                                    width: Float(result.boundingBox.size.width),
                                    height: Float(result.boundingBox.size.height)
                                ),
                                text: result.text,
                                language: result.language,
                                confidence: result.confidence,
                                processedAt: Date(),
                                processor: self.getProcessorName(from: result)
                            )
                        }
                    }.flatMap { $0 }
                    
                    try self.writeOCRResultsToRust(storageResults)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Query OCR results by frame ID
    public func queryOCRResults(for frameId: String) async throws -> [OCRResult] {
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    let storageResults = try self.queryOCRResultsByFrameId(frameId)
                    let swiftResults = storageResults.map { self.convertToSwiftOCRResult($0) }
                    continuation.resume(returning: swiftResults)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Search OCR results by text content
    public func searchOCRResults(containing text: String) async throws -> [OCRResult] {
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    let storageResults = try self.queryOCRResultsByText(text)
                    let swiftResults = storageResults.map { self.convertToSwiftOCRResult($0) }
                    continuation.resume(returning: swiftResults)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Query OCR results by confidence threshold
    public func queryOCRResults(withMinimumConfidence confidence: Float) async throws -> [OCRResult] {
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    let storageResults = try self.queryOCRResultsByConfidence(confidence)
                    let swiftResults = storageResults.map { self.convertToSwiftOCRResult($0) }
                    continuation.resume(returning: swiftResults)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Query OCR results by language
    public func queryOCRResults(byLanguage language: String) async throws -> [OCRResult] {
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    let storageResults = try self.queryOCRResultsByLanguage(language)
                    let swiftResults = storageResults.map { self.convertToSwiftOCRResult($0) }
                    continuation.resume(returning: swiftResults)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get storage statistics
    public func getStorageStatistics() async throws -> StorageStatistics {
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    let rustStats = try self.getRustStorageStatistics()
                    let swiftStats = StorageStatistics(
                        totalRecords: rustStats.totalRecords,
                        averageConfidence: rustStats.averageConfidence,
                        languageDistribution: rustStats.languageDistribution,
                        processorDistribution: rustStats.processorDistribution,
                        totalSizeBytes: rustStats.totalSizeBytes
                    )
                    continuation.resume(returning: swiftStats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Flush any pending writes to disk
    public func flush() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    try self.flushRustStorage()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Clean up old OCR data based on retention policy
    public func cleanupOldData() async throws {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(configuration.retentionDays * 24 * 60 * 60))
        
        return try await withCheckedThrowingContinuation { continuation in
            rustBridgeQueue.async {
                do {
                    try self.cleanupRustDataBefore(cutoffDate)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getProcessorName(from result: OCRResult) -> String {
        // Determine processor based on context or metadata
        // This is a simplified implementation
        return "vision" // Default to Vision framework
    }
    
    private func convertToSwiftOCRResult(_ storageResult: StorageOCRResult) -> OCRResult {
        return OCRResult(
            text: storageResult.text,
            boundingBox: CGRect(
                x: CGFloat(storageResult.roi.x),
                y: CGFloat(storageResult.roi.y),
                width: CGFloat(storageResult.roi.width),
                height: CGFloat(storageResult.roi.height)
            ),
            confidence: storageResult.confidence,
            language: storageResult.language
        )
    }
    
    // MARK: - Rust Bridge Functions (Mock Implementation)
    // In a real implementation, these would be actual FFI calls to Rust
    
    private func initializeRustStorage() throws {
        // Mock implementation - would initialize Rust OCR Parquet writer
        print("Initializing Rust OCR storage at: \(storageDirectory.path)")
    }
    
    private func writeOCRResultsToRust(_ results: [StorageOCRResult]) throws {
        // Mock implementation - would call Rust function to write OCR results
        print("Writing \(results.count) OCR results to Rust storage")
    }
    
    private func queryOCRResultsByFrameId(_ frameId: String) throws -> [StorageOCRResult] {
        // Mock implementation - would call Rust query function
        print("Querying OCR results for frame: \(frameId)")
        return []
    }
    
    private func queryOCRResultsByText(_ text: String) throws -> [StorageOCRResult] {
        // Mock implementation - would call Rust text search function
        print("Searching OCR results for text: \(text)")
        return []
    }
    
    private func queryOCRResultsByConfidence(_ confidence: Float) throws -> [StorageOCRResult] {
        // Mock implementation - would call Rust confidence query function
        print("Querying OCR results with confidence >= \(confidence)")
        return []
    }
    
    private func queryOCRResultsByLanguage(_ language: String) throws -> [StorageOCRResult] {
        // Mock implementation - would call Rust language query function
        print("Querying OCR results for language: \(language)")
        return []
    }
    
    private func getRustStorageStatistics() throws -> RustStorageStatistics {
        // Mock implementation - would call Rust statistics function
        print("Getting storage statistics from Rust")
        return RustStorageStatistics(
            totalRecords: 0,
            averageConfidence: 0.0,
            languageDistribution: [:],
            processorDistribution: [:],
            totalSizeBytes: 0
        )
    }
    
    private func flushRustStorage() throws {
        // Mock implementation - would call Rust flush function
        print("Flushing Rust storage")
    }
    
    private func cleanupRustDataBefore(_ date: Date) throws {
        // Mock implementation - would call Rust cleanup function
        print("Cleaning up Rust data before: \(date)")
    }
}

// MARK: - Supporting Data Structures

/// OCR batch for efficient processing
public struct OCRBatch {
    public let results: [String: [OCRResult]] // frameId -> results
    public let batchId: String
    public let createdAt: Date
    
    public init(results: [String: [OCRResult]]) {
        self.results = results
        self.batchId = UUID().uuidString
        self.createdAt = Date()
    }
}

/// Internal storage representation of OCR result
private struct StorageOCRResult {
    let frameId: String
    let roi: StorageBoundingBox
    let text: String
    let language: String
    let confidence: Float
    let processedAt: Date
    let processor: String
}

/// Internal storage representation of bounding box
private struct StorageBoundingBox {
    let x: Float
    let y: Float
    let width: Float
    let height: Float
}

/// Internal representation of Rust storage statistics
private struct RustStorageStatistics {
    let totalRecords: UInt64
    let averageConfidence: Float
    let languageDistribution: [String: UInt64]
    let processorDistribution: [String: UInt64]
    let totalSizeBytes: UInt64
}

// MARK: - Error Types

public enum OCRStorageError: Error, LocalizedError {
    case initializationFailed(String)
    case writeFailed(String)
    case queryFailed(String)
    case corruptedData(String)
    case insufficientSpace
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "OCR storage initialization failed: \(message)"
        case .writeFailed(let message):
            return "OCR data write failed: \(message)"
        case .queryFailed(let message):
            return "OCR data query failed: \(message)"
        case .corruptedData(let message):
            return "OCR data corrupted: \(message)"
        case .insufficientSpace:
            return "Insufficient disk space for OCR data storage"
        }
    }
}