import Foundation
import AVFoundation

/// Manages video segment creation and file organization
public class SegmentManager {
    private let configuration: RecorderConfiguration
    private var currentSegment: VideoSegment?
    private var segmentTimer: Timer?
    private let fileManager = FileManager.default
    private let logger = Logger.shared
    
    // Recovery manager integration
    public weak var recoveryManager: RecoveryManager?
    
    public init(configuration: RecorderConfiguration) {
        self.configuration = configuration
        setupStorageDirectories()
    }
    
    /// Sets the recovery manager for crash-safe operation
    public func setRecoveryManager(_ recoveryManager: RecoveryManager) {
        self.recoveryManager = recoveryManager
    }
    
    public func startSegmentation() async throws {
        logger.info("Starting segment management...")
        
        // Clean up any existing partial segments first
        cleanupExistingPartialSegments()
        
        // Create initial segment
        try createNewSegment()
        
        // Start timer for segment rotation
        startSegmentTimer()
        
        logger.info("Segment management started")
    }
    
    public func stopSegmentation() async {
        logger.info("Stopping segment management...")
        
        // Stop timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // Finalize current segment if it exists and is valid
        if let segment = currentSegment {
            // Check if segment file exists and has reasonable size before finalizing
            if fileManager.fileExists(atPath: segment.filePath.path) {
                let fileSize = getFileSize(at: segment.filePath)
                if fileSize > 100_000 { // At least 100KB
                    finalizeSegment(segment)
                } else {
                    // Mark as partial segment for cleanup
                    logger.warning("Current segment appears incomplete (size: \(fileSize) bytes), marking for cleanup")
                    recoveryManager?.addPartialSegmentForCleanup(segment.filePath)
                }
            }
        }
        
        currentSegment = nil
        logger.info("Segment management stopped")
    }
    
    public func getCurrentSegment() -> VideoSegment? {
        return currentSegment
    }
    
    public func finalizeCurrentSegment() throws {
        guard let segment = currentSegment else {
            throw SegmentError.noActiveSegment
        }
        
        finalizeSegment(segment)
        try createNewSegment()
    }
    
    private func setupStorageDirectories() {
        let baseURL = configuration.storageURL
        
        // Create main storage directory
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        
        // Create segments subdirectory
        let segmentsURL = baseURL.appendingPathComponent("segments")
        try? fileManager.createDirectory(at: segmentsURL, withIntermediateDirectories: true)
        
        // Create daily subdirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        let todayURL = segmentsURL.appendingPathComponent(todayString)
        try? fileManager.createDirectory(at: todayURL, withIntermediateDirectories: true)
    }
    
    private func createNewSegment() throws {
        // Finalize previous segment if it exists
        if let previousSegment = currentSegment {
            if fileManager.fileExists(atPath: previousSegment.filePath.path) {
                let fileSize = getFileSize(at: previousSegment.filePath)
                if fileSize > 100_000 { // At least 100KB
                    finalizeSegment(previousSegment)
                } else {
                    // Mark as partial segment for cleanup
                    logger.warning("Previous segment appears incomplete (size: \(fileSize) bytes), marking for cleanup")
                    recoveryManager?.addPartialSegmentForCleanup(previousSegment.filePath)
                }
            }
        }
        
        let segmentID = UUID()
        let timestamp = Date()
        
        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayString = dateFormatter.string(from: timestamp)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let timeString = timeFormatter.string(from: timestamp)
        
        let filename = "\(timeString)_\(segmentID.uuidString.prefix(8)).mp4"
        let segmentURL = configuration.storageURL
            .appendingPathComponent("segments")
            .appendingPathComponent(dayString)
            .appendingPathComponent(filename)
        
        let segment = VideoSegment(
            id: segmentID,
            startTime: timestamp,
            filePath: segmentURL,
            displayIDs: configuration.selectedDisplays.isEmpty ? [] : configuration.selectedDisplays
        )
        
        currentSegment = segment
        
        logger.info("Created new segment: \(filename)")
    }
    
    /// Cleans up existing partial segments on startup
    private func cleanupExistingPartialSegments() {
        let segmentsURL = configuration.storageURL.appendingPathComponent("segments")
        
        guard fileManager.fileExists(atPath: segmentsURL.path) else {
            return
        }
        
        do {
            // Get all subdirectories (date folders)
            let dateFolders = try fileManager.contentsOfDirectory(at: segmentsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            
            for dateFolder in dateFolders {
                guard dateFolder.hasDirectoryPath else { continue }
                
                let videoFiles = try fileManager.contentsOfDirectory(at: dateFolder, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles])
                
                for videoFile in videoFiles {
                    guard videoFile.pathExtension.lowercased() == "mp4" else { continue }
                    
                    let resourceValues = try videoFile.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    let fileSize = resourceValues.fileSize ?? 0
                    let creationDate = resourceValues.creationDate ?? Date.distantPast
                    
                    // Consider files smaller than 100KB or created in the last 5 minutes as potentially partial
                    let fiveMinutesAgo = Date().addingTimeInterval(-300)
                    if fileSize < 100_000 || creationDate > fiveMinutesAgo {
                        recoveryManager?.addPartialSegmentForCleanup(videoFile)
                        logger.info("Marked potential partial segment for cleanup: \(videoFile.lastPathComponent) (size: \(fileSize) bytes)")
                    }
                }
            }
        } catch {
            logger.error("Failed to scan for existing partial segments: \(error)")
        }
    }
    
    private func startSegmentTimer() {
        segmentTimer = Timer.scheduledTimer(withTimeInterval: configuration.segmentDuration, repeats: true) { [weak self] _ in
            Task {
                try? self?.finalizeCurrentSegment()
            }
        }
    }
    
    private func finalizeSegment(_ segment: VideoSegment) {
        let endTime = Date()
        let fileSize = getFileSize(at: segment.filePath)
        
        let finalizedSegment = VideoSegment(
            id: segment.id,
            startTime: segment.startTime,
            endTime: endTime,
            filePath: segment.filePath,
            displayIDs: segment.displayIDs,
            fileSize: fileSize
        )
        
        // Only notify indexer if segment is valid
        if fileSize > 100_000 { // At least 100KB
            notifyIndexerOfNewSegment(finalizedSegment)
            logger.info("Finalized segment: \(segment.filePath.lastPathComponent) (size: \(fileSize) bytes)")
        } else {
            logger.warning("Segment too small to finalize: \(segment.filePath.lastPathComponent) (size: \(fileSize) bytes)")
            recoveryManager?.addPartialSegmentForCleanup(segment.filePath)
        }
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func notifyIndexerOfNewSegment(_ segment: VideoSegment) {
        // Create a notification file for the indexer service
        let notificationURL = configuration.storageURL
            .appendingPathComponent("queue")
            .appendingPathComponent("new_segments")
        
        try? fileManager.createDirectory(at: notificationURL, withIntermediateDirectories: true)
        
        let notificationFile = notificationURL.appendingPathComponent("\(segment.id.uuidString).json")
        
        let segmentInfo: [String: Any] = [
            "id": segment.id.uuidString,
            "start_time": segment.startTime.timeIntervalSince1970,
            "end_time": segment.endTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "file_path": segment.filePath.path,
            "display_ids": segment.displayIDs,
            "file_size": segment.fileSize
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: segmentInfo, options: .prettyPrinted)
            try jsonData.write(to: notificationFile)
        } catch {
            print("Failed to create segment notification: \(error)")
        }
    }
}

// MARK: - Data Models
public struct VideoSegment {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let filePath: URL
    public let displayIDs: [CGDirectDisplayID]
    public let fileSize: Int64
    
    public init(id: UUID, startTime: Date, endTime: Date? = nil, filePath: URL, displayIDs: [CGDirectDisplayID], fileSize: Int64 = 0) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.filePath = filePath
        self.displayIDs = displayIDs
        self.fileSize = fileSize
    }
}

// MARK: - Error Types
public enum SegmentError: Error {
    case noActiveSegment
    case segmentCreationFailed
    case storageNotAvailable
    
    public var localizedDescription: String {
        switch self {
        case .noActiveSegment:
            return "No active segment to finalize"
        case .segmentCreationFailed:
            return "Failed to create new segment"
        case .storageNotAvailable:
            return "Storage location not available"
        }
    }
}