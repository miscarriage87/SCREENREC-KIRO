import Foundation
import ScreenCaptureKit
import VideoToolbox
import Shared

@main
struct RecorderDaemon {
    static func main() async {
        print("Starting Always-On AI Companion Recorder Daemon...")
        
        // Load configuration
        let configManager = ConfigurationManager()
        guard let config = configManager.loadConfiguration() else {
            print("Failed to load configuration")
            exit(1)
        }
        
        // Initialize recovery manager
        let recoveryManager = RecoveryManager(configuration: config)
        
        // Initialize screen capture manager
        let screenCaptureManager = ScreenCaptureManager(configuration: config)
        
        // Initialize video encoder
        let videoEncoder = VideoEncoder(configuration: config)
        
        // Initialize segment manager
        let segmentManager = SegmentManager(configuration: config)
        
        // Set up recovery manager integration
        screenCaptureManager.setRecoveryManager(recoveryManager)
        segmentManager.setRecoveryManager(recoveryManager)
        
        // Set up recovery handling
        recoveryManager.onRecoveryNeeded = {
            Task {
                await restartRecording(
                    screenCaptureManager: screenCaptureManager,
                    videoEncoder: videoEncoder,
                    segmentManager: segmentManager
                )
            }
        }
        
        recoveryManager.onRecoverySuccess = {
            print("Recovery completed successfully")
        }
        
        recoveryManager.onRecoveryFailed = {
            print("Recovery failed after maximum attempts")
            exit(1)
        }
        
        // Start health monitoring
        recoveryManager.startHealthMonitoring()
        
        // Set up crash detection
        recoveryManager.setupCrashDetection()
        
        do {
            // Start recording
            try await startRecording(
                screenCaptureManager: screenCaptureManager,
                videoEncoder: videoEncoder,
                segmentManager: segmentManager
            )
            
            // Keep the daemon running
            RunLoop.main.run()
            
        } catch {
            print("Failed to start recording: \(error)")
            recoveryManager.triggerRecovery()
        }
    }
    
    private static func startRecording(
        screenCaptureManager: ScreenCaptureManager,
        videoEncoder: VideoEncoder,
        segmentManager: SegmentManager
    ) async throws {
        print("Initializing screen capture...")
        try await screenCaptureManager.startCapture()
        
        print("Starting video encoding...")
        try await videoEncoder.startEncoding()
        
        print("Starting segment management...")
        try await segmentManager.startSegmentation()
        
        print("Recording started successfully")
    }
    
    private static func restartRecording(
        screenCaptureManager: ScreenCaptureManager,
        videoEncoder: VideoEncoder,
        segmentManager: SegmentManager
    ) async {
        print("Attempting to restart recording...")
        
        do {
            // Stop current recording gracefully
            await screenCaptureManager.stopCapture()
            await videoEncoder.stopEncoding()
            await segmentManager.stopSegmentation()
            
            // Wait a moment before restarting
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Restart recording
            try await startRecording(
                screenCaptureManager: screenCaptureManager,
                videoEncoder: videoEncoder,
                segmentManager: segmentManager
            )
            
            // Report successful recovery
            screenCaptureManager.recoveryManager?.reportRecoverySuccess()
            print("Recording restarted successfully")
            
        } catch {
            print("Failed to restart recording: \(error)")
            // The recovery manager will handle retry logic
        }
    }
}