import Foundation
import ScreenCaptureKit
import CoreVideo
import AVFoundation
import Combine

/// Protocol defining the screen capture management interface
public protocol ScreenCaptureManagerProtocol {
    func startCapture() async throws
    func stopCapture() async
    func pauseCapture() async
    func resumeCapture() async
    var isRecording: Bool { get }
    var availableDisplays: [SCDisplay] { get async }
    var capturedDisplays: [DisplayCaptureSession] { get }
    func enumerateDisplays() async throws -> [DisplayInfo]
    func configureDisplays(_ displayIDs: [CGDirectDisplayID]) async throws
}

/// Information about a display
public struct DisplayInfo {
    public let displayID: CGDirectDisplayID
    public let width: Int
    public let height: Int
    public let name: String
    public let isMain: Bool
    
    public init(display: SCDisplay) {
        self.displayID = display.displayID
        self.width = display.width
        self.height = display.height
        // SCDisplay doesn't have localizedName, use a generic name
        self.name = "Display \(display.displayID)"
        self.isMain = CGDisplayIsMain(display.displayID) != 0
    }
}

/// Represents a capture session for a single display
public struct DisplayCaptureSession {
    public let displayID: CGDirectDisplayID
    public let stream: SCStream
    public let configuration: SCStreamConfiguration
    public var isActive: Bool
    
    public init(displayID: CGDirectDisplayID, stream: SCStream, configuration: SCStreamConfiguration) {
        self.displayID = displayID
        self.stream = stream
        self.configuration = configuration
        self.isActive = false
    }
}

/// Manages ScreenCaptureKit sessions for multi-monitor capture
public class ScreenCaptureManager: NSObject, ScreenCaptureManagerProtocol {
    private let configuration: RecorderConfiguration
    private var availableContent: SCShareableContent?
    private var captureSessions: [CGDirectDisplayID: DisplayCaptureSession] = [:]
    private let logger = Logger.shared
    private let sessionQueue = DispatchQueue(label: "com.alwaysonai.capture.sessions", qos: .userInitiated)
    
    // Recovery manager integration
    public weak var recoveryManager: RecoveryManager?
    
    // Allowlist manager integration
    public weak var allowlistManager: AllowlistManager?
    
    @Published public private(set) var isRecording: Bool = false
    
    public var capturedDisplays: [DisplayCaptureSession] {
        return Array(captureSessions.values)
    }
    
    public var availableDisplays: [SCDisplay] {
        get async {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return content.displays
            } catch {
                logger.error("Failed to get available displays: \(error)")
                return []
            }
        }
    }
    
    public init(configuration: RecorderConfiguration) {
        self.configuration = configuration
        super.init()
    }
    
    /// Sets the recovery manager for crash-safe operation
    public func setRecoveryManager(_ recoveryManager: RecoveryManager) {
        self.recoveryManager = recoveryManager
        
        // Set up recovery callbacks
        recoveryManager.onGracefulDegradation = { [weak self] failedDisplays in
            Task {
                await self?.handleGracefulDegradation(failedDisplays: failedDisplays)
            }
        }
    }
    
    /// Sets the allowlist manager for privacy control
    public func setAllowlistManager(_ allowlistManager: AllowlistManager) {
        self.allowlistManager = allowlistManager
        
        // Set up allowlist change callbacks
        allowlistManager.onAllowlistChanged = { [weak self] in
            Task {
                await self?.handleAllowlistChanged()
            }
        }
    }
    
    /// Handles graceful degradation by removing failed displays
    private func handleGracefulDegradation(failedDisplays: [CGDirectDisplayID]) async {
        logger.info("Handling graceful degradation for displays: \(failedDisplays)")
        
        // Stop capture sessions for failed displays
        for displayID in failedDisplays {
            if let session = captureSessions[displayID] {
                do {
                    try await session.stream.stopCapture()
                    captureSessions.removeValue(forKey: displayID)
                    logger.info("Removed failed display \(displayID) from capture")
                } catch {
                    logger.error("Failed to stop capture for display \(displayID): \(error)")
                }
            }
        }
        
        // Check if we still have active sessions
        let remainingSessions = captureSessions.values.filter { $0.isActive }
        if remainingSessions.isEmpty {
            // Try to fall back to main display
            let mainDisplayID = CGMainDisplayID()
            if !failedDisplays.contains(mainDisplayID) {
                do {
                    try await configureDisplays([mainDisplayID])
                    try await startCapture()
                    logger.info("Successfully fell back to main display")
                } catch {
                    logger.error("Failed to fall back to main display: \(error)")
                    isRecording = false
                }
            } else {
                isRecording = false
                logger.error("Cannot fall back to main display - it was one of the failed displays")
            }
        } else {
            logger.info("Continuing with \(remainingSessions.count) remaining displays")
        }
    }
    
    /// Enumerates all connected displays and returns their information
    public func enumerateDisplays() async throws -> [DisplayInfo] {
        logger.info("Enumerating connected displays")
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableContent = content
            
            let displayInfos = content.displays.map { DisplayInfo(display: $0) }
            
            logger.info("Found \(displayInfos.count) displays:")
            for info in displayInfos {
                logger.info("  - Display \(info.displayID): \(info.name) (\(info.width)x\(info.height))\(info.isMain ? " [Main]" : "")")
            }
            
            return displayInfos
        } catch {
            logger.error("Failed to enumerate displays: \(error)")
            throw ScreenCaptureError.displayEnumerationFailed(error)
        }
    }
    
    /// Configures capture sessions for specified displays
    public func configureDisplays(_ displayIDs: [CGDirectDisplayID]) async throws {
        logger.info("Configuring displays for capture: \(displayIDs)")
        
        if availableContent == nil {
            // Try to get content if not already available
            let displayInfos = try await enumerateDisplays()
            guard !displayInfos.isEmpty else {
                throw ScreenCaptureError.noAvailableContent
            }
        }
        
        guard let content = availableContent else {
            throw ScreenCaptureError.noAvailableContent
        }
        
        // Validate that all requested displays are available
        let availableDisplayIDs = Set(content.displays.map { $0.displayID })
        let requestedDisplayIDs = Set(displayIDs)
        let unavailableDisplays = requestedDisplayIDs.subtracting(availableDisplayIDs)
        
        if !unavailableDisplays.isEmpty {
            logger.warning("Some requested displays are not available: \(unavailableDisplays)")
        }
        
        let validDisplayIDs = requestedDisplayIDs.intersection(availableDisplayIDs)
        guard !validDisplayIDs.isEmpty else {
            throw ScreenCaptureError.noValidDisplays
        }
        
        // Clear existing sessions
        await stopAllCaptureSessions()
        
        // Create capture sessions for each valid display
        for displayID in validDisplayIDs {
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                continue
            }
            
            do {
                let session = try await createCaptureSession(for: display)
                captureSessions[displayID] = session
                logger.info("Created capture session for display \(displayID)")
            } catch {
                logger.error("Failed to create capture session for display \(displayID): \(error)")
                // Continue with other displays rather than failing completely
            }
        }
        
        if captureSessions.isEmpty {
            throw ScreenCaptureError.noValidCaptureSessions
        }
        
        logger.info("Successfully configured \(captureSessions.count) capture sessions")
    }
    
    /// Creates a capture session for a specific display
    private func createCaptureSession(for display: SCDisplay) async throws -> DisplayCaptureSession {
        // Create stream configuration optimized for the display
        let streamConfig = SCStreamConfiguration()
        
        // Use display's native resolution or configured resolution
        let displayWidth = display.width
        let displayHeight = display.height
        let configuredWidth = configuration.captureWidth
        let configuredHeight = configuration.captureHeight
        
        // Scale down if configured resolution is smaller than display resolution
        if configuredWidth < displayWidth || configuredHeight < displayHeight {
            let widthScale = Double(configuredWidth) / Double(displayWidth)
            let heightScale = Double(configuredHeight) / Double(displayHeight)
            let scale = min(widthScale, heightScale)
            
            streamConfig.width = Int(Double(displayWidth) * scale)
            streamConfig.height = Int(Double(displayHeight) * scale)
        } else {
            streamConfig.width = displayWidth
            streamConfig.height = displayHeight
        }
        
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
        streamConfig.queueDepth = 5
        streamConfig.showsCursor = configuration.showCursor
        streamConfig.scalesToFit = false
        streamConfig.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        
        // Create content filter for this specific display
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Create stream
        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        
        return DisplayCaptureSession(displayID: display.displayID, stream: stream, configuration: streamConfig)
    }
    
    /// Stops all active capture sessions
    private func stopAllCaptureSessions() async {
        logger.info("Stopping all capture sessions")
        
        await withTaskGroup(of: Void.self) { group in
            for (displayID, session) in captureSessions {
                group.addTask {
                    do {
                        try await session.stream.stopCapture()
                        self.logger.info("Stopped capture session for display \(displayID)")
                    } catch {
                        self.logger.error("Failed to stop capture session for display \(displayID): \(error)")
                    }
                }
            }
        }
        
        captureSessions.removeAll()
    }
    
    public func startCapture() async throws {
        logger.info("Starting multi-display screen capture")
        
        // Ensure we're not already recording
        guard !isRecording else {
            logger.warning("Capture already in progress")
            return
        }
        
        // Enumerate displays if not already done
        if availableContent == nil {
            _ = try await enumerateDisplays()
        }
        
        // Determine which displays to capture based on allowlist
        let displayIDsToCapture: [CGDirectDisplayID]
        if let allowlistManager = self.allowlistManager {
            // Use allowlist manager to determine allowed displays
            displayIDsToCapture = allowlistManager.getAllowedDisplays()
        } else if configuration.selectedDisplays.isEmpty {
            // Capture all available displays
            displayIDsToCapture = await availableDisplays.map { $0.displayID }
        } else {
            // Capture only selected displays
            displayIDsToCapture = configuration.selectedDisplays
        }
        
        guard !displayIDsToCapture.isEmpty else {
            throw ScreenCaptureError.noDisplaysSelected
        }
        
        // Configure capture sessions for the displays
        try await configureDisplays(displayIDsToCapture)
        
        // Start all capture sessions
        var startedSessions = 0
        var errors: [Error] = []
        
        await withTaskGroup(of: (CGDirectDisplayID, Result<Void, Error>).self) { group in
            for (displayID, session) in captureSessions {
                group.addTask {
                    do {
                        try await session.stream.startCapture()
                        return (displayID, .success(()))
                    } catch {
                        return (displayID, .failure(error))
                    }
                }
            }
            
            for await (displayID, result) in group {
                switch result {
                case .success():
                    captureSessions[displayID]?.isActive = true
                    startedSessions += 1
                    logger.info("Started capture for display \(displayID)")
                case .failure(let error):
                    logger.error("Failed to start capture for display \(displayID): \(error)")
                    errors.append(error)
                    // Remove failed session
                    captureSessions.removeValue(forKey: displayID)
                }
            }
        }
        
        // Check if we have at least one successful capture session
        if startedSessions == 0 {
            let combinedError = ScreenCaptureError.allCaptureSessionsFailed(errors)
            logger.error("Failed to start any capture sessions: \(combinedError)")
            throw combinedError
        }
        
        if !errors.isEmpty {
            logger.warning("Started \(startedSessions) of \(startedSessions + errors.count) capture sessions. Some displays failed to start.")
        }
        
        isRecording = true
        logger.info("Multi-display screen capture started successfully with \(startedSessions) active sessions")
    }
    
    public func stopCapture() async {
        logger.info("Stopping multi-display screen capture")
        
        guard isRecording else {
            logger.warning("No active capture to stop")
            return
        }
        
        await stopAllCaptureSessions()
        isRecording = false
        logger.info("Multi-display screen capture stopped")
    }
    
    public func pauseCapture() async {
        logger.info("Pausing screen capture")
        // ScreenCaptureKit doesn't have a native pause, so we stop and prepare to restart
        await stopCapture()
    }
    
    public func resumeCapture() async {
        logger.info("Resuming screen capture")
        do {
            try await startCapture()
        } catch {
            logger.error("Failed to resume capture: \(error)")
        }
    }
}

// MARK: - SCStreamDelegate
extension ScreenCaptureManager: SCStreamDelegate {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Handle captured frames
        switch type {
        case .screen:
            handleScreenFrame(sampleBuffer, from: stream)
        case .audio:
            // Audio handling if needed in future
            break
        case .microphone:
            // Microphone handling if needed in future
            break
        @unknown default:
            break
        }
    }
    
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Find which display this stream belongs to
        let displayID = captureSessions.first { $0.value.stream === stream }?.key
        
        logger.error("Stream for display \(displayID ?? 0) stopped with error: \(error)")
        
        // Mark this session as inactive
        if let displayID = displayID {
            captureSessions[displayID]?.isActive = false
        }
        
        // Check if all sessions have stopped
        let activeSessions = captureSessions.values.filter { $0.isActive }
        if activeSessions.isEmpty {
            isRecording = false
            logger.warning("All capture sessions have stopped")
        }
        
        // Determine recovery reason based on error
        let recoveryReason = determineRecoveryReason(from: error)
        
        // Trigger recovery if enabled
        if configuration.enableRecovery {
            // Use external recovery manager if available, otherwise use internal recovery
            if let recoveryManager = self.recoveryManager {
                let failedDisplays = displayID.map { [$0] } ?? []
                recoveryManager.triggerRecovery(reason: recoveryReason, failedDisplays: failedDisplays)
            } else {
                Task {
                    await attemptRecovery(for: displayID, after: error)
                }
            }
        }
    }
    
    /// Determines recovery reason from ScreenCaptureKit error
    private func determineRecoveryReason(from error: Error) -> RecoveryReason {
        if let scError = error as? SCStreamError {
            switch scError.code {
            case .userDeclined:
                return .permissionDenied
            case .failedToStart:
                return .screenCaptureSessionFailed
            case .missingEntitlements:
                return .permissionDenied
            default:
                return .screenCaptureSessionFailed
            }
        }
        
        // Check for common system errors
        let nsError = error as NSError
        switch nsError.code {
        case -1004: // Connection failed
            return .displayDisconnected
        case -1009: // Network connection lost (shouldn't happen for screen capture, but just in case)
            return .systemResourceExhaustion
        default:
            return .screenCaptureSessionFailed
        }
    }
    
    /// Attempts to recover a failed capture session
    private func attemptRecovery(for displayID: CGDirectDisplayID?, after error: Error) async {
        guard let displayID = displayID else {
            logger.error("Cannot recover: unknown display ID")
            return
        }
        
        logger.info("Attempting recovery for display \(displayID) after error: \(error)")
        
        // Wait for recovery timeout
        let recoveryDelay = UInt64(configuration.recoveryTimeoutSeconds) * 1_000_000_000
        try? await Task.sleep(nanoseconds: recoveryDelay)
        
        do {
            // Try to recreate the capture session for this display
            guard let content = availableContent,
                  let display = content.displays.first(where: { $0.displayID == displayID }) else {
                logger.error("Cannot recover: display \(displayID) no longer available")
                return
            }
            
            let newSession = try await createCaptureSession(for: display)
            try await newSession.stream.startCapture()
            
            // Update the session
            captureSessions[displayID] = DisplayCaptureSession(
                displayID: displayID,
                stream: newSession.stream,
                configuration: newSession.configuration
            )
            captureSessions[displayID]?.isActive = true
            
            logger.info("Successfully recovered capture session for display \(displayID)")
            
            // If this was the last session and we're not recording, mark as recording again
            if !isRecording && captureSessions.values.contains(where: { $0.isActive }) {
                isRecording = true
                logger.info("Recording resumed after recovery")
            }
            
        } catch {
            logger.error("Failed to recover capture session for display \(displayID): \(error)")
            
            // Remove the failed session
            captureSessions.removeValue(forKey: displayID)
            
            // If no sessions remain, stop recording
            if captureSessions.isEmpty {
                isRecording = false
                logger.error("All recovery attempts failed, stopping recording")
            }
        }
    }
    
    /// Handles allowlist changes by updating capture sessions
    private func handleAllowlistChanged() async {
        logger.info("Allowlist changed, updating capture sessions")
        
        guard isRecording else {
            logger.info("Not currently recording, no action needed")
            return
        }
        
        // Check if current application should be captured
        if let allowlistManager = self.allowlistManager,
           !allowlistManager.shouldCaptureCurrentApplication() {
            logger.info("Current application is not allowed, pausing capture")
            await pauseCapture()
            return
        }
        
        // Get new allowed displays
        let newAllowedDisplays = allowlistManager?.getAllowedDisplays() ?? []
        let currentDisplays = Set(captureSessions.keys)
        let newDisplaysSet = Set(newAllowedDisplays)
        
        // Stop capture for displays that are no longer allowed
        let displaysToStop = currentDisplays.subtracting(newDisplaysSet)
        for displayID in displaysToStop {
            if let session = captureSessions[displayID] {
                do {
                    try await session.stream.stopCapture()
                    captureSessions.removeValue(forKey: displayID)
                    logger.info("Stopped capture for display \(displayID) (removed from allowlist)")
                } catch {
                    logger.error("Failed to stop capture for display \(displayID): \(error)")
                }
            }
        }
        
        // Start capture for new allowed displays
        let displaysToStart = newDisplaysSet.subtracting(currentDisplays)
        if !displaysToStart.isEmpty {
            do {
                try await configureDisplays(Array(displaysToStart))
                
                // Start capture for new displays
                for displayID in displaysToStart {
                    if let session = captureSessions[displayID] {
                        try await session.stream.startCapture()
                        captureSessions[displayID]?.isActive = true
                        logger.info("Started capture for display \(displayID) (added to allowlist)")
                    }
                }
            } catch {
                logger.error("Failed to configure new displays: \(error)")
            }
        }
        
        // Update recording status
        let activeSessions = captureSessions.values.filter { $0.isActive }
        isRecording = !activeSessions.isEmpty
    }
    
    private func handleScreenFrame(_ sampleBuffer: CMSampleBuffer, from stream: SCStream) {
        // Find which display this frame came from
        guard let displayID = captureSessions.first(where: { $0.value.stream === stream })?.key else {
            logger.warning("Received frame from unknown stream")
            return
        }
        
        // Check if current application should be captured on this display
        if let allowlistManager = self.allowlistManager,
           !allowlistManager.shouldCaptureCurrentApplication(onDisplay: displayID) {
            // Skip this frame as the current application is not allowed on this display
            return
        }
        
        // Check if this display should be captured
        if let allowlistManager = self.allowlistManager,
           !allowlistManager.shouldCaptureDisplay(displayID) {
            // Skip this frame as the display is not allowed
            return
        }
        
        // Extract pixel buffer from sample buffer
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else {
            logger.warning("Failed to extract pixel buffer from sample buffer for display \(displayID)")
            return
        }
        
        // Get timestamp
        _ = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Forward to video encoder
        Task {
            // TODO: Send to video encoder
            // This will be implemented in task 3
            // For now, just log that we received a frame
            // logger.debug("Received frame from display \(displayID) at timestamp \(timestamp.seconds)")
        }
    }
}

// MARK: - Error Types
public enum ScreenCaptureError: Error {
    case noAvailableContent
    case noDisplaysSelected
    case noValidDisplays
    case noValidCaptureSessions
    case captureSessionFailed(Error)
    case permissionDenied
    case displayEnumerationFailed(Error)
    case allCaptureSessionsFailed([Error])
    
    public var localizedDescription: String {
        switch self {
        case .noAvailableContent:
            return "No available content to capture"
        case .noDisplaysSelected:
            return "No displays selected for capture"
        case .noValidDisplays:
            return "No valid displays found for capture"
        case .noValidCaptureSessions:
            return "Failed to create any valid capture sessions"
        case .captureSessionFailed(let error):
            return "Failed to start capture session: \(error.localizedDescription)"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .displayEnumerationFailed(let error):
            return "Failed to enumerate displays: \(error.localizedDescription)"
        case .allCaptureSessionsFailed(let errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: ", ")
            return "All capture sessions failed: \(errorMessages)"
        }
    }
}