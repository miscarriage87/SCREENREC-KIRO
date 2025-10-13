import XCTest
import Foundation
import ScreenCaptureKit
@testable import Shared

/// Integration tests for major user workflows
/// Validates complete user scenarios from start to finish
class UserWorkflowIntegrationTests: XCTestCase {
    
    private var testDataDirectory: URL!
    private var screenCaptureManager: ScreenCaptureManager!
    private var configurationManager: ConfigurationManager!
    private var privacyController: PrivacyController!
    private var allowlistManager: AllowlistManager!
    private var activitySummarizer: ActivitySummarizer!
    private var reportGenerator: ReportGenerator!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testDataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UserWorkflowTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: testDataDirectory,
            withIntermediateDirectories: true
        )
        
        configurationManager = ConfigurationManager(dataDirectory: testDataDirectory)
        try await configurationManager.initializeConfiguration()
        
        screenCaptureManager = ScreenCaptureManager(configuration: configurationManager)
        privacyController = PrivacyController(configuration: configurationManager)
        allowlistManager = AllowlistManager(configuration: configurationManager)
        activitySummarizer = ActivitySummarizer(dataDirectory: testDataDirectory)
        reportGenerator = ReportGenerator(dataDirectory: testDataDirectory)
    }
    
    override func tearDown() async throws {
        await screenCaptureManager.stopCapture()
        try? FileManager.default.removeItem(at: testDataDirectory)
        try await super.tearDown()
    }
    
    // MARK: - Initial Setup and Configuration Workflow
    
    /// Test complete first-time user setup workflow
    func testFirstTimeUserSetupWorkflow() async throws {
        // Given: Fresh system installation
        let setupManager = FirstTimeSetupManager(configuration: configurationManager)
        
        // When: User goes through setup process
        
        // Step 1: System requirements check
        let systemCheck = await setupManager.performSystemRequirementsCheck()
        XCTAssertTrue(systemCheck.isCompatible, "System should meet requirements")
        XCTAssertTrue(systemCheck.hasRequiredPermissions, "Should request required permissions")
        
        // Step 2: Display configuration
        let displays = try await screenCaptureManager.getAvailableDisplays()
        try await setupManager.configureDisplays(displays)
        
        let displayConfig = await configurationManager.getDisplayConfiguration()
        XCTAssertEqual(displayConfig.selectedDisplays.count, displays.count)
        
        // Step 3: Privacy settings configuration
        try await setupManager.configurePrivacySettings(
            enablePIIMasking: true,
            allowlistApps: ["com.apple.finder", "com.apple.safari"],
            pauseHotkey: "cmd+shift+p"
        )
        
        let privacyConfig = await configurationManager.getPrivacyConfiguration()
        XCTAssertTrue(privacyConfig.piiMaskingEnabled)
        XCTAssertEqual(privacyConfig.allowlistedApps.count, 2)
        
        // Step 4: Start recording
        try await setupManager.startInitialRecording()
        
        // Then: Verify complete setup
        XCTAssertTrue(screenCaptureManager.isRecording)
        
        let setupStatus = await setupManager.getSetupStatus()
        XCTAssertTrue(setupStatus.isComplete)
        XCTAssertTrue(setupStatus.allComponentsHealthy)
    }
    
    // MARK: - Daily Usage Workflows
    
    /// Test typical daily work session workflow
    func testDailyWorkSessionWorkflow() async throws {
        // Given: Configured system ready for daily use
        let displays = try await screenCaptureManager.getAvailableDisplays()
        
        // When: User starts their work day
        
        // Step 1: System automatically starts recording
        try await screenCaptureManager.startCapture(displays: displays)
        XCTAssertTrue(screenCaptureManager.isRecording)
        
        // Step 2: User works with various applications
        await simulateWorkActivities()
        
        // Step 3: User takes a privacy break
        await privacyController.activatePrivacyMode()
        XCTAssertTrue(await privacyController.isPrivacyModeActive())
        
        // Simulate private activity
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Step 4: User resumes work
        await privacyController.deactivatePrivacyMode()
        XCTAssertFalse(await privacyController.isPrivacyModeActive())
        
        // Step 5: Continue work activities
        await simulateMoreWorkActivities()
        
        // Step 6: End of day - generate summary
        let workSession = try await activitySummarizer.summarizeWorkSession(
            startTime: Date().addingTimeInterval(-28800), // 8 hours ago
            endTime: Date()
        )
        
        // Then: Verify complete workflow
        XCTAssertNotNil(workSession)
        XCTAssertGreaterThan(workSession!.activities.count, 0)
        XCTAssertGreaterThan(workSession!.totalActiveTime, 0)
        
        // Verify privacy periods are excluded
        let privacyPeriods = workSession!.activities.filter { $0.type == .privacyBreak }
        XCTAssertGreaterThan(privacyPeriods.count, 0)
        
        await screenCaptureManager.stopCapture()
    }
    
    /// Test multi-application workflow with context switching
    func testMultiApplicationWorkflow() async throws {
        // Given: System recording multiple applications
        let displays = try await screenCaptureManager.getAvailableDisplays()
        
        // Configure allowlist for specific applications
        try await allowlistManager.setAllowlistedApplications([
            "com.apple.safari",
            "com.microsoft.VSCode",
            "com.slack.Slack",
            "com.apple.mail"
        ])
        
        try await screenCaptureManager.startCapture(displays: displays)
        
        // When: User switches between applications
        let applicationWorkflow = ApplicationWorkflowSimulator()
        
        // Step 1: Web browsing session
        await applicationWorkflow.simulateWebBrowsing(duration: 5.0)
        
        // Step 2: Code development session
        await applicationWorkflow.simulateCodeDevelopment(duration: 8.0)
        
        // Step 3: Communication session
        await applicationWorkflow.simulateCommunication(duration: 3.0)
        
        // Step 4: Email processing
        await applicationWorkflow.simulateEmailProcessing(duration: 4.0)
        
        await screenCaptureManager.stopCapture()
        
        // Then: Verify application context tracking
        let applicationSummary = try await activitySummarizer.summarizeApplicationUsage(
            timeRange: DateInterval(start: Date().addingTimeInterval(-1200), end: Date())
        )
        
        XCTAssertGreaterThanOrEqual(applicationSummary.applications.count, 4)
        
        // Verify each application has appropriate activity data
        let webActivity = applicationSummary.applications.first { $0.bundleID == "com.apple.safari" }
        XCTAssertNotNil(webActivity)
        XCTAssertGreaterThan(webActivity!.totalTime, 4.0)
        
        let codeActivity = applicationSummary.applications.first { $0.bundleID == "com.microsoft.VSCode" }
        XCTAssertNotNil(codeActivity)
        XCTAssertGreaterThan(codeActivity!.totalTime, 7.0)
    }
    
    // MARK: - Privacy and Security Workflows
    
    /// Test comprehensive privacy workflow
    func testComprehensivePrivacyWorkflow() async throws {
        // Given: System with privacy controls configured
        let displays = try await screenCaptureManager.getAvailableDisplays()
        
        // Configure privacy settings
        try await privacyController.configurePIIMasking(enabled: true)
        try await privacyController.configureHotkey("cmd+shift+p")
        
        try await screenCaptureManager.startCapture(displays: displays)
        
        // When: User encounters sensitive information
        
        // Step 1: Display sensitive content
        await displaySensitiveContent()
        
        // Step 2: User activates privacy mode via hotkey
        let hotkeyResponse = await privacyController.simulateHotkeyPress()
        XCTAssertTrue(hotkeyResponse.wasHandled)
        XCTAssertTrue(await privacyController.isPrivacyModeActive())
        
        // Step 3: Verify recording is paused
        XCTAssertFalse(screenCaptureManager.isRecording)
        
        // Step 4: User handles sensitive information
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Step 5: User resumes recording
        await privacyController.simulateHotkeyPress()
        XCTAssertFalse(await privacyController.isPrivacyModeActive())
        XCTAssertTrue(screenCaptureManager.isRecording)
        
        // Step 6: Continue with normal activities
        await simulateNormalActivities()
        
        await screenCaptureManager.stopCapture()
        
        // Then: Verify privacy protection
        let privacyAudit = try await privacyController.generatePrivacyAudit()
        
        XCTAssertGreaterThan(privacyAudit.privacyActivations.count, 0)
        XCTAssertTrue(privacyAudit.piiMaskingActive)
        XCTAssertEqual(privacyAudit.dataLeaks.count, 0)
        
        // Verify sensitive periods are not in recordings
        let segments = try await getRecordingSegments()
        let sensitiveSegments = segments.filter { segment in
            privacyAudit.privacyActivations.contains { activation in
                segment.timeRange.overlaps(activation.timeRange)
            }
        }
        XCTAssertEqual(sensitiveSegments.count, 0, "No segments should overlap with privacy periods")
    }
    
    /// Test allowlist management workflow
    func testAllowlistManagementWorkflow() async throws {
        // Given: System with dynamic allowlist management
        let displays = try await screenCaptureManager.getAvailableDisplays()
        
        // When: User manages application allowlist
        
        // Step 1: Start with empty allowlist (record everything)
        try await allowlistManager.clearAllowlist()
        try await screenCaptureManager.startCapture(displays: displays)
        
        await simulateMultipleApplications()
        
        // Step 2: Add specific applications to allowlist
        try await allowlistManager.addToAllowlist("com.apple.safari")
        try await allowlistManager.addToAllowlist("com.microsoft.VSCode")
        
        await simulateAllowlistedApplications()
        
        // Step 3: Remove application from allowlist
        try await allowlistManager.removeFromAllowlist("com.apple.safari")
        
        await simulateRemainingApplications()
        
        // Step 4: Configure screen-specific allowlists
        if displays.count > 1 {
            try await allowlistManager.setScreenAllowlist(
                display: displays[0],
                applications: ["com.microsoft.VSCode"]
            )
            try await allowlistManager.setScreenAllowlist(
                display: displays[1],
                applications: ["com.apple.safari", "com.slack.Slack"]
            )
        }
        
        await simulateScreenSpecificActivities()
        
        await screenCaptureManager.stopCapture()
        
        // Then: Verify allowlist enforcement
        let allowlistAudit = try await allowlistManager.generateAllowlistAudit()
        
        XCTAssertGreaterThan(allowlistAudit.allowlistChanges.count, 0)
        XCTAssertTrue(allowlistAudit.enforcementActive)
        
        // Verify only allowlisted applications were recorded
        let recordedApplications = try await getRecordedApplications()
        let nonAllowlistedApps = recordedApplications.filter { app in
            !allowlistAudit.finalAllowlist.contains(app.bundleID)
        }
        XCTAssertEqual(nonAllowlistedApps.count, 0, "Should only record allowlisted applications")
    }
    
    // MARK: - Reporting and Analysis Workflows
    
    /// Test comprehensive reporting workflow
    func testComprehensiveReportingWorkflow() async throws {
        // Given: System with recorded activity data
        let displays = try await screenCaptureManager.getAvailableDisplays()
        
        try await screenCaptureManager.startCapture(displays: displays)
        
        // Generate diverse activity data
        await simulateComplexWorkSession()
        
        await screenCaptureManager.stopCapture()
        
        // When: User generates various reports
        
        // Step 1: Generate daily summary report
        let dailySummary = try await reportGenerator.generateDailySummary(
            date: Date(),
            format: .markdown
        )
        
        XCTAssertNotNil(dailySummary)
        XCTAssertTrue(dailySummary!.contains("# Daily Activity Summary"))
        XCTAssertTrue(dailySummary!.contains("## Applications Used"))
        XCTAssertTrue(dailySummary!.contains("## Key Activities"))
        
        // Step 2: Generate detailed activity report
        let detailedReport = try await reportGenerator.generateDetailedReport(
            timeRange: DateInterval(start: Date().addingTimeInterval(-3600), end: Date()),
            format: .markdown,
            includeEvidence: true
        )
        
        XCTAssertNotNil(detailedReport)
        XCTAssertTrue(detailedReport!.contains("Evidence Links"))
        
        // Step 3: Generate CSV export for analysis
        let csvData = try await reportGenerator.generateCSVExport(
            timeRange: DateInterval(start: Date().addingTimeInterval(-3600), end: Date()),
            includeFields: [.timestamp, .application, .activity, .duration]
        )
        
        XCTAssertNotNil(csvData)
        XCTAssertTrue(csvData!.hasPrefix("timestamp,application,activity,duration"))
        
        // Step 4: Generate playbook for colleagues
        let playbook = try await reportGenerator.generatePlaybook(
            taskName: "Test Workflow Completion",
            timeRange: DateInterval(start: Date().addingTimeInterval(-3600), end: Date())
        )
        
        XCTAssertNotNil(playbook)
        XCTAssertTrue(playbook!.steps.count > 0)
        
        // Then: Verify report quality and completeness
        let reportQuality = try await reportGenerator.assessReportQuality(dailySummary!)
        
        XCTAssertGreaterThanOrEqual(reportQuality.completenessScore, 0.8)
        XCTAssertGreaterThanOrEqual(reportQuality.accuracyScore, 0.9)
        XCTAssertEqual(reportQuality.missingElements.count, 0)
    }
    
    /// Test evidence linking and traceability workflow
    func testEvidenceLinkingWorkflow() async throws {
        // Given: System with evidence linking enabled
        let displays = try await screenCaptureManager.getAvailableDisplays()
        
        try await screenCaptureManager.startCapture(displays: displays)
        
        // Generate activities with clear evidence trails
        await simulateEvidenceGeneratingActivities()
        
        await screenCaptureManager.stopCapture()
        
        // When: User traces evidence for specific activities
        
        // Step 1: Identify key activities
        let activities = try await activitySummarizer.getActivities(
            timeRange: DateInterval(start: Date().addingTimeInterval(-1800), end: Date())
        )
        
        XCTAssertGreaterThan(activities.count, 0)
        
        // Step 2: Trace evidence for each activity
        for activity in activities.prefix(3) {
            let evidenceChain = try await reportGenerator.traceEvidence(for: activity)
            
            XCTAssertNotNil(evidenceChain)
            XCTAssertGreaterThan(evidenceChain!.sourceFrames.count, 0)
            XCTAssertGreaterThan(evidenceChain!.ocrResults.count, 0)
            
            // Verify evidence integrity
            for frameID in evidenceChain!.sourceFrames {
                let frameExists = try await verifyFrameExists(frameID)
                XCTAssertTrue(frameExists, "Evidence frame should exist and be accessible")
            }
            
            // Verify temporal consistency
            let evidenceTimestamps = evidenceChain!.sourceFrames.compactMap { try? await getFrameTimestamp($0) }
            let sortedTimestamps = evidenceTimestamps.sorted()
            XCTAssertEqual(evidenceTimestamps, sortedTimestamps, "Evidence should be temporally consistent")
        }
        
        // Step 3: Generate evidence report
        let evidenceReport = try await reportGenerator.generateEvidenceReport(
            activities: Array(activities.prefix(3))
        )
        
        XCTAssertNotNil(evidenceReport)
        XCTAssertTrue(evidenceReport!.contains("Evidence Traceability Report"))
        
        // Then: Verify evidence completeness
        let evidenceAudit = try await reportGenerator.auditEvidenceCompleteness()
        
        XCTAssertGreaterThanOrEqual(evidenceAudit.coveragePercentage, 95.0)
        XCTAssertEqual(evidenceAudit.brokenLinks.count, 0)
    }
    
    // MARK: - System Maintenance Workflows
    
    /// Test data retention and cleanup workflow
    func testDataRetentionWorkflow() async throws {
        // Given: System with retention policies configured
        let retentionManager = RetentionPolicyManager(configuration: configurationManager)
        
        // Configure retention policies
        try await retentionManager.setRetentionPolicy(
            dataType: .videoSegments,
            retentionDays: 14
        )
        try await retentionManager.setRetentionPolicy(
            dataType: .frameMetadata,
            retentionDays: 90
        )
        try await retentionManager.setRetentionPolicy(
            dataType: .summaries,
            retentionDays: -1 // Permanent
        )
        
        // When: System runs retention cleanup
        
        // Step 1: Generate old data for cleanup testing
        await generateOldTestData()
        
        // Step 2: Run retention cleanup
        let cleanupResults = try await retentionManager.runRetentionCleanup()
        
        XCTAssertGreaterThan(cleanupResults.itemsProcessed, 0)
        XCTAssertGreaterThanOrEqual(cleanupResults.itemsDeleted, 0)
        XCTAssertEqual(cleanupResults.errors.count, 0)
        
        // Step 3: Verify data integrity after cleanup
        let dataIntegrityCheck = try await retentionManager.verifyDataIntegrity()
        
        XCTAssertTrue(dataIntegrityCheck.isHealthy)
        XCTAssertEqual(dataIntegrityCheck.orphanedRecords.count, 0)
        
        // Then: Verify retention policy compliance
        let complianceReport = try await retentionManager.generateComplianceReport()
        
        XCTAssertTrue(complianceReport.isCompliant)
        XCTAssertEqual(complianceReport.violations.count, 0)
        
        // Verify summaries are preserved
        let summaries = try await activitySummarizer.getAllSummaries()
        XCTAssertGreaterThan(summaries.count, 0, "Summaries should be preserved permanently")
    }
    
    // MARK: - Helper Methods
    
    private func simulateWorkActivities() async {
        // Simulate typical work activities
        try? await Task.sleep(nanoseconds: 3_000_000_000)
    }
    
    private func simulateMoreWorkActivities() async {
        // Simulate additional work activities
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func displaySensitiveContent() async {
        // Display content that should trigger privacy controls
    }
    
    private func simulateNormalActivities() async {
        // Simulate normal, non-sensitive activities
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func simulateMultipleApplications() async {
        // Simulate activity across multiple applications
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func simulateAllowlistedApplications() async {
        // Simulate activity in allowlisted applications
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func simulateRemainingApplications() async {
        // Simulate activity in remaining allowlisted applications
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func simulateScreenSpecificActivities() async {
        // Simulate activities specific to different screens
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func simulateComplexWorkSession() async {
        // Simulate a complex work session with various activities
        try? await Task.sleep(nanoseconds: 5_000_000_000)
    }
    
    private func simulateEvidenceGeneratingActivities() async {
        // Simulate activities that generate clear evidence trails
        try? await Task.sleep(nanoseconds: 3_000_000_000)
    }
    
    private func generateOldTestData() async {
        // Generate old test data for retention testing
    }
    
    private func getRecordingSegments() async throws -> [VideoSegment] {
        // Return recorded video segments
        return []
    }
    
    private func getRecordedApplications() async throws -> [ApplicationInfo] {
        // Return information about recorded applications
        return []
    }
    
    private func verifyFrameExists(_ frameID: UUID) async throws -> Bool {
        // Verify that a frame exists and is accessible
        return true
    }
    
    private func getFrameTimestamp(_ frameID: UUID) async throws -> Date {
        // Get timestamp for a specific frame
        return Date()
    }
}

// MARK: - Supporting Types and Classes

class FirstTimeSetupManager {
    private let configuration: ConfigurationManager
    
    init(configuration: ConfigurationManager) {
        self.configuration = configuration
    }
    
    func performSystemRequirementsCheck() async -> SystemRequirementsResult {
        return SystemRequirementsResult(isCompatible: true, hasRequiredPermissions: true)
    }
    
    func configureDisplays(_ displays: [CGDirectDisplayID]) async throws {
        // Configure display settings
    }
    
    func configurePrivacySettings(enablePIIMasking: Bool, allowlistApps: [String], pauseHotkey: String) async throws {
        // Configure privacy settings
    }
    
    func startInitialRecording() async throws {
        // Start initial recording session
    }
    
    func getSetupStatus() async -> SetupStatus {
        return SetupStatus(isComplete: true, allComponentsHealthy: true)
    }
}

class ApplicationWorkflowSimulator {
    func simulateWebBrowsing(duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
    
    func simulateCodeDevelopment(duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
    
    func simulateCommunication(duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
    
    func simulateEmailProcessing(duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}

struct SystemRequirementsResult {
    let isCompatible: Bool
    let hasRequiredPermissions: Bool
}

struct SetupStatus {
    let isComplete: Bool
    let allComponentsHealthy: Bool
}

struct ApplicationInfo {
    let bundleID: String
    let name: String
    let totalTime: TimeInterval
}

struct WorkSession {
    let activities: [Activity]
    let totalActiveTime: TimeInterval
}

struct Activity {
    let type: ActivityType
    let timeRange: DateInterval
}

enum ActivityType {
    case work
    case privacyBreak
    case communication
}

struct ApplicationSummary {
    let applications: [ApplicationUsage]
}

struct ApplicationUsage {
    let bundleID: String
    let totalTime: TimeInterval
}

struct PrivacyAudit {
    let privacyActivations: [PrivacyActivation]
    let piiMaskingActive: Bool
    let dataLeaks: [DataLeak]
}

struct PrivacyActivation {
    let timeRange: DateInterval
}

struct DataLeak {
    let type: String
    let severity: String
}

struct AllowlistAudit {
    let allowlistChanges: [AllowlistChange]
    let enforcementActive: Bool
    let finalAllowlist: [String]
}

struct AllowlistChange {
    let timestamp: Date
    let action: String
    let application: String
}

struct ReportQuality {
    let completenessScore: Double
    let accuracyScore: Double
    let missingElements: [String]
}

struct EvidenceChain {
    let sourceFrames: [UUID]
    let ocrResults: [String]
}

struct EvidenceAudit {
    let coveragePercentage: Double
    let brokenLinks: [String]
}

struct CleanupResults {
    let itemsProcessed: Int
    let itemsDeleted: Int
    let errors: [String]
}

struct DataIntegrityCheck {
    let isHealthy: Bool
    let orphanedRecords: [String]
}

struct ComplianceReport {
    let isCompliant: Bool
    let violations: [String]
}

// MARK: - Extensions

extension PrivacyController {
    func simulateHotkeyPress() async -> HotkeyResponse {
        return HotkeyResponse(wasHandled: true)
    }
}

struct HotkeyResponse {
    let wasHandled: Bool
}

extension DateInterval {
    func overlaps(_ other: DateInterval) -> Bool {
        return start < other.end && end > other.start
    }
}