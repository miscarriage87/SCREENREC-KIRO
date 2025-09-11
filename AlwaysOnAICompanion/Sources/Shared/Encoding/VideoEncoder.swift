import Foundation
import VideoToolbox
import CoreVideo
import AVFoundation

/// Protocol defining the video encoding interface
public protocol VideoEncoderProtocol {
    func startEncoding() async throws
    func stopEncoding() async
    func encode(pixelBuffer: CVPixelBuffer, timestamp: CMTime) async throws
    func finishCurrentSegment() async throws -> URL?
    func startNewSegment(outputURL: URL) async throws
    var isEncoding: Bool { get }
    var performanceMetrics: EncodingPerformanceMetrics { get }
}

/// Performance metrics for encoding operations
public struct EncodingPerformanceMetrics {
    public let cpuUsage: Double
    public let memoryUsage: Int64 // bytes
    public let framesEncoded: Int
    public let droppedFrames: Int
    public let averageEncodingTime: TimeInterval // seconds
    public let currentBitrate: Int
    public let segmentDuration: TimeInterval
    
    public init(cpuUsage: Double = 0.0, memoryUsage: Int64 = 0, framesEncoded: Int = 0, 
                droppedFrames: Int = 0, averageEncodingTime: TimeInterval = 0.0, 
                currentBitrate: Int = 0, segmentDuration: TimeInterval = 0.0) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.framesEncoded = framesEncoded
        self.droppedFrames = droppedFrames
        self.averageEncodingTime = averageEncodingTime
        self.currentBitrate = currentBitrate
        self.segmentDuration = segmentDuration
    }
}

/// Handles H.264 video encoding using VideoToolbox with hardware acceleration
public class VideoEncoder: VideoEncoderProtocol {
    private let configuration: RecorderConfiguration
    private var compressionSession: VTCompressionSession?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var currentOutputURL: URL?
    private var segmentStartTime: CMTime = .zero
    private var lastFrameTime: CMTime = .zero
    
    @Published public private(set) var isEncoding: Bool = false
    @Published public private(set) var performanceMetrics: EncodingPerformanceMetrics = EncodingPerformanceMetrics()
    
    private let encodingQueue = DispatchQueue(label: "com.alwaysonai.encoding", qos: .userInitiated)
    private let logger = Logger.shared
    
    // Performance tracking
    private var framesEncoded: Int = 0
    private var droppedFrames: Int = 0
    private var encodingTimes: [TimeInterval] = []
    private var performanceTimer: Timer?
    
    public init(configuration: RecorderConfiguration) {
        self.configuration = configuration
        startPerformanceMonitoring()
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
    
    public func startEncoding() async throws {
        logger.info("Starting video encoding...")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            encodingQueue.async {
                do {
                    try self.setupCompressionSession()
                    self.isEncoding = true
                    self.resetPerformanceCounters()
                    self.logger.info("Video encoding started successfully")
                    continuation.resume()
                } catch {
                    self.logger.error("Failed to start encoding: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func stopEncoding() async {
        logger.info("Stopping video encoding...")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            encodingQueue.async {
                self.cleanupCompressionSession()
                self.cleanupAssetWriter()
                self.isEncoding = false
                self.logger.info("Video encoding stopped")
                continuation.resume()
            }
        }
    }
    
    public func encode(pixelBuffer: CVPixelBuffer, timestamp: CMTime) async throws {
        guard isEncoding else {
            throw EncodingError.notEncoding
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await withCheckedThrowingContinuation { continuation in
            encodingQueue.async {
                do {
                    try self.encodeFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)
                    
                    // Track performance
                    let encodingTime = CFAbsoluteTimeGetCurrent() - startTime
                    self.encodingTimes.append(encodingTime)
                    self.framesEncoded += 1
                    self.lastFrameTime = timestamp
                    
                    // Keep only recent encoding times for average calculation
                    if self.encodingTimes.count > 100 {
                        self.encodingTimes.removeFirst()
                    }
                    
                    continuation.resume()
                } catch {
                    self.droppedFrames += 1
                    self.logger.warning("Frame encoding failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func finishCurrentSegment() async throws -> URL? {
        guard let outputURL = currentOutputURL else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            encodingQueue.async {
                do {
                    try self.finalizeCurrentSegment()
                    continuation.resume(returning: outputURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    public func startNewSegment(outputURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            encodingQueue.async {
                do {
                    self.currentOutputURL = outputURL
                    try self.setupAssetWriter(outputURL: outputURL)
                    self.segmentStartTime = self.lastFrameTime
                    self.logger.info("Started new segment: \(outputURL.lastPathComponent)")
                    continuation.resume()
                } catch {
                    self.logger.error("Failed to start new segment: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func setupCompressionSession() throws {
        let width = configuration.captureWidth
        let height = configuration.captureHeight
        
        // Create compression session
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &compressionSession
        )
        
        guard status == noErr, let session = compressionSession else {
            throw EncodingError.compressionSessionCreationFailed
        }
        
        // Configure compression properties
        try setCompressionProperties(session: session)
        
        // Prepare to encode
        VTCompressionSessionPrepareToEncodeFrames(session)
    }
    
    private func setCompressionProperties(session: VTCompressionSession) throws {
        var status: OSStatus
        
        // Set pixel format to yuv420p (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_PixelTransferProperties,
            value: pixelBufferAttributes as CFDictionary
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("PixelFormat")
        }
        
        // Set bitrate (2-4 Mbps per display)
        let bitrate = configuration.targetBitrate
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AverageBitRate,
            value: bitrate as CFNumber
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("Bitrate")
        }
        
        // Set data rate limits for consistent quality
        let dataRateLimits = [bitrate * 2, 1] as CFArray // Max bitrate, duration in seconds
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_DataRateLimits,
            value: dataRateLimits
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("DataRateLimits")
        }
        
        // Set frame rate
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_ExpectedFrameRate,
            value: configuration.frameRate as CFNumber
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("FrameRate")
        }
        
        // Set keyframe interval (every 2 seconds for optimal seeking)
        let keyframeInterval = Int(configuration.frameRate * 2)
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
            value: keyframeInterval as CFNumber
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("KeyframeInterval")
        }
        
        // Enable real-time encoding for low latency
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("RealTime")
        }
        
        // Set profile level for optimal compatibility and performance
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_ProfileLevel,
            value: kVTProfileLevel_H264_High_AutoLevel
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("ProfileLevel")
        }
        
        // Enable hardware acceleration (optional - may not be available in test environments)
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder,
            value: kCFBooleanTrue
        )
        if status != noErr {
            logger.warning("Hardware acceleration not available, falling back to software encoding")
        }
        
        // Set entropy mode for better compression
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_H264EntropyMode,
            value: kVTH264EntropyMode_CABAC
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("EntropyMode")
        }
        
        // Optimize for quality vs speed balance
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_Quality,
            value: 0.7 as CFNumber // 0.0 (speed) to 1.0 (quality)
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("Quality")
        }
        
        // Allow frame reordering for better compression
        status = VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AllowFrameReordering,
            value: kCFBooleanTrue
        )
        guard status == noErr else {
            throw EncodingError.propertySetFailed("FrameReordering")
        }
    }
    
    private func setupAssetWriter(outputURL: URL) throws {
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Configure video settings for H.264 with faststart
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: configuration.captureWidth,
            AVVideoHeightKey: configuration.captureHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.targetBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate
            ]
        ]
        
        // Create asset writer input
        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        assetWriterInput?.expectsMediaDataInRealTime = true
        
        // Create pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferWidthKey as String: configuration.captureWidth,
            kCVPixelBufferHeightKey as String: configuration.captureHeight
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        // Add input to writer
        guard let writer = assetWriter, let input = assetWriterInput else {
            throw EncodingError.assetWriterSetupFailed
        }
        
        if writer.canAdd(input) {
            writer.add(input)
        } else {
            throw EncodingError.assetWriterSetupFailed
        }
        
        // Start writing
        guard writer.startWriting() else {
            throw EncodingError.assetWriterStartFailed
        }
        
        writer.startSession(atSourceTime: .zero)
    }
    
    private func encodeFrame(pixelBuffer: CVPixelBuffer, timestamp: CMTime) throws {
        guard let adaptor = pixelBufferAdaptor,
              let input = assetWriterInput,
              input.isReadyForMoreMediaData else {
            return // Skip frame if not ready
        }
        
        let success = adaptor.append(pixelBuffer, withPresentationTime: timestamp)
        if !success {
            throw EncodingError.frameEncodingFailed
        }
    }
    
    private func finalizeCurrentSegment() throws {
        guard let writer = assetWriter,
              let input = assetWriterInput else {
            return
        }
        
        // Calculate actual segment duration
        let segmentDuration = CMTimeGetSeconds(CMTimeSubtract(lastFrameTime, segmentStartTime))
        logger.info("Finalizing segment with duration: \(segmentDuration) seconds")
        
        // Mark input as finished
        input.markAsFinished()
        
        // Finish writing
        let semaphore = DispatchSemaphore(value: 0)
        var finishError: Error?
        
        writer.finishWriting {
            if writer.status == .failed {
                finishError = writer.error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = finishError {
            throw error
        }
        
        // Enable faststart for immediate playbook
        if let outputURL = currentOutputURL {
            try enableFastStart(for: outputURL)
            logger.info("Segment finalized with faststart enabled: \(outputURL.lastPathComponent)")
        }
        
        // Clean up for next segment
        cleanupAssetWriter()
    }
    
    private func enableFastStart(for url: URL) throws {
        // Use AVAssetExportSession to enable faststart
        let asset = AVAsset(url: url)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        
        let tempURL = url.appendingPathExtension("tmp")
        exportSession?.outputURL = tempURL
        exportSession?.outputFileType = .mp4
        exportSession?.shouldOptimizeForNetworkUse = true // This enables faststart
        
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        
        exportSession?.exportAsynchronously {
            if exportSession?.status == .failed {
                exportError = exportSession?.error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = exportError {
            throw error
        }
        
        // Replace original with optimized version
        _ = try FileManager.default.replaceItem(at: url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
    }
    
    private func cleanupCompressionSession() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }
    
    private func cleanupAssetWriter() {
        assetWriter = nil
        assetWriterInput = nil
        pixelBufferAdaptor = nil
        currentOutputURL = nil
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()
        let averageEncodingTime = encodingTimes.isEmpty ? 0.0 : encodingTimes.reduce(0, +) / Double(encodingTimes.count)
        let segmentDuration = CMTimeGetSeconds(CMTimeSubtract(lastFrameTime, segmentStartTime))
        
        let currentBitrate = calculateCurrentBitrate()
        
        performanceMetrics = EncodingPerformanceMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            framesEncoded: framesEncoded,
            droppedFrames: droppedFrames,
            averageEncodingTime: averageEncodingTime,
            currentBitrate: currentBitrate,
            segmentDuration: segmentDuration
        )
        
        // Log warning if CPU usage exceeds target
        if cpuUsage > configuration.maxCPUUsage {
            logger.warning("CPU usage (\(cpuUsage)%) exceeds target (\(configuration.maxCPUUsage)%)")
        }
    }
    
    private func resetPerformanceCounters() {
        framesEncoded = 0
        droppedFrames = 0
        encodingTimes.removeAll()
        segmentStartTime = .zero
        lastFrameTime = .zero
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // Convert to percentage (this is a simplified calculation)
            return Double(info.user_time.seconds + info.system_time.seconds) * 100.0 / Double(ProcessInfo.processInfo.systemUptime)
        }
        
        return 0.0
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        
        return 0
    }
    
    private func calculateCurrentBitrate() -> Int {
        // Estimate current bitrate based on recent frame encoding
        guard !encodingTimes.isEmpty, framesEncoded > 0 else { return 0 }
        
        let totalTime = encodingTimes.reduce(0, +)
        let estimatedBytesPerFrame = configuration.targetBitrate / (8 * configuration.frameRate) // Convert bits to bytes
        let estimatedBitrate = Int(Double(estimatedBytesPerFrame * framesEncoded * 8) / totalTime)
        
        return estimatedBitrate
    }
    
    // MARK: - Segment Duration Management
    
    public func shouldCreateNewSegment() -> Bool {
        let currentDuration = CMTimeGetSeconds(CMTimeSubtract(lastFrameTime, segmentStartTime))
        return currentDuration >= configuration.segmentDuration
    }
}

// MARK: - Error Types
public enum EncodingError: Error {
    case notEncoding
    case compressionSessionCreationFailed
    case propertySetFailed(String)
    case assetWriterSetupFailed
    case assetWriterStartFailed
    case frameEncodingFailed
    
    public var localizedDescription: String {
        switch self {
        case .notEncoding:
            return "Encoder is not currently encoding"
        case .compressionSessionCreationFailed:
            return "Failed to create compression session"
        case .propertySetFailed(let property):
            return "Failed to set property: \(property)"
        case .assetWriterSetupFailed:
            return "Failed to setup asset writer"
        case .assetWriterStartFailed:
            return "Failed to start asset writer"
        case .frameEncodingFailed:
            return "Failed to encode frame"
        }
    }
}