import XCTest
import ScreenCaptureKit
@testable import Shared

final class RecoveryManagerTests: XCTestCase {
    var recoveryManager: RecoveryManager!
    var testConfiguration: RecorderConfiguration!
    var tempStorageURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary storage directory
        tempStorageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecoveryManagerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempStorageURL, withIntermediateDirectories: true)
        
        // Create test configuration
        testConfiguration = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: tempStorageURL,
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
            recoveryTimeoutSeconds: 2, // Shorter for testing
            enableLogging: true,
            logLevel: .info
        )
        
        recoveryManager = RecoveryManager(configuration: testConfiguration)
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempStorageURL)
        
        recoveryManager = nil
        testConfiguration = nil
        tempStorageURL = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Basic Recovery Tests
    
    func testRecoveryTriggerWithinTimeout() async throws {
        let expectation = XCTestExpectation(description: "Recovery triggered within timeout")
        
        recoveryManager.onRecoveryNeeded = {
            expectation.fulfill()
        }
        
        recoveryManager.triggerRecovery(reason: .screenCaptureSessionFailed)
        
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testRecoveryTimeoutRespected() async throws {
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Recovery triggered after timeout")
        
        recoveryManager.onRecoveryNeeded = {
            let elapsedTime = Date().timeIntervalSince(startTime)
            XCTAssertGreaterThanOrEqual(elapsedTime, 2.0, "Recovery should wait for timeout")
            XCTAssertLessThanOrEqual(elapsedTime, 3.0, "Recovery should not wait too long")
            expectation.fulfill()
        }
        
        recoveryManager.triggerRecovery(reason: .screenCaptureSessionFailed)
        
        await fulfillment(of: [expectation], timeout: 4.0)
    }
    
    func testMaxRecoveryAttemptsRespected() async throws {
        let expectation = XCTestExpectation(description: "Recovery failed after max attempts")
        
        recoveryManager.onRecoveryFailed = {
            expectation.fulfill()
        }
        
        // Trigger recovery multiple times to exceed max attempts
        for _ in 0..<6 {
            recoveryManager.triggerRecovery(reason: .screenCaptureSessionFailed)
            recoveryManager.cancelRecovery() // Cancel to allow next attempt
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Graceful Degradation Tests
    
    func testGracefulDegradationCallback() async throws {
        let expectation = XCTestExpectation(description: "Graceful degradation triggered")
        let failedDisplays: [CGDirectDisplayID] = [1, 2]
        
        recoveryManager.onGracefulDegradation = { displays in
            XCTAssertEqual(displays, failedDisplays)
            expectation.fulfill()
        }
        
        recoveryManager.triggerRecovery(reason: .multiMonitorFailure, failedDisplays: failedDisplays)
        
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testSingleMonitorFallbackStrategy() async throws {
        let expectation = XCTestExpectation(description: "Single monitor fallback triggered")
        let multipleFailedDisplays: [CGDirectDisplayID] = [1, 2, 3]
        
        recoveryManager.onRecoveryStrategySelected = { strategy in
            if case .singleMonitorFallback(let displayID) = strategy {
                XCTAssertEqual(displayID, CGMainDisplayID())
                expectation.fulfill()
            }
        }
        
        recoveryManager.triggerRecovery(reason: .multiMonitorFailure, failedDisplays: multipleFailedDisplays)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Partial Segment Cleanup Tests
    
    func testPartialSegmentCleanup() async throws {
        // Create test partial segments
        let segmentsDir = tempStorageURL.appendingPathComponent("segments")
        try FileManager.default.createDirectory(at: segmentsDir, withIntermediateDirectories: true)
        
        let partialSegmentURL = segmentsDir.appendingPathComponent("partial_segment.mp4")
        let smallData = Data(repeating: 0, count: 500) // Small file (500 bytes)
        try smallData.write(to: partialSegmentURL)
        
        let validSegmentURL = segmentsDir.appendingPathComponent("valid_segment.mp4")
        let largeData = Data(repeating: 0, count: 2_000_000) // Large file (2MB)
        try largeData.write(to: validSegmentURL)
        
        let expectation = XCTestExpectation(description: "Partial segment cleaned up")
        
        recoveryManager.onPartialSegmentCleanup = { url in
            XCTAssertEqual(url.lastPathComponent, "partial_segment.mp4")
            expectation.fulfill()
        }
        
        recoveryManager.addPartialSegmentForCleanup(partialSegmentURL)
        recoveryManager.triggerRecovery(reason: .crash)
        
        await fulfillment(of: [expectation], timeout: 3.0)
        
        // Verify partial segment was removed and valid segment remains
        XCTAssertFalse(FileManager.default.fileExists(atPath: partialSegmentURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: validSegmentURL.path))
    }
    
    func testOrphanedSegmentDetection() async throws {
        // Create test segments directory structure
        let segmentsDir = tempStorageURL.appendingPathComponent("segments")
        try FileManager.default.createDirectory(at: segmentsDir, withIntermediateDirectories: true)
        
        // Create an orphaned segment (small and recent)
        let orphanedSegmentURL = segmentsDir.appendingPathComponent("orphaned_segment.mp4")
        let smallData = Data(repeating: 0, count: 500) // Small file
        try smallData.write(to: orphanedSegmentURL)
        
        // Create a valid segment (large)
        let validSegmentURL = segmentsDir.appendingPathComponent("valid_segment.mp4")
        let largeData = Data(repeating: 0, count: 2_000_000) // Large file
        try largeData.write(to: validSegmentURL)
        
        let expectation = XCTestExpectation(description: "Orphaned segment detected and cleaned")
        
        recoveryManager.onPartialSegmentCleanup = { url in
            if url.lastPathComponent == "orphaned_segment.mp4" {
                expectation.fulfill()
            }
        }
        
        recoveryManager.triggerRecovery(reason: .crash)
        
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    // MARK: - Recovery Statistics Tests
    
    func testRecoveryStatisticsTracking() async throws {
        let successExpectation = XCTestExpectation(description: "Recovery success recorded")
        
        recoveryManager.onRecoveryNeeded = {
            // Simulate successful recovery
            self.recoveryManager.reportRecoverySuccess()
        }
        
        recoveryManager.onRecoverySuccess = {
            successExpectation.fulfill()
        }
        
        recoveryManager.triggerRecovery(reason: .screenCaptureSessionFailed)
        
        await fulfillment(of: [successExpectation], timeout: 3.0)
        
        let statistics = recoveryManager.getRecoveryStatistics()
        XCTAssertEqual(statistics.totalRecoveryAttempts, 1)
        XCTAssertEqual(statistics.successfulRecoveries, 1)
        XCTAssertEqual(statistics.failedRecoveries, 0)
        XCTAssertEqual(statistics.successRate, 1.0)
        XCTAssertNotNil(statistics.lastRecoveryTime)
        XCTAssertGreaterThan(statistics.averageRecoveryTime, 0)
    }
    
    func testRecoveryReasonTracking() async throws {
        let expectation = XCTestExpectation(description: "Recovery reasons tracked")
        expectation.expectedFulfillmentCount = 3
        
        recoveryManager.onRecoveryNeeded = {
            expectation.fulfill()
        }
        
        // Trigger different types of recovery
        recoveryManager.triggerRecovery(reason: .screenCaptureSessionFailed)
        recoveryManager.cancelRecovery()
        
        recoveryManager.triggerRecovery(reason: .multiMonitorFailure)
        recoveryManager.cancelRecovery()
        
        recoveryManager.triggerRecovery(reason: .permissionDenied)
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        let statistics = recoveryManager.getRecoveryStatistics()
        XCTAssertEqual(statistics.totalRecoveryAttempts, 3)
        XCTAssertEqual(statistics.recoveryReasons[.screenCaptureSessionFailed], 1)
        XCTAssertEqual(statistics.recoveryReasons[.multiMonitorFailure], 1)
        XCTAssertEqual(statistics.recoveryReasons[.permissionDenied], 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testRecoveryDuringActiveRecovery() async throws {
        let firstExpectation = XCTestExpectation(description: "First recovery triggered")
        
        recoveryManager.onRecoveryNeeded = {
            firstExpectation.fulfill()
        }
        
        // Trigger first recovery
        recoveryManager.triggerRecovery(reason: .screenCaptureSessionFailed)
        
        // Try to trigger second recovery while first is active
        recoveryManager.triggerRecovery(reason: .multiMonitorFailure)
        
        await fulfillment(of: [firstExpectation], timeout: 3.0)
        
        // Should only have one recovery attempt
        let statistics = recoveryManager.getRecoveryStatistics()
        XCTAssertEqual(statistics.totalRecoveryAttempts, 1)
    }
    
    func testRecoveryWithInvalidConfiguration() async throws {
        // Create recovery manager without configuration
        let noConfigRecoveryManager = RecoveryManager(configuration: nil)
        
        let expectation = XCTestExpectation(description: "Recovery with default timeout")
        
        noConfigRecoveryManager.onRecoveryNeeded = {
            expectation.fulfill()
        }
        
        noConfigRecoveryManager.triggerRecovery(reason: .screenCaptureSessionFailed)
        
        await fulfillment(of: [expectation], timeout: 6.0) // Default timeout is 5 seconds
    }
}

// MARK: - Integration Tests

final class RecoveryManagerIntegrationTests: XCTestCase {
    var recoveryManager: RecoveryManager!
    var screenCaptureManager: ScreenCaptureManager!
    var segmentManager: SegmentManager!
    var testConfiguration: RecorderConfiguration!
    var tempStorageURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary storage directory
        tempStorageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecoveryIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempStorageURL, withIntermediateDirectories: true)
        
        // Create test configuration
        testConfiguration = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000,
            segmentDuration: 120,
            storageURL: tempStorageURL,
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
            recoveryTimeoutSeconds: 2,
            enableLogging: true,
            logLevel: .info
        )
        
        // Initialize components
        recoveryManager = RecoveryManager(configuration: testConfiguration)
        screenCaptureManager = ScreenCaptureManager(configuration: testConfiguration)
        segmentManager = SegmentManager(configuration: testConfiguration)
        
        // Set up integration
        screenCaptureManager.setRecoveryManager(recoveryManager)
        segmentManager.setRecoveryManager(recoveryManager)
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempStorageURL)
        
        recoveryManager = nil
        screenCaptureManager = nil
        segmentManager = nil
        testConfiguration = nil
        tempStorageURL = nil
        
        try await super.tearDown()
    }
    
    func testScreenCaptureManagerRecoveryIntegration() async throws {
        let expectation = XCTestExpectation(description: "Screen capture recovery integration")
        
        recoveryManager.onGracefulDegradation = { failedDisplays in
            XCTAssertFalse(failedDisplays.isEmpty)
            expectation.fulfill()
        }
        
        // Simulate a display failure
        let fakeDisplayID: CGDirectDisplayID = 999
        recoveryManager.triggerRecovery(reason: .displayDisconnected, failedDisplays: [fakeDisplayID])
        
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testSegmentManagerPartialCleanupIntegration() async throws {
        // Create a partial segment
        let segmentsDir = tempStorageURL.appendingPathComponent("segments")
        let todayDir = segmentsDir.appendingPathComponent("2024-01-01")
        try FileManager.default.createDirectory(at: todayDir, withIntermediateDirectories: true)
        
        let partialSegmentURL = todayDir.appendingPathComponent("partial_segment.mp4")
        let smallData = Data(repeating: 0, count: 500)
        try smallData.write(to: partialSegmentURL)
        
        let expectation = XCTestExpectation(description: "Segment manager partial cleanup")
        
        recoveryManager.onPartialSegmentCleanup = { url in
            XCTAssertEqual(url.lastPathComponent, "partial_segment.mp4")
            expectation.fulfill()
        }
        
        // Start and stop segmentation to trigger cleanup
        try await segmentManager.startSegmentation()
        await segmentManager.stopSegmentation()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testEndToEndRecoveryFlow() async throws {
        let recoveryExpectation = XCTestExpectation(description: "End-to-end recovery flow")
        let cleanupExpectation = XCTestExpectation(description: "Cleanup completed")
        
        // Create some partial segments
        let segmentsDir = tempStorageURL.appendingPathComponent("segments")
        try FileManager.default.createDirectory(at: segmentsDir, withIntermediateDirectories: true)
        
        let partialSegmentURL = segmentsDir.appendingPathComponent("partial.mp4")
        let smallData = Data(repeating: 0, count: 500)
        try smallData.write(to: partialSegmentURL)
        
        recoveryManager.onRecoveryNeeded = {
            recoveryExpectation.fulfill()
        }
        
        recoveryManager.onPartialSegmentCleanup = { _ in
            cleanupExpectation.fulfill()
        }
        
        // Add partial segment and trigger recovery
        recoveryManager.addPartialSegmentForCleanup(partialSegmentURL)
        recoveryManager.triggerRecovery(reason: .crash)
        
        await fulfillment(of: [recoveryExpectation, cleanupExpectation], timeout: 5.0)
        
        // Verify cleanup occurred
        XCTAssertFalse(FileManager.default.fileExists(atPath: partialSegmentURL.path))
    }
}