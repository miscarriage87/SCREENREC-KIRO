import XCTest
import ScreenCaptureKit
import CoreGraphics
@testable import Shared

final class ScreenCaptureManagerTests: XCTestCase {
    
    var screenCaptureManager: ScreenCaptureManager!
    var testConfiguration: RecorderConfiguration!
    
    override func setUp() {
        super.setUp()
        
        // Create test configuration
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            XCTFail("Could not get documents directory")
            return
        }
        let storageURL = documentsURL.appendingPathComponent("AlwaysOnAICompanionTests")
        
        testConfiguration = RecorderConfiguration(
            selectedDisplays: [], // Empty means all displays
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: storageURL,
            maxStorageDays: 30,
            maxCPUUsage: 8.0,
            maxMemoryUsage: 512,
            maxDiskIORate: 20.0,
            enablePIIMasking: true,
            allowedApplications: [],
            blockedApplications: [],
            pauseHotkey: "cmd+shift+p",
            autoStart: true,
            enableRecovery: true,
            recoveryTimeoutSeconds: 5,
            enableLogging: true,
            logLevel: .info
        )
        
        screenCaptureManager = ScreenCaptureManager(configuration: testConfiguration)
    }
    
    override func tearDown() {
        // Clean up any active capture sessions
        if let manager = screenCaptureManager {
            let expectation = XCTestExpectation(description: "Stop capture")
            Task {
                await manager.stopCapture()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
        
        screenCaptureManager = nil
        testConfiguration = nil
        super.tearDown()
    }
    
    // MARK: - Display Enumeration Tests
    
    func testDisplayEnumeration() async throws {
        // Test that we can enumerate displays
        let displays = try await screenCaptureManager.enumerateDisplays()
        
        // We should have at least one display (the main display)
        XCTAssertGreaterThan(displays.count, 0, "Should have at least one display")
        
        // Check that we have a main display
        let mainDisplays = displays.filter { $0.isMain }
        XCTAssertEqual(mainDisplays.count, 1, "Should have exactly one main display")
        
        // Verify display properties
        for display in displays {
            XCTAssertGreaterThan(display.width, 0, "Display width should be positive")
            XCTAssertGreaterThan(display.height, 0, "Display height should be positive")
            XCTAssertFalse(display.name.isEmpty, "Display name should not be empty")
        }
    }
    
    func testAvailableDisplaysProperty() async {
        let displays = await screenCaptureManager.availableDisplays
        
        // Should have at least one display
        XCTAssertGreaterThan(displays.count, 0, "Should have at least one available display")
        
        // Verify SCDisplay properties
        for display in displays {
            XCTAssertGreaterThan(display.width, 0, "SCDisplay width should be positive")
            XCTAssertGreaterThan(display.height, 0, "SCDisplay height should be positive")
        }
    }
    
    // MARK: - Display Configuration Tests
    
    func testConfigureDisplaysWithValidDisplays() async throws {
        // First enumerate displays to get valid IDs
        let displayInfos = try await screenCaptureManager.enumerateDisplays()
        let displayIDs = displayInfos.map { $0.displayID }
        
        // Configure displays
        try await screenCaptureManager.configureDisplays(displayIDs)
        
        // Verify that capture sessions were created
        let capturedDisplays = screenCaptureManager.capturedDisplays
        XCTAssertEqual(capturedDisplays.count, displayIDs.count, "Should create capture sessions for all valid displays")
        
        // Verify each session
        for session in capturedDisplays {
            XCTAssertTrue(displayIDs.contains(session.displayID), "Session should be for a requested display")
            XCTAssertNotNil(session.stream, "Session should have a stream")
            XCTAssertNotNil(session.configuration, "Session should have a configuration")
        }
    }
    
    func testConfigureDisplaysWithInvalidDisplays() async {
        // Use invalid display IDs
        let invalidDisplayIDs: [CGDirectDisplayID] = [999999, 888888]
        
        do {
            try await screenCaptureManager.configureDisplays(invalidDisplayIDs)
            XCTFail("Should throw error for invalid display IDs")
        } catch ScreenCaptureError.noValidDisplays {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testConfigureDisplaysWithMixedValidInvalidDisplays() async throws {
        // Get one valid display ID
        let displayInfos = try await screenCaptureManager.enumerateDisplays()
        guard let validDisplayID = displayInfos.first?.displayID else {
            XCTFail("No displays available for testing")
            return
        }
        
        // Mix valid and invalid display IDs
        let mixedDisplayIDs: [CGDirectDisplayID] = [validDisplayID, 999999]
        
        // Should succeed with the valid display
        try await screenCaptureManager.configureDisplays(mixedDisplayIDs)
        
        let capturedDisplays = screenCaptureManager.capturedDisplays
        XCTAssertEqual(capturedDisplays.count, 1, "Should create session only for valid display")
        XCTAssertEqual(capturedDisplays.first?.displayID, validDisplayID, "Should capture the valid display")
    }
    
    // MARK: - Capture Session Management Tests
    
    func testInitialState() {
        XCTAssertFalse(screenCaptureManager.isRecording, "Should not be recording initially")
        XCTAssertEqual(screenCaptureManager.capturedDisplays.count, 0, "Should have no capture sessions initially")
    }
    
    func testStartCaptureWithAllDisplays() async throws {
        // Test starting capture with all displays (empty selectedDisplays)
        let configWithAllDisplays = RecorderConfiguration(
            selectedDisplays: [], // Empty means all displays
            captureWidth: testConfiguration.captureWidth,
            captureHeight: testConfiguration.captureHeight,
            frameRate: testConfiguration.frameRate,
            showCursor: testConfiguration.showCursor,
            targetBitrate: testConfiguration.targetBitrate,
            segmentDuration: testConfiguration.segmentDuration,
            storageURL: testConfiguration.storageURL,
            maxStorageDays: testConfiguration.maxStorageDays,
            maxCPUUsage: testConfiguration.maxCPUUsage,
            maxMemoryUsage: testConfiguration.maxMemoryUsage,
            maxDiskIORate: testConfiguration.maxDiskIORate,
            enablePIIMasking: testConfiguration.enablePIIMasking,
            allowedApplications: testConfiguration.allowedApplications,
            blockedApplications: testConfiguration.blockedApplications,
            pauseHotkey: testConfiguration.pauseHotkey,
            autoStart: testConfiguration.autoStart,
            enableRecovery: testConfiguration.enableRecovery,
            recoveryTimeoutSeconds: testConfiguration.recoveryTimeoutSeconds,
            enableLogging: testConfiguration.enableLogging,
            logLevel: testConfiguration.logLevel
        )
        
        let manager = ScreenCaptureManager(configuration: configWithAllDisplays)
        
        do {
            try await manager.startCapture()
            
            XCTAssertTrue(manager.isRecording, "Should be recording after start")
            XCTAssertGreaterThan(manager.capturedDisplays.count, 0, "Should have capture sessions")
            
            // Clean up
            await manager.stopCapture()
            XCTAssertFalse(manager.isRecording, "Should not be recording after stop")
            
        } catch ScreenCaptureError.permissionDenied {
            // Skip test if permissions are not granted
            throw XCTSkip("Screen recording permission not granted")
        } catch {
            XCTFail("Unexpected error starting capture: \(error)")
        }
    }
    
    func testStartCaptureWithSpecificDisplays() async throws {
        // Get available displays
        let displayInfos = try await screenCaptureManager.enumerateDisplays()
        guard let firstDisplay = displayInfos.first else {
            XCTFail("No displays available for testing")
            return
        }
        
        // Create configuration with specific display
        let configWithSpecificDisplay = RecorderConfiguration(
            selectedDisplays: [firstDisplay.displayID],
            captureWidth: testConfiguration.captureWidth,
            captureHeight: testConfiguration.captureHeight,
            frameRate: testConfiguration.frameRate,
            showCursor: testConfiguration.showCursor,
            targetBitrate: testConfiguration.targetBitrate,
            segmentDuration: testConfiguration.segmentDuration,
            storageURL: testConfiguration.storageURL,
            maxStorageDays: testConfiguration.maxStorageDays,
            maxCPUUsage: testConfiguration.maxCPUUsage,
            maxMemoryUsage: testConfiguration.maxMemoryUsage,
            maxDiskIORate: testConfiguration.maxDiskIORate,
            enablePIIMasking: testConfiguration.enablePIIMasking,
            allowedApplications: testConfiguration.allowedApplications,
            blockedApplications: testConfiguration.blockedApplications,
            pauseHotkey: testConfiguration.pauseHotkey,
            autoStart: testConfiguration.autoStart,
            enableRecovery: testConfiguration.enableRecovery,
            recoveryTimeoutSeconds: testConfiguration.recoveryTimeoutSeconds,
            enableLogging: testConfiguration.enableLogging,
            logLevel: testConfiguration.logLevel
        )
        
        let manager = ScreenCaptureManager(configuration: configWithSpecificDisplay)
        
        do {
            try await manager.startCapture()
            
            XCTAssertTrue(manager.isRecording, "Should be recording after start")
            XCTAssertEqual(manager.capturedDisplays.count, 1, "Should have one capture session")
            XCTAssertEqual(manager.capturedDisplays.first?.displayID, firstDisplay.displayID, "Should capture the specified display")
            
            // Clean up
            await manager.stopCapture()
            
        } catch ScreenCaptureError.permissionDenied {
            // Skip test if permissions are not granted
            throw XCTSkip("Screen recording permission not granted")
        } catch {
            XCTFail("Unexpected error starting capture: \(error)")
        }
    }
    
    func testStopCapture() async throws {
        do {
            try await screenCaptureManager.startCapture()
            XCTAssertTrue(screenCaptureManager.isRecording, "Should be recording after start")
            
            await screenCaptureManager.stopCapture()
            XCTAssertFalse(screenCaptureManager.isRecording, "Should not be recording after stop")
            XCTAssertEqual(screenCaptureManager.capturedDisplays.count, 0, "Should have no capture sessions after stop")
            
        } catch ScreenCaptureError.permissionDenied {
            // Skip test if permissions are not granted
            throw XCTSkip("Screen recording permission not granted")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testPauseAndResumeCapture() async throws {
        do {
            try await screenCaptureManager.startCapture()
            XCTAssertTrue(screenCaptureManager.isRecording, "Should be recording after start")
            
            await screenCaptureManager.pauseCapture()
            XCTAssertFalse(screenCaptureManager.isRecording, "Should not be recording after pause")
            
            await screenCaptureManager.resumeCapture()
            XCTAssertTrue(screenCaptureManager.isRecording, "Should be recording after resume")
            
            // Clean up
            await screenCaptureManager.stopCapture()
            
        } catch ScreenCaptureError.permissionDenied {
            // Skip test if permissions are not granted
            throw XCTSkip("Screen recording permission not granted")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDoubleStartCapture() async throws {
        do {
            try await screenCaptureManager.startCapture()
            XCTAssertTrue(screenCaptureManager.isRecording, "Should be recording after first start")
            
            // Starting again should not throw an error, just return early
            try await screenCaptureManager.startCapture()
            XCTAssertTrue(screenCaptureManager.isRecording, "Should still be recording after second start")
            
            // Clean up
            await screenCaptureManager.stopCapture()
            
        } catch ScreenCaptureError.permissionDenied {
            // Skip test if permissions are not granted
            throw XCTSkip("Screen recording permission not granted")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testStopCaptureWhenNotRecording() async {
        XCTAssertFalse(screenCaptureManager.isRecording, "Should not be recording initially")
        
        // Stopping when not recording should not crash
        await screenCaptureManager.stopCapture()
        XCTAssertFalse(screenCaptureManager.isRecording, "Should still not be recording")
    }
    
    // MARK: - Error Handling Tests
    
    func testScreenCaptureErrorDescriptions() {
        let errors: [ScreenCaptureError] = [
            .noAvailableContent,
            .noDisplaysSelected,
            .noValidDisplays,
            .noValidCaptureSessions,
            .captureSessionFailed(NSError(domain: "test", code: 1)),
            .permissionDenied,
            .displayEnumerationFailed(NSError(domain: "test", code: 2)),
            .allCaptureSessionsFailed([NSError(domain: "test", code: 3)])
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Display Info Tests
    
    func testDisplayInfoInitialization() async throws {
        let displays = await screenCaptureManager.availableDisplays
        guard let scDisplay = displays.first else {
            XCTFail("No displays available for testing")
            return
        }
        
        let displayInfo = DisplayInfo(display: scDisplay)
        
        XCTAssertEqual(displayInfo.displayID, scDisplay.displayID)
        XCTAssertEqual(displayInfo.width, scDisplay.width)
        XCTAssertEqual(displayInfo.height, scDisplay.height)
        XCTAssertEqual(displayInfo.name, "Display \(scDisplay.displayID)")
        XCTAssertEqual(displayInfo.isMain, CGDisplayIsMain(scDisplay.displayID) != 0)
    }
    
    // MARK: - Configuration Tests
    
    func testCaptureSessionConfiguration() async throws {
        let displayInfos = try await screenCaptureManager.enumerateDisplays()
        guard let firstDisplay = displayInfos.first else {
            XCTFail("No displays available for testing")
            return
        }
        
        try await screenCaptureManager.configureDisplays([firstDisplay.displayID])
        
        let capturedDisplays = screenCaptureManager.capturedDisplays
        guard let session = capturedDisplays.first else {
            XCTFail("No capture session created")
            return
        }
        
        let config = session.configuration
        
        // Verify configuration properties
        XCTAssertGreaterThan(config.width, 0, "Width should be positive")
        XCTAssertGreaterThan(config.height, 0, "Height should be positive")
        XCTAssertEqual(config.showsCursor, testConfiguration.showCursor, "Cursor setting should match configuration")
        XCTAssertEqual(config.pixelFormat, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, "Pixel format should be yuv420p")
        XCTAssertEqual(config.queueDepth, 5, "Queue depth should be 5")
        XCTAssertFalse(config.scalesToFit, "Should not scale to fit")
    }
}