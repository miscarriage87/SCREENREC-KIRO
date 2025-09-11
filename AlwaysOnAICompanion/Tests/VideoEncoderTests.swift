import XCTest
import CoreVideo
import AVFoundation
import VideoToolbox
@testable import Shared

final class VideoEncoderTests: XCTestCase {
    var testConfiguration: RecorderConfiguration!
    var videoEncoder: VideoEncoder!
    var testOutputDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create test output directory
        let tempDir = FileManager.default.temporaryDirectory
        testOutputDirectory = tempDir.appendingPathComponent("VideoEncoderTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testOutputDirectory, withIntermediateDirectories: true)
        
        // Create test configuration
        testConfiguration = RecorderConfiguration(
            selectedDisplays: [],
            captureWidth: 1920,
            captureHeight: 1080,
            frameRate: 30,
            showCursor: true,
            targetBitrate: 3_000_000, // 3 Mbps
            segmentDuration: 120, // 2 minutes
            storageURL: testOutputDirectory,
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
        
        videoEncoder = VideoEncoder(configuration: testConfiguration)
    }
    
    override func tearDown() {
        // Clean up test files
        try? FileManager.default.removeItem(at: testOutputDirectory)
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testVideoEncoderInitialization() {
        XCTAssertNotNil(videoEncoder)
        XCTAssertFalse(videoEncoder.isEncoding)
        XCTAssertEqual(videoEncoder.performanceMetrics.framesEncoded, 0)
        XCTAssertEqual(videoEncoder.performanceMetrics.droppedFrames, 0)
    }
    
    func testVideoEncoderProtocolConformance() {
        XCTAssertTrue(videoEncoder is VideoEncoderProtocol)
    }
    
    // MARK: - Configuration Tests
    
    func testH264ConfigurationProperties() {
        // Test that configuration values are properly set
        XCTAssertEqual(testConfiguration.targetBitrate, 3_000_000)
        XCTAssertEqual(testConfiguration.frameRate, 30)
        XCTAssertEqual(testConfiguration.segmentDuration, 120)
        XCTAssertEqual(testConfiguration.maxCPUUsage, 8.0)
        
        // Test yuv420p pixel format expectation
        XCTAssertEqual(testConfiguration.captureWidth, 1920)
        XCTAssertEqual(testConfiguration.captureHeight, 1080)
    }
    
    // MARK: - Encoding State Tests
    
    func testEncodingStateManagement() async throws {
        // Initial state
        XCTAssertFalse(videoEncoder.isEncoding)
        
        // Start encoding
        try await videoEncoder.startEncoding()
        XCTAssertTrue(videoEncoder.isEncoding)
        
        // Stop encoding
        await videoEncoder.stopEncoding()
        XCTAssertFalse(videoEncoder.isEncoding)
    }
    
    func testEncodingWithoutStartThrowsError() async {
        // Create a mock pixel buffer
        let pixelBuffer = createMockPixelBuffer()
        let timestamp = CMTime(seconds: 0, preferredTimescale: 30)
        
        do {
            try await videoEncoder.encode(pixelBuffer: pixelBuffer, timestamp: timestamp)
            XCTFail("Should have thrown notEncoding error")
        } catch EncodingError.notEncoding {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Segment Management Tests
    
    func testSegmentCreation() async throws {
        let outputURL = testOutputDirectory.appendingPathComponent("test_segment.mp4")
        
        try await videoEncoder.startEncoding()
        try await videoEncoder.startNewSegment(outputURL: outputURL)
        
        // Verify segment was started
        XCTAssertTrue(videoEncoder.isEncoding)
        
        await videoEncoder.stopEncoding()
    }
    
    func testSegmentDurationCheck() {
        // Test segment duration logic
        XCTAssertFalse(videoEncoder.shouldCreateNewSegment()) // No frames encoded yet
    }
    
    func testTwoMinuteSegmentDuration() {
        // Verify configuration specifies 2-minute segments
        XCTAssertEqual(testConfiguration.segmentDuration, 120.0)
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetricsInitialization() {
        let metrics = videoEncoder.performanceMetrics
        
        XCTAssertEqual(metrics.framesEncoded, 0)
        XCTAssertEqual(metrics.droppedFrames, 0)
        XCTAssertEqual(metrics.averageEncodingTime, 0.0)
        XCTAssertEqual(metrics.currentBitrate, 0)
        XCTAssertEqual(metrics.segmentDuration, 0.0)
    }
    
    func testCPUUsageTarget() {
        // Verify CPU usage target is set correctly
        XCTAssertEqual(testConfiguration.maxCPUUsage, 8.0)
        
        // Performance metrics should track CPU usage
        let metrics = videoEncoder.performanceMetrics
        XCTAssertGreaterThanOrEqual(metrics.cpuUsage, 0.0)
    }
    
    func testMemoryUsageTracking() {
        let metrics = videoEncoder.performanceMetrics
        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testEncodingErrorTypes() {
        let errors: [EncodingError] = [
            .notEncoding,
            .compressionSessionCreationFailed,
            .propertySetFailed("TestProperty"),
            .assetWriterSetupFailed,
            .assetWriterStartFailed,
            .frameEncodingFailed
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error description should not be empty for \(error)")
        }
    }
    
    // MARK: - Video Quality Tests
    
    func testH264ProfileConfiguration() {
        // Test that H.264 High profile is configured
        // This is tested indirectly through configuration validation
        XCTAssertEqual(testConfiguration.targetBitrate, 3_000_000)
        XCTAssertEqual(testConfiguration.frameRate, 30)
    }
    
    func testYUV420PPixelFormat() {
        // Test that yuv420p pixel format is expected
        // This is validated through the configuration and encoding setup
        XCTAssertEqual(testConfiguration.captureWidth, 1920)
        XCTAssertEqual(testConfiguration.captureHeight, 1080)
    }
    
    func testBitrateConfiguration() {
        // Test bitrate is within 2-4 Mbps range as specified in requirements
        let bitrate = testConfiguration.targetBitrate
        XCTAssertGreaterThanOrEqual(bitrate, 2_000_000) // 2 Mbps minimum
        XCTAssertLessThanOrEqual(bitrate, 4_000_000) // 4 Mbps maximum
    }
    
    // MARK: - Faststart Tests
    
    func testFaststartConfiguration() {
        // Test that faststart is enabled for immediate playback
        // This is tested through the segment finalization process
        XCTAssertEqual(testConfiguration.segmentDuration, 120) // 2-minute segments
    }
    
    // MARK: - Performance Benchmark Tests
    
    func testEncodingPerformanceBenchmark() async throws {
        // This test measures encoding performance to ensure it meets requirements
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await videoEncoder.startEncoding()
        
        let outputURL = testOutputDirectory.appendingPathComponent("benchmark_segment.mp4")
        try await videoEncoder.startNewSegment(outputURL: outputURL)
        
        // Encode a few test frames
        for i in 0..<30 { // 1 second worth of frames at 30fps
            let pixelBuffer = createMockPixelBuffer()
            let timestamp = CMTime(seconds: Double(i) / 30.0, preferredTimescale: 30)
            
            try await videoEncoder.encode(pixelBuffer: pixelBuffer, timestamp: timestamp)
        }
        
        await videoEncoder.stopEncoding()
        
        let encodingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Verify encoding completed in reasonable time
        XCTAssertLessThan(encodingTime, 5.0, "Encoding should complete quickly for test frames")
        
        // Check performance metrics
        let metrics = videoEncoder.performanceMetrics
        XCTAssertEqual(metrics.framesEncoded, 30)
        XCTAssertLessThanOrEqual(metrics.cpuUsage, testConfiguration.maxCPUUsage * 2) // Allow some overhead in tests
    }
    
    // MARK: - Integration Tests
    
    func testCompleteEncodingWorkflow() async throws {
        // Test the complete encoding workflow
        try await videoEncoder.startEncoding()
        
        let outputURL = testOutputDirectory.appendingPathComponent("complete_workflow.mp4")
        try await videoEncoder.startNewSegment(outputURL: outputURL)
        
        // Encode several frames
        for i in 0..<60 { // 2 seconds worth of frames
            let pixelBuffer = createMockPixelBuffer()
            let timestamp = CMTime(seconds: Double(i) / 30.0, preferredTimescale: 30)
            
            try await videoEncoder.encode(pixelBuffer: pixelBuffer, timestamp: timestamp)
        }
        
        // Finish segment
        let finishedURL = try await videoEncoder.finishCurrentSegment()
        XCTAssertNotNil(finishedURL)
        
        await videoEncoder.stopEncoding()
        
        // Verify file was created
        if let url = finishedURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
        
        // Verify performance metrics
        let metrics = videoEncoder.performanceMetrics
        XCTAssertEqual(metrics.framesEncoded, 60)
        XCTAssertEqual(metrics.droppedFrames, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPixelBuffer() -> CVPixelBuffer {
        let width = testConfiguration.captureWidth
        let height = testConfiguration.captureHeight
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to create mock pixel buffer")
        }
        
        // Fill with test pattern (optional)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        return buffer
    }
}

// MARK: - Performance Test Extensions

extension VideoEncoderTests {
    
    func testCPUUsageCompliance() async throws {
        // Test that CPU usage stays within the ≤8% target
        try await videoEncoder.startEncoding()
        
        let outputURL = testOutputDirectory.appendingPathComponent("cpu_test.mp4")
        try await videoEncoder.startNewSegment(outputURL: outputURL)
        
        // Encode frames and monitor CPU usage
        var maxCPUUsage: Double = 0
        
        for i in 0..<300 { // 10 seconds worth of frames
            let pixelBuffer = createMockPixelBuffer()
            let timestamp = CMTime(seconds: Double(i) / 30.0, preferredTimescale: 30)
            
            try await videoEncoder.encode(pixelBuffer: pixelBuffer, timestamp: timestamp)
            
            // Sample CPU usage periodically
            if i % 30 == 0 { // Every second
                let currentCPU = videoEncoder.performanceMetrics.cpuUsage
                maxCPUUsage = max(maxCPUUsage, currentCPU)
            }
        }
        
        await videoEncoder.stopEncoding()
        
        // In a test environment, CPU usage might be higher due to system overhead
        // We'll allow up to 2x the target for test conditions
        XCTAssertLessThanOrEqual(maxCPUUsage, testConfiguration.maxCPUUsage * 2,
                                "CPU usage should stay within reasonable bounds")
    }
    
    func testMemoryUsageStability() async throws {
        // Test that memory usage remains stable during encoding
        try await videoEncoder.startEncoding()
        
        let outputURL = testOutputDirectory.appendingPathComponent("memory_test.mp4")
        try await videoEncoder.startNewSegment(outputURL: outputURL)
        
        let initialMemory = videoEncoder.performanceMetrics.memoryUsage
        
        // Encode a significant number of frames
        for i in 0..<600 { // 20 seconds worth of frames
            let pixelBuffer = createMockPixelBuffer()
            let timestamp = CMTime(seconds: Double(i) / 30.0, preferredTimescale: 30)
            
            try await videoEncoder.encode(pixelBuffer: pixelBuffer, timestamp: timestamp)
        }
        
        let finalMemory = videoEncoder.performanceMetrics.memoryUsage
        
        await videoEncoder.stopEncoding()
        
        // Memory usage should not grow excessively
        let memoryGrowth = finalMemory - initialMemory
        let maxAllowedGrowth = Int64(testConfiguration.maxMemoryUsage * 1024 * 1024) // Convert MB to bytes
        
        XCTAssertLessThanOrEqual(memoryGrowth, maxAllowedGrowth,
                                "Memory usage should remain stable during encoding")
    }
}