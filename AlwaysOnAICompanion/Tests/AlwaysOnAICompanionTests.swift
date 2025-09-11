import XCTest
@testable import Shared

final class AlwaysOnAICompanionTests: XCTestCase {
    
    func testVersionInfo() {
        XCTAssertEqual(AlwaysOnAICompanionVersion.major, 1)
        XCTAssertEqual(AlwaysOnAICompanionVersion.minor, 0)
        XCTAssertEqual(AlwaysOnAICompanionVersion.patch, 0)
        XCTAssertEqual(AlwaysOnAICompanionVersion.string, "1.0.0")
    }
    
    func testSystemInfo() {
        XCTAssertFalse(SystemInfo.macOSVersion.isEmpty)
        XCTAssertFalse(SystemInfo.architecture.isEmpty)
        XCTAssertFalse(SystemInfo.systemDescription.isEmpty)
    }
    
    func testConfigurationManager() {
        let configManager = ConfigurationManager()
        let config = configManager.loadConfiguration()
        
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.frameRate, 30)
        XCTAssertEqual(config?.segmentDuration, 120)
        XCTAssertEqual(config?.maxCPUUsage, 8.0)
    }
    
    func testLogger() {
        let logger = Logger.shared
        
        // Test that logging doesn't crash
        logger.debug("Test debug message")
        logger.info("Test info message")
        logger.warning("Test warning message")
        logger.error("Test error message")
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }
    
    func testRecoveryManager() {
        let recoveryManager = RecoveryManager()
        
        var recoveryTriggered = false
        recoveryManager.onRecoveryNeeded = {
            recoveryTriggered = true
        }
        
        recoveryManager.triggerRecovery()
        
        // Wait a moment for the recovery to be triggered
        let expectation = XCTestExpectation(description: "Recovery triggered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(recoveryTriggered)
    }
    
    func testLaunchAgentManager() {
        let launchAgentManager = LaunchAgentManager()
        
        // Test permission checking (should not crash)
        let permissions = launchAgentManager.checkRequiredPermissions()
        XCTAssertFalse(permissions.isEmpty)
        
        // Test installation status check
        let isInstalled = launchAgentManager.isLaunchAgentInstalled()
        // This should return false since we haven't installed it
        XCTAssertFalse(isInstalled)
    }
}