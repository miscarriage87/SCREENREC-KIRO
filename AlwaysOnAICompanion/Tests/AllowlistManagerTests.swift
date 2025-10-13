import XCTest
import CoreGraphics
@testable import Shared

class AllowlistManagerTests: XCTestCase {
    var configurationManager: ConfigurationManager!
    var allowlistManager: AllowlistManager!
    
    override func setUp() {
        super.setUp()
        configurationManager = ConfigurationManager()
        allowlistManager = AllowlistManager(configurationManager: configurationManager)
    }
    
    override func tearDown() {
        allowlistManager = nil
        configurationManager = nil
        super.tearDown()
    }
    
    // MARK: - Application Allowlist Tests
    
    func testAddAllowedApplication() {
        // Given
        let bundleID = "com.example.testapp"
        
        // When
        allowlistManager.addAllowedApplication(bundleID)
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID))
    }
    
    func testRemoveAllowedApplication() {
        // Given
        let bundleID = "com.example.testapp"
        allowlistManager.addAllowedApplication(bundleID)
        
        // When
        allowlistManager.removeAllowedApplication(bundleID)
        
        // Then
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(bundleID))
    }
    
    func testAddBlockedApplication() {
        // Given
        let bundleID = "com.example.blockedapp"
        
        // When
        allowlistManager.addBlockedApplication(bundleID)
        
        // Then
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(bundleID))
    }
    
    func testRemoveBlockedApplication() {
        // Given
        let bundleID = "com.example.blockedapp"
        allowlistManager.addBlockedApplication(bundleID)
        
        // When
        allowlistManager.removeBlockedApplication(bundleID)
        
        // Then
        // Should return true since no allowlist is set (captures all by default)
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID))
    }
    
    func testSetAllowedApplications() {
        // Given
        let allowedApps = ["com.example.app1", "com.example.app2", "com.example.app3"]
        let blockedApp = "com.example.blocked"
        
        // When
        allowlistManager.setAllowedApplications(allowedApps)
        
        // Then
        for app in allowedApps {
            XCTAssertTrue(allowlistManager.shouldCaptureApplication(app))
        }
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(blockedApp))
    }
    
    func testSetBlockedApplications() {
        // Given
        let blockedApps = ["com.example.blocked1", "com.example.blocked2"]
        let allowedApp = "com.example.allowed"
        
        // When
        allowlistManager.setBlockedApplications(blockedApps)
        
        // Then
        for app in blockedApps {
            XCTAssertFalse(allowlistManager.shouldCaptureApplication(app))
        }
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(allowedApp))
    }
    
    func testBlockedApplicationOverridesAllowed() {
        // Given
        let bundleID = "com.example.conflictapp"
        
        // When
        allowlistManager.addAllowedApplication(bundleID)
        allowlistManager.addBlockedApplication(bundleID)
        
        // Then
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(bundleID))
    }
    
    // MARK: - Display Allowlist Tests
    
    func testAddAllowedDisplay() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        
        // When
        allowlistManager.addAllowedDisplay(displayID)
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureDisplay(displayID))
    }
    
    func testRemoveAllowedDisplay() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        allowlistManager.addAllowedDisplay(displayID)
        
        // When
        allowlistManager.removeAllowedDisplay(displayID)
        
        // Then
        // Should return true since no displays are selected (captures all by default)
        XCTAssertTrue(allowlistManager.shouldCaptureDisplay(displayID))
    }
    
    func testSetAllowedDisplays() {
        // Given
        let allowedDisplays: [CGDirectDisplayID] = [12345, 67890, 11111]
        let blockedDisplay: CGDirectDisplayID = 99999
        
        // When
        allowlistManager.setAllowedDisplays(allowedDisplays)
        
        // Then
        for display in allowedDisplays {
            XCTAssertTrue(allowlistManager.shouldCaptureDisplay(display))
        }
        XCTAssertFalse(allowlistManager.shouldCaptureDisplay(blockedDisplay))
    }
    
    // MARK: - Display-Specific Allowlist Tests
    
    func testDisplaySpecificAllowlist() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let allowedApp = "com.example.allowed"
        let blockedApp = "com.example.blocked"
        
        var displayAllowlist = DisplayAllowlist()
        displayAllowlist.allowedApplications.insert(allowedApp)
        displayAllowlist.blockedApplications.insert(blockedApp)
        
        // When
        allowlistManager.setDisplayAllowlist(displayID, allowlist: displayAllowlist)
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(allowedApp, onDisplay: displayID))
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(blockedApp, onDisplay: displayID))
    }
    
    func testAddApplicationToDisplay() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let bundleID = "com.example.testapp"
        
        // When
        allowlistManager.addApplicationToDisplay(displayID, bundleIdentifier: bundleID)
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID, onDisplay: displayID))
    }
    
    func testRemoveApplicationFromDisplay() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let bundleID = "com.example.testapp"
        allowlistManager.addApplicationToDisplay(displayID, bundleIdentifier: bundleID)
        
        // When
        allowlistManager.removeApplicationFromDisplay(displayID, bundleIdentifier: bundleID)
        
        // Then
        // Should fall back to global allowlist rules
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID, onDisplay: displayID))
    }
    
    func testBlockApplicationOnDisplay() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let bundleID = "com.example.blockedapp"
        
        // When
        allowlistManager.blockApplicationOnDisplay(displayID, bundleIdentifier: bundleID)
        
        // Then
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(bundleID, onDisplay: displayID))
    }
    
    func testUnblockApplicationOnDisplay() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let bundleID = "com.example.blockedapp"
        allowlistManager.blockApplicationOnDisplay(displayID, bundleIdentifier: bundleID)
        
        // When
        allowlistManager.unblockApplicationOnDisplay(displayID, bundleIdentifier: bundleID)
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID, onDisplay: displayID))
    }
    
    func testDisplaySpecificBlockOverridesGlobalAllow() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let bundleID = "com.example.conflictapp"
        
        // When
        allowlistManager.addAllowedApplication(bundleID) // Global allow
        allowlistManager.blockApplicationOnDisplay(displayID, bundleIdentifier: bundleID) // Display-specific block
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID)) // Global check
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(bundleID, onDisplay: displayID)) // Display-specific check
    }
    
    func testDisplaySpecificAllowOverridesGlobalBlock() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let bundleID = "com.example.conflictapp"
        
        // When
        allowlistManager.addBlockedApplication(bundleID) // Global block
        allowlistManager.addApplicationToDisplay(displayID, bundleIdentifier: bundleID) // Display-specific allow
        
        // Then
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(bundleID)) // Global check
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID, onDisplay: displayID)) // Display-specific check
    }
    
    func testFallbackToGlobalRulesWhenNoDisplaySpecificRules() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let allowedApp = "com.example.allowed"
        let blockedApp = "com.example.blocked"
        
        // When
        allowlistManager.addAllowedApplication(allowedApp)
        allowlistManager.addBlockedApplication(blockedApp)
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(allowedApp, onDisplay: displayID))
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(blockedApp, onDisplay: displayID))
    }
    
    // MARK: - Multi-Monitor Scenario Tests
    
    func testMultiMonitorDifferentAllowlists() {
        // Given
        let display1: CGDirectDisplayID = 12345
        let display2: CGDirectDisplayID = 67890
        let workApp = "com.example.work"
        let personalApp = "com.example.personal"
        
        // When - Set up work display (display1) to only allow work apps
        allowlistManager.addApplicationToDisplay(display1, bundleIdentifier: workApp)
        
        // Set up personal display (display2) to only allow personal apps
        allowlistManager.addApplicationToDisplay(display2, bundleIdentifier: personalApp)
        
        // Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(workApp, onDisplay: display1))
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(personalApp, onDisplay: display1))
        
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(workApp, onDisplay: display2))
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(personalApp, onDisplay: display2))
    }
    
    func testMultiMonitorMixedConfiguration() {
        // Given
        let display1: CGDirectDisplayID = 12345
        let display2: CGDirectDisplayID = 67890
        let sensitiveApp = "com.example.sensitive"
        let normalApp = "com.example.normal"
        
        // When - Block sensitive app on display1 only
        allowlistManager.blockApplicationOnDisplay(display1, bundleIdentifier: sensitiveApp)
        
        // Then
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(sensitiveApp, onDisplay: display1))
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(sensitiveApp, onDisplay: display2))
        
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(normalApp, onDisplay: display1))
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(normalApp, onDisplay: display2))
    }
    
    // MARK: - Configuration Persistence Tests
    
    func testAllowlistChangeNotification() {
        // Given
        var notificationReceived = false
        allowlistManager.onAllowlistChanged = {
            notificationReceived = true
        }
        
        // When
        allowlistManager.addAllowedApplication("com.example.test")
        
        // Then
        XCTAssertTrue(notificationReceived)
    }
    
    func testDisplaySpecificAllowlistChangeNotification() {
        // Given
        var notificationReceived = false
        allowlistManager.onAllowlistChanged = {
            notificationReceived = true
        }
        
        // When
        allowlistManager.addApplicationToDisplay(12345, bundleIdentifier: "com.example.test")
        
        // Then
        XCTAssertTrue(notificationReceived)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testEmptyAllowlistCapturesAll() {
        // Given - No allowlist configured
        let bundleID = "com.example.anyapp"
        
        // When/Then
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(bundleID))
    }
    
    func testEmptyDisplayListCapturesAll() {
        // Given - No display list configured
        let displayID: CGDirectDisplayID = 12345
        
        // When/Then
        XCTAssertTrue(allowlistManager.shouldCaptureDisplay(displayID))
    }
    
    func testGetDisplayAllowlistReturnsNilForNonExistent() {
        // Given
        let displayID: CGDirectDisplayID = 99999
        
        // When
        let allowlist = allowlistManager.getDisplayAllowlist(displayID)
        
        // Then
        XCTAssertNil(allowlist)
    }
    
    func testRemoveNonExistentDisplayAllowlist() {
        // Given
        let displayID: CGDirectDisplayID = 99999
        
        // When/Then - Should not crash
        allowlistManager.removeDisplayAllowlist(displayID)
    }
    
    // MARK: - Application Discovery Tests
    
    func testGetRunningApplications() {
        // When
        let runningApps = allowlistManager.getRunningApplications()
        
        // Then
        XCTAssertTrue(runningApps.count >= 0) // Should not crash and return valid array
        
        // Verify structure of returned applications
        for app in runningApps {
            XCTAssertFalse(app.bundleIdentifier.isEmpty)
            XCTAssertFalse(app.name.isEmpty)
        }
    }
    
    func testGetInstalledApplications() {
        // When
        let installedApps = allowlistManager.getInstalledApplications()
        
        // Then
        XCTAssertTrue(installedApps.count >= 0) // Should not crash and return valid array
        
        // Verify structure of returned applications
        for app in installedApps {
            XCTAssertFalse(app.bundleIdentifier.isEmpty)
            XCTAssertFalse(app.name.isEmpty)
        }
    }
}

// MARK: - Integration Tests

class AllowlistManagerIntegrationTests: XCTestCase {
    var configurationManager: ConfigurationManager!
    var allowlistManager: AllowlistManager!
    
    override func setUp() {
        super.setUp()
        configurationManager = ConfigurationManager()
        allowlistManager = AllowlistManager(configurationManager: configurationManager)
    }
    
    override func tearDown() {
        allowlistManager = nil
        configurationManager = nil
        super.tearDown()
    }
    
    func testComplexMultiDisplayScenario() {
        // Given - A complex multi-monitor setup
        let workDisplay: CGDirectDisplayID = 1
        let personalDisplay: CGDirectDisplayID = 2
        let sharedDisplay: CGDirectDisplayID = 3
        
        let workApps = ["com.microsoft.teams", "com.atlassian.jira", "com.slack.desktop"]
        let personalApps = ["com.spotify.client", "com.apple.mail", "com.apple.safari"]
        let sensitiveApps = ["com.1password.1password", "com.apple.keychain"]
        let sharedApps = ["com.apple.finder", "com.apple.systempreferences"]
        
        // When - Configure complex allowlist rules
        
        // Work display: Only work apps + shared apps, block sensitive apps
        for app in workApps + sharedApps {
            allowlistManager.addApplicationToDisplay(workDisplay, bundleIdentifier: app)
        }
        for app in sensitiveApps {
            allowlistManager.blockApplicationOnDisplay(workDisplay, bundleIdentifier: app)
        }
        
        // Personal display: Only personal apps + shared apps
        for app in personalApps + sharedApps {
            allowlistManager.addApplicationToDisplay(personalDisplay, bundleIdentifier: app)
        }
        
        // Shared display: Block sensitive apps only
        for app in sensitiveApps {
            allowlistManager.blockApplicationOnDisplay(sharedDisplay, bundleIdentifier: app)
        }
        
        // Then - Verify complex rules work correctly
        
        // Work display tests
        for app in workApps {
            XCTAssertTrue(allowlistManager.shouldCaptureApplication(app, onDisplay: workDisplay), "Work app \(app) should be allowed on work display")
        }
        for app in personalApps {
            XCTAssertFalse(allowlistManager.shouldCaptureApplication(app, onDisplay: workDisplay), "Personal app \(app) should not be allowed on work display")
        }
        for app in sensitiveApps {
            XCTAssertFalse(allowlistManager.shouldCaptureApplication(app, onDisplay: workDisplay), "Sensitive app \(app) should be blocked on work display")
        }
        for app in sharedApps {
            XCTAssertTrue(allowlistManager.shouldCaptureApplication(app, onDisplay: workDisplay), "Shared app \(app) should be allowed on work display")
        }
        
        // Personal display tests
        for app in personalApps {
            XCTAssertTrue(allowlistManager.shouldCaptureApplication(app, onDisplay: personalDisplay), "Personal app \(app) should be allowed on personal display")
        }
        for app in workApps {
            XCTAssertFalse(allowlistManager.shouldCaptureApplication(app, onDisplay: personalDisplay), "Work app \(app) should not be allowed on personal display")
        }
        for app in sharedApps {
            XCTAssertTrue(allowlistManager.shouldCaptureApplication(app, onDisplay: personalDisplay), "Shared app \(app) should be allowed on personal display")
        }
        
        // Shared display tests (falls back to global rules, but blocks sensitive apps)
        for app in sensitiveApps {
            XCTAssertFalse(allowlistManager.shouldCaptureApplication(app, onDisplay: sharedDisplay), "Sensitive app \(app) should be blocked on shared display")
        }
        for app in workApps + personalApps + sharedApps {
            XCTAssertTrue(allowlistManager.shouldCaptureApplication(app, onDisplay: sharedDisplay), "App \(app) should be allowed on shared display")
        }
    }
    
    func testDynamicAllowlistUpdates() {
        // Given
        let displayID: CGDirectDisplayID = 12345
        let testApp = "com.example.testapp"
        
        var changeNotifications = 0
        allowlistManager.onAllowlistChanged = {
            changeNotifications += 1
        }
        
        // When - Make multiple dynamic updates
        allowlistManager.addApplicationToDisplay(displayID, bundleIdentifier: testApp)
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID))
        
        allowlistManager.blockApplicationOnDisplay(displayID, bundleIdentifier: testApp)
        XCTAssertFalse(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID))
        
        allowlistManager.unblockApplicationOnDisplay(displayID, bundleIdentifier: testApp)
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID))
        
        allowlistManager.removeApplicationFromDisplay(displayID, bundleIdentifier: testApp)
        // Should fall back to global rules (true since no global restrictions)
        XCTAssertTrue(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID))
        
        // Then
        XCTAssertEqual(changeNotifications, 4, "Should receive notification for each change")
    }
}