import Foundation
import CoreGraphics
import Shared

/// Demo script showing how to use the ScreenCaptureManager for multi-display capture
@main
struct ScreenCaptureDemo {
    static func main() async {
        print("=== Always-On AI Companion Screen Capture Demo ===")
        
        // Create configuration manager and load configuration
        let configManager = ConfigurationManager()
        guard let config = configManager.loadConfiguration() else {
            print("❌ Failed to load configuration")
            return
        }
        
        print("✅ Configuration loaded successfully")
        print("   - Capture resolution: \(config.captureWidth)x\(config.captureHeight)")
        print("   - Frame rate: \(config.frameRate) FPS")
        print("   - Target bitrate: \(config.targetBitrate / 1_000_000) Mbps")
        print("   - Segment duration: \(Int(config.segmentDuration)) seconds")
        print("   - Recovery enabled: \(config.enableRecovery)")
        print("   - Recovery timeout: \(config.recoveryTimeoutSeconds) seconds")
        
        // Create screen capture manager
        let screenCaptureManager = ScreenCaptureManager(configuration: config)
        
        print("\n=== Display Enumeration ===")
        
        do {
            // Enumerate available displays
            let displays = try await screenCaptureManager.enumerateDisplays()
            print("✅ Found \(displays.count) display(s):")
            
            for (index, display) in displays.enumerated() {
                print("   \(index + 1). \(display.name)")
                print("      - ID: \(display.displayID)")
                print("      - Resolution: \(display.width)x\(display.height)")
                print("      - Main display: \(display.isMain ? "Yes" : "No")")
            }
            
            // Test display configuration
            print("\n=== Display Configuration ===")
            let displayIDs = displays.map { $0.displayID }
            
            if !displayIDs.isEmpty {
                try await screenCaptureManager.configureDisplays(displayIDs)
                print("✅ Successfully configured \(screenCaptureManager.capturedDisplays.count) capture session(s)")
                
                for session in screenCaptureManager.capturedDisplays {
                    print("   - Display \(session.displayID): \(session.configuration.width)x\(session.configuration.height)")
                }
            }
            
            // Test capture start/stop (without actually capturing due to permissions)
            print("\n=== Capture Session Management ===")
            print("ℹ️  Initial recording state: \(screenCaptureManager.isRecording)")
            
            // Note: Actual capture would require screen recording permissions
            print("ℹ️  To test actual capture, grant screen recording permissions in System Preferences")
            print("   Security & Privacy > Privacy > Screen Recording")
            
            // Demonstrate error handling
            print("\n=== Error Handling Demo ===")
            let invalidDisplayIDs: [CGDirectDisplayID] = [999999, 888888]
            
            do {
                try await screenCaptureManager.configureDisplays(invalidDisplayIDs)
                print("❌ Unexpected success with invalid display IDs")
            } catch ScreenCaptureError.noValidDisplays {
                print("✅ Correctly handled invalid display IDs")
            } catch {
                print("❌ Unexpected error: \(error)")
            }
            
            // Test mixed valid/invalid displays
            if let validDisplayID = displays.first?.displayID {
                let mixedDisplayIDs = [validDisplayID, 999999]
                
                do {
                    try await screenCaptureManager.configureDisplays(mixedDisplayIDs)
                    print("✅ Successfully handled mixed valid/invalid display IDs")
                    print("   - Created \(screenCaptureManager.capturedDisplays.count) session(s) from \(mixedDisplayIDs.count) requested")
                } catch {
                    print("❌ Failed to handle mixed display IDs: \(error)")
                }
            }
            
        } catch {
            print("❌ Display enumeration failed: \(error)")
            
            if case ScreenCaptureError.displayEnumerationFailed(let underlyingError) = error {
                print("   Underlying error: \(underlyingError)")
                
                // Check if it's a permission error
                if underlyingError.localizedDescription.contains("declined TCCs") {
                    print("   💡 This is likely due to missing screen recording permissions")
                    print("   Please grant permissions in System Preferences > Security & Privacy > Privacy > Screen Recording")
                }
            }
        }
        
        // Clean up
        await screenCaptureManager.stopCapture()
        print("\n✅ Demo completed successfully")
    }
}