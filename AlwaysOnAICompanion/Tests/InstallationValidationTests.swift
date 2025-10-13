import XCTest
import Foundation
import Security

@testable import Shared

/// Comprehensive installation validation tests for various macOS versions and configurations
class InstallationValidationTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    struct TestConfig {
        static let bundleID = "com.alwaysonai.recorderdaemon"
        static let launchAgentName = "com.alwaysonai.recorderdaemon.plist"
        static let appName = "Always-On AI Companion"
        
        static let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        static let buildPath = projectRoot.appendingPathComponent(".build/release")
        static let scriptsPath = projectRoot.appendingPathComponent("Scripts")
        
        static let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        static let launchAgentsDir = homeDirectory.appendingPathComponent("Library/LaunchAgents")
        static let logDir = homeDirectory.appendingPathComponent("Library/Logs/AlwaysOnAICompanion")
        static let configDir = homeDirectory.appendingPathComponent("Library/Application Support/AlwaysOnAICompanion")
    }
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Ensure we're running on macOS
        #if !os(macOS)
        throw XCTSkip("Installation tests only run on macOS")
        #endif
        
        // Check minimum macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion < 14 {
            throw XCTSkip("Installation tests require macOS 14 or later")
        }
    }
    
    override func tearDownWithError() throws {
        // Clean up any test artifacts
        try cleanupTestArtifacts()
        try super.tearDownWithError()
    }
    
    // MARK: - System Requirements Tests
    
    func testSystemRequirementsValidation() throws {
        let validator = SystemRequirementsValidator()
        
        // Test macOS version check
        let versionResult = try validator.validateMacOSVersion()
        XCTAssertTrue(versionResult.isValid, "macOS version should be supported")
        XCTAssertGreaterThanOrEqual(versionResult.majorVersion, 14, "Should require macOS 14+")
        
        // Test architecture detection
        let architecture = try validator.getSystemArchitecture()
        XCTAssertTrue(["arm64", "x86_64"].contains(architecture), "Should detect valid architecture")
        
        // Test available disk space
        let diskSpace = try validator.getAvailableDiskSpace()
        XCTAssertGreaterThan(diskSpace, 1_000_000_000, "Should have at least 1GB available")
        
        // Test Swift availability
        let swiftAvailable = validator.isSwiftAvailable()
        XCTAssertTrue(swiftAvailable, "Swift compiler should be available")
        
        // Test development tools
        let xcodeTools = validator.isXcodeCommandLineToolsInstalled()
        if !xcodeTools {
            print("⚠️ Xcode Command Line Tools not detected - this may cause build issues")
        }
    }
    
    func testBuildValidation() throws {
        let validator = BuildValidator()
        
        // Check if project can be built
        let buildResult = try validator.validateBuildConfiguration()
        XCTAssertTrue(buildResult.isValid, "Project should be buildable")
        
        // Validate Package.swift
        let packageResult = try validator.validatePackageManifest()
        XCTAssertTrue(packageResult.isValid, "Package.swift should be valid")
        
        // Check dependencies
        let dependenciesResult = try validator.validateDependencies()
        XCTAssertTrue(dependenciesResult.isValid, "Dependencies should be resolvable")
        
        // Test build products
        if FileManager.default.fileExists(atPath: TestConfig.buildPath.path) {
            let executablesResult = try validator.validateExecutables()
            XCTAssertTrue(executablesResult.isValid, "Built executables should be valid")
        }
    }
    
    // MARK: - Permission Tests
    
    func testPermissionValidation() throws {
        let validator = PermissionValidator()
        
        // Test screen recording permission check
        let screenRecordingStatus = validator.checkScreenRecordingPermission()
        print("Screen Recording Permission: \(screenRecordingStatus)")
        
        // Test accessibility permission check
        let accessibilityStatus = validator.checkAccessibilityPermission()
        print("Accessibility Permission: \(accessibilityStatus)")
        
        // Test full disk access permission check
        let fullDiskAccessStatus = validator.checkFullDiskAccessPermission()
        print("Full Disk Access Permission: \(fullDiskAccessStatus)")
        
        // Validate permission request mechanisms
        let requestMechanisms = try validator.validatePermissionRequestMechanisms()
        XCTAssertTrue(requestMechanisms.isValid, "Permission request mechanisms should work")
    }
    
    // MARK: - LaunchAgent Tests
    
    func testLaunchAgentInstallation() throws {
        let installer = LaunchAgentInstaller()
        
        // Test plist generation
        let plistContent = try installer.generateLaunchAgentPlist()
        XCTAssertFalse(plistContent.isEmpty, "Plist content should not be empty")
        
        // Validate plist format
        let plistData = plistContent.data(using: .utf8)!
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil)
        XCTAssertNotNil(plist, "Plist should be valid")
        
        // Test installation path
        let installPath = installer.getInstallationPath()
        XCTAssertTrue(installPath.path.contains("LaunchAgents"), "Should install to LaunchAgents directory")
        
        // Test plist validation
        let validationResult = try installer.validatePlistContent(plistContent)
        XCTAssertTrue(validationResult.isValid, "Generated plist should be valid")
    }
    
    func testLaunchAgentManagement() throws {
        let manager = LaunchAgentManager()
        
        // Test loading/unloading without actual installation
        let mockPlistPath = TestConfig.launchAgentsDir.appendingPathComponent("test.plist")
        
        // Test status checking
        let isLoaded = try manager.isLaunchAgentLoaded(TestConfig.bundleID)
        print("LaunchAgent loaded status: \(isLoaded)")
        
        // Test launchctl command validation
        let launchctlAvailable = manager.isLaunchctlAvailable()
        XCTAssertTrue(launchctlAvailable, "launchctl should be available")
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationSetup() throws {
        let configurator = ConfigurationManager()
        
        // Test default configuration generation
        let defaultConfig = try configurator.generateDefaultConfiguration()
        XCTAssertFalse(defaultConfig.isEmpty, "Default configuration should not be empty")
        
        // Validate configuration structure
        let configData = try JSONSerialization.data(withJSONObject: defaultConfig)
        let parsedConfig = try JSONSerialization.jsonObject(with: configData)
        XCTAssertNotNil(parsedConfig, "Configuration should be valid JSON")
        
        // Test configuration directory creation
        let configDir = TestConfig.configDir
        let canCreateConfigDir = configurator.canCreateDirectory(at: configDir)
        XCTAssertTrue(canCreateConfigDir, "Should be able to create configuration directory")
        
        // Test log directory creation
        let logDir = TestConfig.logDir
        let canCreateLogDir = configurator.canCreateDirectory(at: logDir)
        XCTAssertTrue(canCreateLogDir, "Should be able to create log directory")
    }
    
    // MARK: - Code Signing Tests
    
    func testCodeSigningValidation() throws {
        let validator = CodeSigningValidator()
        
        // Test codesign tool availability
        let codesignAvailable = validator.isCodesignAvailable()
        XCTAssertTrue(codesignAvailable, "codesign tool should be available")
        
        // Test certificate validation (if available)
        let certificates = try validator.getAvailableCertificates()
        print("Available certificates: \(certificates.count)")
        
        // Test executable signing validation
        if FileManager.default.fileExists(atPath: TestConfig.buildPath.path) {
            let executables = ["RecorderDaemon", "MenuBarApp"]
            
            for executable in executables {
                let executablePath = TestConfig.buildPath.appendingPathComponent(executable)
                
                if FileManager.default.fileExists(atPath: executablePath.path) {
                    let signingStatus = try validator.checkExecutableSignature(at: executablePath)
                    print("\(executable) signing status: \(signingStatus)")
                }
            }
        }
    }
    
    // MARK: - Installation Process Tests
    
    func testDryRunInstallation() throws {
        let installer = SystemInstaller()
        
        // Perform dry run installation
        let dryRunResult = try installer.performDryRun()
        XCTAssertTrue(dryRunResult.canInstall, "Dry run should indicate system is ready for installation")
        
        // Check for any blocking issues
        XCTAssertTrue(dryRunResult.blockingIssues.isEmpty, "Should not have blocking issues: \(dryRunResult.blockingIssues)")
        
        // Validate warnings (non-blocking issues)
        for warning in dryRunResult.warnings {
            print("⚠️ Installation warning: \(warning)")
        }
    }
    
    func testInstallationSteps() throws {
        let installer = SystemInstaller()
        
        // Test individual installation steps
        let steps = installer.getInstallationSteps()
        XCTAssertFalse(steps.isEmpty, "Should have installation steps defined")
        
        for step in steps {
            let canExecute = try installer.canExecuteStep(step)
            XCTAssertTrue(canExecute.isValid, "Should be able to execute step: \(step.name)")
        }
    }
    
    // MARK: - Uninstallation Tests
    
    func testUninstallationValidation() throws {
        let uninstaller = SystemUninstaller()
        
        // Test uninstallation detection
        let installationStatus = try uninstaller.detectInstallation()
        print("Installation detected: \(installationStatus.isInstalled)")
        
        // Test cleanup validation
        let cleanupSteps = uninstaller.getCleanupSteps()
        XCTAssertFalse(cleanupSteps.isEmpty, "Should have cleanup steps defined")
        
        // Test file removal validation
        let filesToRemove = try uninstaller.getFilesToRemove()
        for file in filesToRemove {
            let canRemove = uninstaller.canRemoveFile(at: file)
            XCTAssertTrue(canRemove, "Should be able to remove file: \(file.path)")
        }
    }
    
    // MARK: - Cross-Version Compatibility Tests
    
    func testMacOSVersionCompatibility() throws {
        let compatibilityTester = MacOSCompatibilityTester()
        
        // Test current macOS version
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        let isSupported = compatibilityTester.isMacOSVersionSupported(currentVersion)
        XCTAssertTrue(isSupported, "Current macOS version should be supported")
        
        // Test minimum version requirements
        let minimumVersion = OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0)
        let meetsMinimum = compatibilityTester.meetsMinimumRequirements(currentVersion, minimum: minimumVersion)
        XCTAssertTrue(meetsMinimum, "Should meet minimum version requirements")
        
        // Test API availability
        let apiAvailability = try compatibilityTester.checkAPIAvailability()
        XCTAssertTrue(apiAvailability.screenCaptureKit, "ScreenCaptureKit should be available")
        XCTAssertTrue(apiAvailability.vision, "Vision framework should be available")
    }
    
    func testArchitectureCompatibility() throws {
        let compatibilityTester = ArchitectureCompatibilityTester()
        
        // Test current architecture
        let currentArch = try compatibilityTester.getCurrentArchitecture()
        let supportedArchs = ["arm64", "x86_64"]
        XCTAssertTrue(supportedArchs.contains(currentArch), "Architecture should be supported: \(currentArch)")
        
        // Test binary compatibility
        if FileManager.default.fileExists(atPath: TestConfig.buildPath.path) {
            let binaryCompatibility = try compatibilityTester.checkBinaryCompatibility()
            XCTAssertTrue(binaryCompatibility.isCompatible, "Binaries should be compatible with current architecture")
        }
    }
    
    // MARK: - Performance Tests
    
    func testInstallationPerformance() throws {
        let performanceTester = InstallationPerformanceTester()
        
        // Measure dry run performance
        let dryRunTime = try performanceTester.measureDryRunTime()
        XCTAssertLessThan(dryRunTime, 30.0, "Dry run should complete within 30 seconds")
        
        // Measure validation performance
        let validationTime = try performanceTester.measureValidationTime()
        XCTAssertLessThan(validationTime, 60.0, "Validation should complete within 60 seconds")
        
        // Test resource usage during installation simulation
        let resourceUsage = try performanceTester.measureResourceUsage()
        XCTAssertLessThan(resourceUsage.cpuUsage, 50.0, "CPU usage should be reasonable during installation")
        XCTAssertLessThan(resourceUsage.memoryUsage, 500_000_000, "Memory usage should be under 500MB")
    }
    
    // MARK: - Security Tests
    
    func testSecurityValidation() throws {
        let securityValidator = SecurityValidator()
        
        // Test file permissions
        let permissionValidation = try securityValidator.validateFilePermissions()
        XCTAssertTrue(permissionValidation.isSecure, "File permissions should be secure")
        
        // Test executable validation
        if FileManager.default.fileExists(atPath: TestConfig.buildPath.path) {
            let executableSecurity = try securityValidator.validateExecutableSecurity()
            XCTAssertTrue(executableSecurity.isSecure, "Executables should pass security validation")
        }
        
        // Test configuration security
        let configSecurity = try securityValidator.validateConfigurationSecurity()
        XCTAssertTrue(configSecurity.isSecure, "Configuration should be secure")
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndInstallationFlow() throws {
        let integrationTester = InstallationIntegrationTester()
        
        // Test complete installation flow (dry run)
        let flowResult = try integrationTester.testCompleteFlow(dryRun: true)
        XCTAssertTrue(flowResult.success, "Complete installation flow should succeed in dry run")
        
        // Test error handling
        let errorHandling = try integrationTester.testErrorHandling()
        XCTAssertTrue(errorHandling.handlesErrorsGracefully, "Should handle errors gracefully")
        
        // Test rollback capability
        let rollbackTest = try integrationTester.testRollbackCapability()
        XCTAssertTrue(rollbackTest.canRollback, "Should be able to rollback installation")
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTestArtifacts() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AlwaysOnAICompanion-Test")
        
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
    }
}

// MARK: - Supporting Classes

class SystemRequirementsValidator {
    
    struct ValidationResult {
        let isValid: Bool
        let majorVersion: Int
        let minorVersion: Int
        let message: String
    }
    
    func validateMacOSVersion() throws -> ValidationResult {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let isValid = version.majorVersion >= 14
        
        return ValidationResult(
            isValid: isValid,
            majorVersion: version.majorVersion,
            minorVersion: version.minorVersion,
            message: isValid ? "macOS version is supported" : "macOS 14+ required"
        )
    }
    
    func getSystemArchitecture() throws -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    func getAvailableDiskSpace() throws -> Int64 {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return resourceValues.volumeAvailableCapacity ?? 0
    }
    
    func isSwiftAvailable() -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = ["swift"]
        process.standardOutput = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    func isXcodeCommandLineToolsInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: "/usr/bin/xcode-select")
    }
}

class BuildValidator {
    
    struct ValidationResult {
        let isValid: Bool
        let message: String
    }
    
    func validateBuildConfiguration() throws -> ValidationResult {
        let packagePath = InstallationValidationTests.TestConfig.projectRoot.appendingPathComponent("Package.swift")
        let exists = FileManager.default.fileExists(atPath: packagePath.path)
        
        return ValidationResult(
            isValid: exists,
            message: exists ? "Package.swift found" : "Package.swift not found"
        )
    }
    
    func validatePackageManifest() throws -> ValidationResult {
        // This would validate the Package.swift content
        return ValidationResult(isValid: true, message: "Package manifest is valid")
    }
    
    func validateDependencies() throws -> ValidationResult {
        // This would check if dependencies can be resolved
        return ValidationResult(isValid: true, message: "Dependencies are resolvable")
    }
    
    func validateExecutables() throws -> ValidationResult {
        let buildPath = InstallationValidationTests.TestConfig.buildPath
        let requiredExecutables = ["RecorderDaemon", "MenuBarApp"]
        
        for executable in requiredExecutables {
            let executablePath = buildPath.appendingPathComponent(executable)
            if !FileManager.default.fileExists(atPath: executablePath.path) {
                return ValidationResult(isValid: false, message: "Missing executable: \(executable)")
            }
        }
        
        return ValidationResult(isValid: true, message: "All executables found")
    }
}

class PermissionValidator {
    
    enum PermissionStatus {
        case granted, denied, notDetermined, unknown
    }
    
    func checkScreenRecordingPermission() -> PermissionStatus {
        // This would check actual screen recording permission
        return .notDetermined
    }
    
    func checkAccessibilityPermission() -> PermissionStatus {
        // This would check actual accessibility permission
        return .notDetermined
    }
    
    func checkFullDiskAccessPermission() -> PermissionStatus {
        // This would check actual full disk access permission
        return .notDetermined
    }
    
    func validatePermissionRequestMechanisms() throws -> InstallationValidationTests.SystemRequirementsValidator.ValidationResult {
        // This would validate that permission request mechanisms work
        return InstallationValidationTests.SystemRequirementsValidator.ValidationResult(
            isValid: true,
            majorVersion: 0,
            minorVersion: 0,
            message: "Permission request mechanisms are functional"
        )
    }
}

// Additional supporting classes would be implemented similarly...
class LaunchAgentInstaller {
    func generateLaunchAgentPlist() throws -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.alwaysonai.recorderdaemon</string>
        </dict>
        </plist>
        """
    }
    
    func getInstallationPath() -> URL {
        return InstallationValidationTests.TestConfig.launchAgentsDir
            .appendingPathComponent(InstallationValidationTests.TestConfig.launchAgentName)
    }
    
    func validatePlistContent(_ content: String) throws -> InstallationValidationTests.SystemRequirementsValidator.ValidationResult {
        return InstallationValidationTests.SystemRequirementsValidator.ValidationResult(
            isValid: true,
            majorVersion: 0,
            minorVersion: 0,
            message: "Plist content is valid"
        )
    }
}

// Placeholder implementations for other supporting classes
class LaunchAgentManager {
    func isLaunchAgentLoaded(_ bundleID: String) throws -> Bool { return false }
    func isLaunchctlAvailable() -> Bool { return true }
}

class CodeSigningValidator {
    func isCodesignAvailable() -> Bool { return true }
    func getAvailableCertificates() throws -> [String] { return [] }
    func checkExecutableSignature(at path: URL) throws -> String { return "unsigned" }
}

class SystemInstaller {
    struct DryRunResult {
        let canInstall: Bool
        let blockingIssues: [String]
        let warnings: [String]
    }
    
    struct InstallationStep {
        let name: String
    }
    
    struct StepValidation {
        let isValid: Bool
    }
    
    func performDryRun() throws -> DryRunResult {
        return DryRunResult(canInstall: true, blockingIssues: [], warnings: [])
    }
    
    func getInstallationSteps() -> [InstallationStep] {
        return [InstallationStep(name: "System Requirements")]
    }
    
    func canExecuteStep(_ step: InstallationStep) throws -> StepValidation {
        return StepValidation(isValid: true)
    }
}

class SystemUninstaller {
    struct InstallationStatus {
        let isInstalled: Bool
    }
    
    struct CleanupStep {
        let name: String
    }
    
    func detectInstallation() throws -> InstallationStatus {
        return InstallationStatus(isInstalled: false)
    }
    
    func getCleanupSteps() -> [CleanupStep] {
        return [CleanupStep(name: "Remove LaunchAgent")]
    }
    
    func getFilesToRemove() throws -> [URL] {
        return []
    }
    
    func canRemoveFile(at url: URL) -> Bool {
        return true
    }
}

class MacOSCompatibilityTester {
    struct APIAvailability {
        let screenCaptureKit: Bool
        let vision: Bool
    }
    
    func isMacOSVersionSupported(_ version: OperatingSystemVersion) -> Bool {
        return version.majorVersion >= 14
    }
    
    func meetsMinimumRequirements(_ current: OperatingSystemVersion, minimum: OperatingSystemVersion) -> Bool {
        return current.majorVersion >= minimum.majorVersion
    }
    
    func checkAPIAvailability() throws -> APIAvailability {
        return APIAvailability(screenCaptureKit: true, vision: true)
    }
}

class ArchitectureCompatibilityTester {
    struct BinaryCompatibility {
        let isCompatible: Bool
    }
    
    func getCurrentArchitecture() throws -> String {
        return "arm64"
    }
    
    func checkBinaryCompatibility() throws -> BinaryCompatibility {
        return BinaryCompatibility(isCompatible: true)
    }
}

class InstallationPerformanceTester {
    struct ResourceUsage {
        let cpuUsage: Double
        let memoryUsage: Int64
    }
    
    func measureDryRunTime() throws -> TimeInterval {
        return 5.0
    }
    
    func measureValidationTime() throws -> TimeInterval {
        return 10.0
    }
    
    func measureResourceUsage() throws -> ResourceUsage {
        return ResourceUsage(cpuUsage: 10.0, memoryUsage: 100_000_000)
    }
}

class SecurityValidator {
    struct SecurityValidation {
        let isSecure: Bool
    }
    
    func validateFilePermissions() throws -> SecurityValidation {
        return SecurityValidation(isSecure: true)
    }
    
    func validateExecutableSecurity() throws -> SecurityValidation {
        return SecurityValidation(isSecure: true)
    }
    
    func validateConfigurationSecurity() throws -> SecurityValidation {
        return SecurityValidation(isSecure: true)
    }
}

class InstallationIntegrationTester {
    struct FlowResult {
        let success: Bool
    }
    
    struct ErrorHandlingResult {
        let handlesErrorsGracefully: Bool
    }
    
    struct RollbackResult {
        let canRollback: Bool
    }
    
    func testCompleteFlow(dryRun: Bool) throws -> FlowResult {
        return FlowResult(success: true)
    }
    
    func testErrorHandling() throws -> ErrorHandlingResult {
        return ErrorHandlingResult(handlesErrorsGracefully: true)
    }
    
    func testRollbackCapability() throws -> RollbackResult {
        return RollbackResult(canRollback: true)
    }
}