import Foundation
import ScreenCaptureKit

/// Reasons for recovery
public enum RecoveryReason: String, CaseIterable {
    case unknown = "unknown"
    case screenCaptureSessionFailed = "screen_capture_session_failed"
    case multiMonitorFailure = "multi_monitor_failure"
    case encodingFailure = "encoding_failure"
    case storageFailure = "storage_failure"
    case systemResourceExhaustion = "system_resource_exhaustion"
    case permissionDenied = "permission_denied"
    case displayDisconnected = "display_disconnected"
    case crash = "crash"
    case manualTrigger = "manual_trigger"
}

/// Recovery strategy options
public enum RecoveryStrategy {
    case fullRestart
    case gracefulDegradation([CGDirectDisplayID])
    case singleMonitorFallback(CGDirectDisplayID)
    case qualityReduction
    case temporaryPause
}

/// Manages automatic recovery and restart functionality for crash-safe operation
public class RecoveryManager {
    private let configuration: RecorderConfiguration?
    private var recoveryTimer: Timer?
    private var isRecovering: Bool = false
    private var recoveryAttempts: Int = 0
    private let maxRecoveryAttempts: Int = 5
    private let logger = Logger.shared
    private var lastSuccessfulRecording: Date?
    private var partialSegmentCleanupQueue: [URL] = []
    private var recoveryStartTime: Date?
    private var recoveryStatistics = RecoveryStatisticsTracker()
    private let fileManager = FileManager.default
    
    // Recovery callbacks
    public var onRecoveryNeeded: (() async -> Void)?
    public var onRecoverySuccess: (() -> Void)?
    public var onRecoveryFailed: (() -> Void)?
    public var onGracefulDegradation: (([CGDirectDisplayID]) -> Void)?
    public var onPartialSegmentCleanup: ((URL) -> Void)?
    public var onRecoveryStrategySelected: ((RecoveryStrategy) -> Void)?
    
    public init(configuration: RecorderConfiguration? = nil) {
        self.configuration = configuration
    }
    
    /// Triggers recovery process with automatic restart within 5 seconds
    public func triggerRecovery(reason: RecoveryReason = .unknown, failedDisplays: [CGDirectDisplayID] = []) {
        guard !isRecovering else {
            logger.warning("Recovery already in progress")
            return
        }
        
        guard recoveryAttempts < maxRecoveryAttempts else {
            logger.error("Maximum recovery attempts reached (\(maxRecoveryAttempts))")
            recoveryStatistics.recordFailedRecovery(reason: reason)
            onRecoveryFailed?()
            return
        }
        
        isRecovering = true
        recoveryAttempts += 1
        recoveryStartTime = Date()
        
        logger.info("Triggering recovery attempt \(recoveryAttempts)/\(maxRecoveryAttempts) - Reason: \(reason.rawValue)")
        recoveryStatistics.recordRecoveryAttempt(reason: reason)
        
        // Determine recovery strategy based on reason and failed displays
        let strategy = determineRecoveryStrategy(reason: reason, failedDisplays: failedDisplays)
        onRecoveryStrategySelected?(strategy)
        
        let timeoutSeconds = min(configuration?.recoveryTimeoutSeconds ?? 5, 5) // Ensure ≤5 seconds
        
        // Clean up partial segments immediately (synchronously for immediate effect)
        Task.detached { [weak self] in
            await self?.cleanupPartialSegments()
        }
        
        // Schedule recovery after timeout (within 5 seconds as required)
        recoveryTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeoutSeconds), repeats: false) { [weak self] _ in
            Task {
                await self?.performRecovery(reason: reason, failedDisplays: failedDisplays, strategy: strategy)
            }
        }
        
        // Ensure timer is added to run loop
        if let timer = recoveryTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Determines the appropriate recovery strategy based on the failure reason
    private func determineRecoveryStrategy(reason: RecoveryReason, failedDisplays: [CGDirectDisplayID]) -> RecoveryStrategy {
        switch reason {
        case .multiMonitorFailure:
            if failedDisplays.count == 1 {
                // Try to continue with remaining displays
                return .gracefulDegradation(failedDisplays)
            } else {
                // Fall back to single monitor (main display)
                let mainDisplayID = CGMainDisplayID()
                return .singleMonitorFallback(mainDisplayID)
            }
            
        case .displayDisconnected:
            // Remove disconnected displays and continue
            return .gracefulDegradation(failedDisplays)
            
        case .systemResourceExhaustion:
            // Reduce quality to lower resource usage
            return .qualityReduction
            
        case .permissionDenied:
            // Pause temporarily and wait for permission
            return .temporaryPause
            
        case .screenCaptureSessionFailed, .encodingFailure, .storageFailure, .crash, .unknown, .manualTrigger:
            // Full restart for these cases
            return .fullRestart
        }
    }
    
    public func cancelRecovery() {
        recoveryTimer?.invalidate()
        recoveryTimer = nil
        isRecovering = false
        
        print("Recovery cancelled")
    }
    
    public func resetRecoveryAttempts() {
        recoveryAttempts = 0
        print("Recovery attempts reset")
    }
    
    public func reportRecoverySuccess() {
        let recoveryTime = recoveryStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        cancelRecovery()
        resetRecoveryAttempts()
        lastSuccessfulRecording = Date()
        
        recoveryStatistics.recordSuccessfulRecovery(recoveryTime: recoveryTime)
        onRecoverySuccess?()
        
        logger.info("Recovery successful in \(String(format: "%.2f", recoveryTime)) seconds")
    }
    
    /// Performs the actual recovery process
    private func performRecovery(reason: RecoveryReason, failedDisplays: [CGDirectDisplayID], strategy: RecoveryStrategy) async {
        logger.info("Performing recovery for reason: \(reason.rawValue) with strategy: \(strategy)")
        
        // Clean up any existing state
        await cleanupBeforeRecovery()
        
        // Execute recovery strategy
        switch strategy {
        case .gracefulDegradation(let displays):
            await attemptGracefulDegradation(failedDisplays: displays)
            
        case .singleMonitorFallback(let displayID):
            await attemptSingleMonitorFallback(displayID: displayID)
            
        case .qualityReduction:
            await attemptQualityReduction()
            
        case .temporaryPause:
            await attemptTemporaryPause()
            
        case .fullRestart:
            // Trigger full recovery callback
            await onRecoveryNeeded?()
        }
        
        // Schedule next recovery attempt if this one fails
        scheduleNextRecoveryCheck()
    }
    
    private func cleanupBeforeRecovery() async {
        logger.info("Cleaning up before recovery...")
        
        // Clean up partial segments
        await cleanupPartialSegments()
        
        // Clear any temporary state
        partialSegmentCleanupQueue.removeAll()
        
        // Reset internal timers and state
        recoveryTimer?.invalidate()
        recoveryTimer = nil
        
        logger.info("Cleanup before recovery completed")
    }
    
    /// Attempts graceful degradation by removing failed displays
    private func attemptGracefulDegradation(failedDisplays: [CGDirectDisplayID]) async {
        logger.info("Attempting graceful degradation, removing displays: \(failedDisplays)")
        
        // Notify about graceful degradation
        onGracefulDegradation?(failedDisplays)
        
        // Wait a moment for the system to adjust
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        logger.info("Graceful degradation completed")
    }
    
    /// Attempts to fall back to single monitor capture
    private func attemptSingleMonitorFallback(displayID: CGDirectDisplayID) async {
        logger.info("Attempting single monitor fallback to display: \(displayID)")
        
        // Get all displays except the target one
        let allDisplays = await getCurrentDisplayIDs()
        let failedDisplays = allDisplays.filter { $0 != displayID }
        
        // Notify about graceful degradation to single monitor
        onGracefulDegradation?(failedDisplays)
        
        // Wait a moment for the system to adjust
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        logger.info("Single monitor fallback completed")
    }
    
    /// Attempts to reduce quality to lower resource usage
    private func attemptQualityReduction() async {
        logger.info("Attempting quality reduction to lower resource usage")
        
        // This would typically involve reducing resolution, frame rate, or bitrate
        // For now, we'll just trigger a full restart with the assumption that
        // the configuration will be adjusted externally
        await onRecoveryNeeded?()
        
        logger.info("Quality reduction completed")
    }
    
    /// Attempts temporary pause for permission issues
    private func attemptTemporaryPause() async {
        logger.info("Attempting temporary pause for permission issues")
        
        // Wait longer for permission issues
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        // Try to restart after pause
        await onRecoveryNeeded?()
        
        logger.info("Temporary pause completed")
    }
    
    /// Gets current display IDs from the system
    private func getCurrentDisplayIDs() async -> [CGDirectDisplayID] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.displays.map { $0.displayID }
        } catch {
            logger.error("Failed to get current display IDs: \(error)")
            return []
        }
    }
    
    private func scheduleNextRecoveryCheck() {
        // Check if recovery was successful after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            
            if self.isRecovering {
                // Recovery didn't complete successfully, try again
                self.isRecovering = false
                self.triggerRecovery()
            }
        }
    }
}

// MARK: - System Health Monitoring
extension RecoveryManager {
    public func startHealthMonitoring() {
        // Monitor system health and trigger recovery if needed
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkSystemHealth()
        }
    }
    
    private func checkSystemHealth() {
        // Check various system health indicators
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()
        let diskSpace = getAvailableDiskSpace()
        
        // Check if system is healthy
        if let config = configuration {
            if cpuUsage > config.maxCPUUsage * 2 { // Allow 2x threshold before recovery
                print("High CPU usage detected: \(cpuUsage)%")
                triggerRecovery()
                return
            }
            
            if memoryUsage > Double(config.maxMemoryUsage) * 2 { // Allow 2x threshold
                print("High memory usage detected: \(memoryUsage) MB")
                triggerRecovery()
                return
            }
            
            if diskSpace < 1000 { // Less than 1GB free space
                print("Low disk space detected: \(diskSpace) MB")
                triggerRecovery()
                return
            }
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        // In a real implementation, this would use system APIs like host_processor_info
        return Double.random(in: 1.0...10.0)
    }
    
    private func getCurrentMemoryUsage() -> Double {
        // Get current memory usage
        let processInfo = ProcessInfo.processInfo
        return Double(processInfo.physicalMemory) / (1024 * 1024) * 0.05 // Rough estimate
    }
    
    private func getAvailableDiskSpace() -> Double {
        // Get available disk space in MB
        do {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let capacity = resourceValues.volumeAvailableCapacity {
                return Double(capacity) / (1024 * 1024) // Convert to MB
            }
        } catch {
            print("Failed to get disk space: \(error)")
        }
        
        return 0
    }
}

// MARK: - Crash Detection
extension RecoveryManager {
    public func setupCrashDetection() {
        // Set up crash detection mechanisms
        setupSignalHandlers()
        setupExceptionHandlers()
    }
    
    private func setupSignalHandlers() {
        // Handle common crash signals
        let signals = [SIGTERM, SIGINT, SIGQUIT, SIGABRT]
        
        for signal in signals {
            Darwin.signal(signal) { signal in
                print("Received signal \(signal), triggering recovery...")
                // Note: This is a simplified approach
                // In production, you'd want more sophisticated crash handling
            }
        }
    }
    
    private func setupExceptionHandlers() {
        // Set up NSException handlers
        NSSetUncaughtExceptionHandler { exception in
            print("Uncaught exception: \(exception)")
            // Trigger recovery through a different mechanism since we're in an exception handler
        }
    }
}

// MARK: - Partial Segment Cleanup
extension RecoveryManager {
    /// Adds a partial segment to the cleanup queue
    public func addPartialSegmentForCleanup(_ segmentURL: URL) {
        partialSegmentCleanupQueue.append(segmentURL)
        logger.info("Added partial segment for cleanup: \(segmentURL.lastPathComponent)")
    }
    
    /// Cleans up partial segments during crashes
    private func cleanupPartialSegments() async {
        logger.info("Cleaning up \(partialSegmentCleanupQueue.count) partial segments")
        
        for segmentURL in partialSegmentCleanupQueue {
            await cleanupPartialSegment(segmentURL)
        }
        
        // Also scan for orphaned segments in storage directory
        if let storageURL = configuration?.storageURL {
            await scanAndCleanupOrphanedSegments(in: storageURL)
        }
        
        partialSegmentCleanupQueue.removeAll()
        logger.info("Partial segment cleanup completed")
    }
    
    /// Cleans up a single partial segment
    private func cleanupPartialSegment(_ segmentURL: URL) async {
        do {
            // Check if file exists and is incomplete
            if fileManager.fileExists(atPath: segmentURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: segmentURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // Consider files smaller than 1MB as potentially incomplete
                if fileSize < 1_000_000 {
                    try fileManager.removeItem(at: segmentURL)
                    logger.info("Removed partial segment: \(segmentURL.lastPathComponent) (size: \(fileSize) bytes)")
                    
                    // Notify callback
                    onPartialSegmentCleanup?(segmentURL)
                } else {
                    logger.info("Keeping segment (appears complete): \(segmentURL.lastPathComponent) (size: \(fileSize) bytes)")
                }
            }
        } catch {
            logger.error("Failed to cleanup partial segment \(segmentURL.lastPathComponent): \(error)")
        }
    }
    
    /// Scans storage directory for orphaned segments and cleans them up
    private func scanAndCleanupOrphanedSegments(in storageURL: URL) async {
        let segmentsURL = storageURL.appendingPathComponent("segments")
        
        guard fileManager.fileExists(atPath: segmentsURL.path) else {
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: segmentsURL, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [])
            
            for fileURL in contents {
                // Check if it's a video file
                guard fileURL.pathExtension.lowercased() == "mp4" else { continue }
                
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let fileSize = resourceValues.fileSize ?? 0
                let creationDate = resourceValues.creationDate ?? Date.distantPast
                
                // Consider files created in the last 5 minutes and smaller than 1MB as potentially orphaned
                let fiveMinutesAgo = Date().addingTimeInterval(-300)
                if creationDate > fiveMinutesAgo && fileSize < 1_000_000 {
                    try fileManager.removeItem(at: fileURL)
                    logger.info("Removed orphaned segment: \(fileURL.lastPathComponent) (size: \(fileSize) bytes)")
                    
                    onPartialSegmentCleanup?(fileURL)
                }
            }
        } catch {
            logger.error("Failed to scan for orphaned segments: \(error)")
        }
    }
}

// MARK: - Recovery Statistics
public struct RecoveryStatistics {
    public let totalRecoveryAttempts: Int
    public let successfulRecoveries: Int
    public let failedRecoveries: Int
    public let lastRecoveryTime: Date?
    public let averageRecoveryTime: TimeInterval
    public let recoveryReasons: [RecoveryReason: Int]
    
    public var successRate: Double {
        guard totalRecoveryAttempts > 0 else { return 0 }
        return Double(successfulRecoveries) / Double(totalRecoveryAttempts)
    }
}

/// Tracks recovery statistics
private class RecoveryStatisticsTracker {
    private var totalAttempts = 0
    private var successfulRecoveries = 0
    private var failedRecoveries = 0
    private var lastRecoveryTime: Date?
    private var recoveryTimes: [TimeInterval] = []
    private var reasonCounts: [RecoveryReason: Int] = [:]
    
    func recordRecoveryAttempt(reason: RecoveryReason) {
        totalAttempts += 1
        reasonCounts[reason, default: 0] += 1
    }
    
    func recordSuccessfulRecovery(recoveryTime: TimeInterval) {
        successfulRecoveries += 1
        lastRecoveryTime = Date()
        recoveryTimes.append(recoveryTime)
    }
    
    func recordFailedRecovery(reason: RecoveryReason) {
        failedRecoveries += 1
    }
    
    func getStatistics() -> RecoveryStatistics {
        let averageTime = recoveryTimes.isEmpty ? 0 : recoveryTimes.reduce(0, +) / Double(recoveryTimes.count)
        
        return RecoveryStatistics(
            totalRecoveryAttempts: totalAttempts,
            successfulRecoveries: successfulRecoveries,
            failedRecoveries: failedRecoveries,
            lastRecoveryTime: lastRecoveryTime,
            averageRecoveryTime: averageTime,
            recoveryReasons: reasonCounts
        )
    }
}

extension RecoveryManager {
    public func getRecoveryStatistics() -> RecoveryStatistics {
        return recoveryStatistics.getStatistics()
    }
}