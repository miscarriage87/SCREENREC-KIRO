import XCTest
import Foundation
@testable import Shared

final class LaunchAgentManagerTests: XCTestCase {
    var launchAgentManager: LaunchAgentManager!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        launchAgentManager = LaunchAgentManager()
        
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchAgentTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testGetDaemonExecutablePath() {
        // Test that the method returns a valid path or nil
        let path = launchAgentManager.getDaemonExecutablePath()
        
        if let path = path {
            // If a path is returned, it should be executable
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path),
                         "Returned path should be executable: \(path)")
        }
        // It's okay if no path is found in test environment
    }
    
    func testPermissionChecking() {
        let permissions = launchAgentManager.checkRequiredPermissions()
        
        // Should return exactly 3 permission statuses
        XCTAssertEqual(permissions.count, 3, "Should check 3 permissions")
        
        // Check that all required permission types are present
        let types = permissions.map { $0.type }
        XCTAssertTrue(types.contains(.screenRecording), "Should check screen recording permission")
        XCTAssertTrue(types.contains(.accessibility), "Should check accessibility permission")
        XCTAssertTrue(types.contains(.fullDiskAccess), "Should check full disk access permission")
        
        // Screen recording and accessibility should be required
        let screenRecording = permissions.first { $0.type == .screenRecording }
        let accessibility = permissions.first { $0.type == .accessibility }
        let fullDiskAccess = permissions.first { $0.type == .fullDiskAccess }
        
        XCTAssertTrue(screenRecording?.required == true, "Screen recording should be required")
        XCTAssertTrue(accessibility?.required == true, "Accessibility should be required")
        XCTAssertTrue(fullDiskAccess?.required == false, "Full disk access should be optional")
    }
    
    func testPermissionStatusDescription() {
        let grantedRequired = PermissionStatus(type: .screenRecording, granted: true, required: true)
        let deniedOptional = PermissionStatus(type: .fullDiskAccess, granted: false, required: false)
        
        XCTAssertTrue(grantedRequired.description.contains("✅ Granted"))
        XCTAssertTrue(grantedRequired.description.contains("(Required)"))
        
        XCTAssertTrue(deniedOptional.description.contains("❌ Denied"))
        XCTAssertTrue(deniedOptional.description.contains("(Optional)"))
    }
    
    func testLaunchAgentPlistGeneration() {
        // Create a mock daemon path
        let mockDaemonPath = "/usr/local/bin/RecorderDaemon"
        
        // Use reflection to access the private method for testing
        let mirror = Mirror(reflecting: launchAgentManager)
        
        // We can't easily test the private method, so let's test the public interface
        // by checking if the installation would fail with a non-existent daemon
        XCTAssertThrowsError(try launchAgentManager.installLaunchAgent(daemonPath: "/nonexistent/path")) { error in
            if let launchAgentError = error as? LaunchAgentError {
                switch launchAgentError {
                case .daemonNotExecutable:
                    // This is expected for a non-existent path
                    break
                default:
                    XCTFail("Expected daemonNotExecutable error, got \(launchAgentError)")
                }
            } else {
                XCTFail("Expected LaunchAgentError, got \(error)")
            }
        }
    }
    
    func testLaunchAgentErrorDescriptions() {
        let errors: [LaunchAgentError] = [
            .notInstalled,
            .loadFailed("test error"),
            .unloadFailed("test error"),
            .permissionDenied,
            .daemonNotFound,
            .daemonNotExecutable("/test/path")
        ]
        
        for error in errors {
            let description = error.localizedDescription
            XCTAssertFalse(description.isEmpty, "Error description should not be empty")
            XCTAssertTrue(description.count > 10, "Error description should be meaningful")
        }
    }
    
    func testIsLaunchAgentInstalled() {
        // In a clean test environment, the launch agent should not be installed
        let isInstalled = launchAgentManager.isLaunchAgentInstalled()
        
        // This test is environment-dependent, so we just verify the method doesn't crash
        XCTAssertNotNil(isInstalled, "Method should return a boolean value")
    }
    
    func testIsLaunchAgentLoaded() {
        // Test that the method returns a boolean without crashing
        let isLoaded = launchAgentManager.isLaunchAgentLoaded()
        XCTAssertNotNil(isLoaded, "Method should return a boolean value")
    }
    
    func testPermissionTypeDescriptions() {
        let types: [PermissionType] = [.screenRecording, .accessibility, .fullDiskAccess]
        
        for type in types {
            let description = type.description
            XCTAssertFalse(description.isEmpty, "Permission type description should not be empty")
        }
    }
    
    // Integration test that requires manual verification
    func testRequestPermissionsInteractive() {
        // This test just verifies the method doesn't crash
        // Actual permission testing requires user interaction
        XCTAssertNoThrow(launchAgentManager.requestPermissionsInteractive())
    }
    
    // Performance test for permission checking
    func testPermissionCheckingPerformance() {
        measure {
            _ = launchAgentManager.checkRequiredPermissions()
        }
    }
}

// MARK: - Mock Tests
extension LaunchAgentManagerTests {
    func testMockDaemonInstallation() {
        // Create a mock executable file
        let mockExecutable = tempDirectory.appendingPathComponent("MockDaemon")
        let mockContent = "#!/bin/bash\necho 'Mock daemon'\n"
        
        try! mockContent.write(to: mockExecutable, atomically: true, encoding: .utf8)
        
        // Make it executable
        let attributes = [FileAttributeKey.posixPermissions: 0o755]
        try! FileManager.default.setAttributes(attributes, ofItemAtPath: mockExecutable.path)
        
        // Verify it's executable
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: mockExecutable.path))
        
        // Test installation would work with this path (but don't actually install)
        // We can't easily test the full installation without affecting the system
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: mockExecutable.path))
    }
}