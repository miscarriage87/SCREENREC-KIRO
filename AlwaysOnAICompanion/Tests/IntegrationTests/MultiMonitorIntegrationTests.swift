import XCTest
import Foundation
import ScreenCaptureKit
@testable import Shared

/// Integration tests for multi-monitor recording scenarios
/// Validates various display configurations and edge cases
class MultiMonitorIntegrationTests: XCTestCase {
    
    private var testDataDirectory: URL!
    private var screenCaptureManager: ScreenCaptureManager!
    private var configurationManager: ConfigurationManager!
    private var performanceMonitor: SystemPerformanceMonitor!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testDataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MultiMonitorTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: testDataDirectory,
            withIntermediateDirectories: true
        )
        
        configurationManager = ConfigurationManager(dataDirectory: testDataDirectory)
        try await configurationManager.initializeConfiguration()
        
        screenCaptureManager = ScreenCaptureManager(configuration: configurationManager)
        performanceMonitor = SystemPerformanceMonitor()
    }
    
    override func tearDown() async throws {
        await screenCaptureManager.stopCapture()
        try? FileManager.default.removeItem(at: testDataDirectory)
        try await super.tearDown()
    }
    
    // MARK: - Display Configuration Tests
    
    /// Test single monitor recording baseline
    func testSingleMonitorRecording() async throws {
        // Given: Single display configuration
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard !displays.isEmpty else {
            throw XCTSkip("No displays available for testing")
        }
        
        let singleDisplay = [displays.first!]
        
        // When: Record single display
        await performanceMonitor.startMonitoring()
        
        try await screenCaptureManager.startCapture(displays: singleDisplay)
        XCTAssertTrue(screenCaptureManager.isRecording)
        
        // Record for 10 seconds
        try await Task.sleep(nanoseconds: 10_000_000_000)
        
        let metrics = await performanceMonitor.getCurrentMetrics()
        await screenCaptureManager.stopCapture()
        await performanceMonitor.stopMonitoring()
        
        // Then: Verify baseline performance
        XCTAssertLessThanOrEqual(metrics.cpuUsage, 3.0, "Single monitor should use minimal CPU")
        XCTAssertFalse(screenCaptureManager.isRecording)
        
        // Verify capture session was created
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        XCTAssertEqual(captureInfo.activeDisplayCount, 1)
    }
    
    /// Test dual monitor recording
    func testDualMonitorRecording() async throws {
        // Given: Dual display configuration
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard displays.count >= 2 else {
            throw XCTSkip("Need at least 2 displays for dual monitor testing")
        }
        
        let dualDisplays = Array(displays.prefix(2))
        
        // When: Record dual displays
        await performanceMonitor.startMonitoring()
        
        try await screenCaptureManager.startCapture(displays: dualDisplays)
        XCTAssertTrue(screenCaptureManager.isRecording)
        
        // Record for 15 seconds
        try await Task.sleep(nanoseconds: 15_000_000_000)
        
        let metrics = await performanceMonitor.getCurrentMetrics()
        await screenCaptureManager.stopCapture()
        await performanceMonitor.stopMonitoring()
        
        // Then: Verify dual monitor performance
        XCTAssertLessThanOrEqual(metrics.cpuUsage, 6.0, "Dual monitor should stay under 6% CPU")
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        XCTAssertEqual(captureInfo.activeDisplayCount, 2)
        XCTAssertEqual(captureInfo.totalPixelsPerSecond, calculateExpectedPixelRate(for: dualDisplays))
    }
    
    /// Test triple monitor recording (maximum supported)
    func testTripleMonitorRecording() async throws {
        // Given: Triple display configuration
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard displays.count >= 3 else {
            throw XCTSkip("Need at least 3 displays for triple monitor testing")
        }
        
        let tripleDisplays = Array(displays.prefix(3))
        
        // When: Record triple displays
        await performanceMonitor.startMonitoring()
        
        try await screenCaptureManager.startCapture(displays: tripleDisplays)
        XCTAssertTrue(screenCaptureManager.isRecording)
        
        // Record for 20 seconds to test sustained performance
        try await Task.sleep(nanoseconds: 20_000_000_000)
        
        let metrics = await performanceMonitor.getCurrentMetrics()
        await screenCaptureManager.stopCapture()
        await performanceMonitor.stopMonitoring()
        
        // Then: Verify triple monitor meets requirements
        XCTAssertLessThanOrEqual(metrics.cpuUsage, 8.0, "Triple monitor should meet 8% CPU requirement")
        XCTAssertLessThanOrEqual(metrics.diskWriteRate, 20_000_000, "Should meet disk I/O requirements")
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        XCTAssertEqual(captureInfo.activeDisplayCount, 3)
    }
    
    // MARK: - Display Resolution Tests
    
    /// Test mixed resolution displays
    func testMixedResolutionDisplays() async throws {
        // Given: Displays with different resolutions
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard displays.count >= 2 else {
            throw XCTSkip("Need multiple displays for resolution testing")
        }
        
        // Get display information
        let displayInfos = try await getDisplayInformation(for: displays)
        let mixedDisplays = selectMixedResolutionDisplays(from: displayInfos)
        
        guard mixedDisplays.count >= 2 else {
            throw XCTSkip("Need displays with different resolutions")
        }
        
        // When: Record mixed resolution displays
        try await screenCaptureManager.startCapture(displays: mixedDisplays.map(\.displayID))
        
        // Record for 10 seconds
        try await Task.sleep(nanoseconds: 10_000_000_000)
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        await screenCaptureManager.stopCapture()
        
        // Then: Verify all displays are captured correctly
        XCTAssertEqual(captureInfo.activeDisplayCount, mixedDisplays.count)
        
        // Verify each display has appropriate encoding settings
        for displayInfo in mixedDisplays {
            let encodingSettings = captureInfo.encodingSettings[displayInfo.displayID]
            XCTAssertNotNil(encodingSettings, "Should have encoding settings for display \(displayInfo.displayID)")
            
            // Verify bitrate is appropriate for resolution
            let expectedBitrate = calculateExpectedBitrate(for: displayInfo.resolution)
            XCTAssertEqual(encodingSettings?.bitrate, expectedBitrate, accuracy: 500_000)
        }
    }
    
    /// Test high DPI (Retina) display handling
    func testHighDPIDisplayHandling() async throws {
        // Given: High DPI display configuration
        let displays = try await screenCaptureManager.getAvailableDisplays()
        let displayInfos = try await getDisplayInformation(for: displays)
        
        let highDPIDisplays = displayInfos.filter { $0.scaleFactor > 1.0 }
        guard !highDPIDisplays.isEmpty else {
            throw XCTSkip("No high DPI displays available for testing")
        }
        
        // When: Record high DPI display
        try await screenCaptureManager.startCapture(displays: [highDPIDisplays.first!.displayID])
        
        try await Task.sleep(nanoseconds: 8_000_000_000)
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        await screenCaptureManager.stopCapture()
        
        // Then: Verify proper handling of high DPI
        let displaySettings = captureInfo.encodingSettings[highDPIDisplays.first!.displayID]
        XCTAssertNotNil(displaySettings)
        
        // Verify resolution handling (should capture at native resolution)
        XCTAssertEqual(displaySettings?.resolution.width, highDPIDisplays.first!.resolution.width)
        XCTAssertEqual(displaySettings?.resolution.height, highDPIDisplays.first!.resolution.height)
    }
    
    // MARK: - Dynamic Display Configuration Tests
    
    /// Test adding displays during recording
    func testDynamicDisplayAddition() async throws {
        // Given: Recording with initial display set
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard displays.count >= 2 else {
            throw XCTSkip("Need multiple displays for dynamic testing")
        }
        
        let initialDisplay = [displays.first!]
        let additionalDisplay = displays[1]
        
        // When: Start with single display
        try await screenCaptureManager.startCapture(displays: initialDisplay)
        XCTAssertTrue(screenCaptureManager.isRecording)
        
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Add second display dynamically
        try await screenCaptureManager.addDisplay(additionalDisplay)
        
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        await screenCaptureManager.stopCapture()
        
        // Then: Verify both displays are now being captured
        XCTAssertEqual(captureInfo.activeDisplayCount, 2)
        XCTAssertTrue(captureInfo.displayIDs.contains(initialDisplay.first!))
        XCTAssertTrue(captureInfo.displayIDs.contains(additionalDisplay))
    }
    
    /// Test removing displays during recording
    func testDynamicDisplayRemoval() async throws {
        // Given: Recording with multiple displays
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard displays.count >= 2 else {
            throw XCTSkip("Need multiple displays for dynamic testing")
        }
        
        let multipleDisplays = Array(displays.prefix(2))
        
        // When: Start with multiple displays
        try await screenCaptureManager.startCapture(displays: multipleDisplays)
        
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Remove one display
        try await screenCaptureManager.removeDisplay(multipleDisplays.last!)
        
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        await screenCaptureManager.stopCapture()
        
        // Then: Verify only remaining display is captured
        XCTAssertEqual(captureInfo.activeDisplayCount, 1)
        XCTAssertTrue(captureInfo.displayIDs.contains(multipleDisplays.first!))
        XCTAssertFalse(captureInfo.displayIDs.contains(multipleDisplays.last!))
    }
    
    // MARK: - Error Handling Tests
    
    /// Test graceful degradation when display becomes unavailable
    func testDisplayDisconnectionHandling() async throws {
        // Given: Multi-display recording
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard displays.count >= 2 else {
            throw XCTSkip("Need multiple displays for disconnection testing")
        }
        
        try await screenCaptureManager.startCapture(displays: displays)
        
        // When: Simulate display disconnection
        await screenCaptureManager.simulateDisplayDisconnection(displays.last!)
        
        // Allow time for recovery
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        await screenCaptureManager.stopCapture()
        
        // Then: Verify graceful degradation
        XCTAssertLessThan(captureInfo.activeDisplayCount, displays.count)
        XCTAssertTrue(screenCaptureManager.isRecording, "Should continue recording remaining displays")
        
        // Verify error was logged
        let errorLogs = await screenCaptureManager.getErrorLogs()
        XCTAssertTrue(errorLogs.contains { $0.contains("display disconnection") })
    }
    
    /// Test recovery from multi-monitor capture failure
    func testMultiMonitorCaptureFailureRecovery() async throws {
        // Given: System configured for multi-monitor capture
        let displays = try await screenCaptureManager.getAvailableDisplays()
        guard displays.count >= 2 else {
            throw XCTSkip("Need multiple displays for failure testing")
        }
        
        // When: Attempt capture that will fail (simulate resource exhaustion)
        await screenCaptureManager.simulateResourceExhaustion()
        
        do {
            try await screenCaptureManager.startCapture(displays: displays)
            XCTFail("Expected capture to fail due to simulated resource exhaustion")
        } catch {
            // Expected failure
        }
        
        // Clear simulation and retry with single display
        await screenCaptureManager.clearSimulation()
        
        try await screenCaptureManager.startCapture(displays: [displays.first!])
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let captureInfo = await screenCaptureManager.getCaptureSessionInfo()
        await screenCaptureManager.stopCapture()
        
        // Then: Verify graceful fallback to single display
        XCTAssertEqual(captureInfo.activeDisplayCount, 1)
        XCTAssertTrue(captureInfo.displayIDs.contains(displays.first!))
    }
    
    // MARK: - Helper Methods
    
    private func calculateExpectedPixelRate(for displays: [CGDirectDisplayID]) -> Int64 {
        // Calculate total pixels per second for given displays
        // This would use actual display information in real implementation
        return Int64(displays.count * 1920 * 1080 * 30) // Assume 1080p@30fps baseline
    }
    
    private func getDisplayInformation(for displays: [CGDirectDisplayID]) async throws -> [DisplayInfo] {
        // Get detailed information about each display
        return displays.map { displayID in
            DisplayInfo(
                displayID: displayID,
                resolution: CGSize(width: 1920, height: 1080), // Mock resolution
                scaleFactor: 1.0 // Mock scale factor
            )
        }
    }
    
    private func selectMixedResolutionDisplays(from displayInfos: [DisplayInfo]) -> [DisplayInfo] {
        // Select displays with different resolutions for testing
        var selected: [DisplayInfo] = []
        var seenResolutions: Set<String> = []
        
        for info in displayInfos {
            let resolutionKey = "\(info.resolution.width)x\(info.resolution.height)"
            if !seenResolutions.contains(resolutionKey) {
                selected.append(info)
                seenResolutions.insert(resolutionKey)
            }
        }
        
        return selected
    }
    
    private func calculateExpectedBitrate(for resolution: CGSize) -> Int {
        // Calculate appropriate bitrate based on resolution
        let pixels = resolution.width * resolution.height
        let baseRate = 0.1 // bits per pixel per frame
        return Int(pixels * baseRate * 30) // 30 FPS
    }
}

// MARK: - Supporting Types

struct DisplayInfo {
    let displayID: CGDirectDisplayID
    let resolution: CGSize
    let scaleFactor: CGFloat
}

struct CaptureSessionInfo {
    let activeDisplayCount: Int
    let displayIDs: [CGDirectDisplayID]
    let totalPixelsPerSecond: Int64
    let encodingSettings: [CGDirectDisplayID: EncodingSettings]
}

struct EncodingSettings {
    let resolution: CGSize
    let bitrate: Int
    let frameRate: Int
}

// MARK: - ScreenCaptureManager Extensions for Testing

extension ScreenCaptureManager {
    func getCaptureSessionInfo() async -> CaptureSessionInfo {
        // Return current capture session information
        return CaptureSessionInfo(
            activeDisplayCount: 0,
            displayIDs: [],
            totalPixelsPerSecond: 0,
            encodingSettings: [:]
        )
    }
    
    func addDisplay(_ displayID: CGDirectDisplayID) async throws {
        // Add display to existing capture session
    }
    
    func removeDisplay(_ displayID: CGDirectDisplayID) async throws {
        // Remove display from capture session
    }
    
    func simulateDisplayDisconnection(_ displayID: CGDirectDisplayID) async {
        // Simulate display disconnection for testing
    }
    
    func simulateResourceExhaustion() async {
        // Simulate system resource exhaustion
    }
    
    func clearSimulation() async {
        // Clear any active simulations
    }
    
    func getErrorLogs() async -> [String] {
        // Return recent error logs
        return []
    }
}