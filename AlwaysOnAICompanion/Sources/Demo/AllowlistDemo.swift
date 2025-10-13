import Foundation
import CoreGraphics
import Shared

/// Demonstrates the application and screen allowlist system functionality
public class AllowlistDemo {
    private let configurationManager: ConfigurationManager
    private let allowlistManager: AllowlistManager
    
    public init() {
        self.configurationManager = ConfigurationManager()
        self.allowlistManager = AllowlistManager(configurationManager: configurationManager)
        
        // Set up change notifications
        allowlistManager.onAllowlistChanged = { [weak self] in
            self?.printAllowlistStatus()
        }
    }
    
    public func runDemo() {
        print("=== Always-On AI Companion: Allowlist System Demo ===\n")
        
        demonstrateBasicApplicationAllowlist()
        demonstrateDisplayAllowlist()
        demonstrateDisplaySpecificAllowlists()
        demonstrateMultiMonitorScenario()
        demonstrateApplicationDiscovery()
        demonstrateDynamicUpdates()
        
        print("\n=== Demo Complete ===")
    }
    
    // MARK: - Basic Application Allowlist
    
    private func demonstrateBasicApplicationAllowlist() {
        print("📱 Basic Application Allowlist Demo")
        print("==================================")
        
        // Test applications
        let workApps = ["com.microsoft.teams", "com.atlassian.jira", "com.slack.desktop"]
        let personalApps = ["com.spotify.client", "com.apple.mail"]
        let sensitiveApps = ["com.1password.1password", "com.apple.keychain"]
        
        print("\n1. Testing default behavior (no allowlist):")
        for app in workApps + personalApps + sensitiveApps {
            let allowed = allowlistManager.shouldCaptureApplication(app)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n2. Adding work applications to allowlist:")
        allowlistManager.setAllowedApplications(workApps)
        
        for app in workApps {
            let allowed = allowlistManager.shouldCaptureApplication(app)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        for app in personalApps {
            let allowed = allowlistManager.shouldCaptureApplication(app)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n3. Blocking sensitive applications:")
        allowlistManager.setBlockedApplications(sensitiveApps)
        
        for app in sensitiveApps {
            let allowed = allowlistManager.shouldCaptureApplication(app)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n4. Testing conflict resolution (blocked overrides allowed):")
        let conflictApp = workApps[0]
        allowlistManager.addBlockedApplication(conflictApp)
        let allowed = allowlistManager.shouldCaptureApplication(conflictApp)
        print("   \(conflictApp): \(allowed ? "✅ Allowed" : "❌ Blocked") (should be blocked)")
        
        // Reset for next demo
        allowlistManager.setAllowedApplications([])
        allowlistManager.setBlockedApplications([])
        
        print("\n")
    }
    
    // MARK: - Display Allowlist
    
    private func demonstrateDisplayAllowlist() {
        print("🖥️ Display Allowlist Demo")
        print("========================")
        
        let displays: [CGDirectDisplayID] = [1, 2, 3]
        
        print("\n1. Testing default behavior (no display restrictions):")
        for display in displays {
            let allowed = allowlistManager.shouldCaptureDisplay(display)
            print("   Display \(display): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n2. Restricting to specific displays:")
        let allowedDisplays: [CGDirectDisplayID] = [1, 3]
        allowlistManager.setAllowedDisplays(allowedDisplays)
        
        for display in displays {
            let allowed = allowlistManager.shouldCaptureDisplay(display)
            print("   Display \(display): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        // Reset for next demo
        allowlistManager.setAllowedDisplays([])
        
        print("\n")
    }
    
    // MARK: - Display-Specific Allowlists
    
    private func demonstrateDisplaySpecificAllowlists() {
        print("🖥️📱 Display-Specific Application Allowlists Demo")
        print("===============================================")
        
        let workDisplay: CGDirectDisplayID = 1
        let personalDisplay: CGDirectDisplayID = 2
        
        let workApp = "com.microsoft.teams"
        let personalApp = "com.spotify.client"
        let sharedApp = "com.apple.finder"
        let sensitiveApp = "com.1password.1password"
        
        print("\n1. Setting up work display allowlist:")
        allowlistManager.addApplicationToDisplay(workDisplay, bundleIdentifier: workApp)
        allowlistManager.addApplicationToDisplay(workDisplay, bundleIdentifier: sharedApp)
        allowlistManager.blockApplicationOnDisplay(workDisplay, bundleIdentifier: sensitiveApp)
        
        print("\n2. Setting up personal display allowlist:")
        allowlistManager.addApplicationToDisplay(personalDisplay, bundleIdentifier: personalApp)
        allowlistManager.addApplicationToDisplay(personalDisplay, bundleIdentifier: sharedApp)
        
        print("\n3. Testing work display rules:")
        let testApps = [workApp, personalApp, sharedApp, sensitiveApp]
        for app in testApps {
            let allowed = allowlistManager.shouldCaptureApplication(app, onDisplay: workDisplay)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n4. Testing personal display rules:")
        for app in testApps {
            let allowed = allowlistManager.shouldCaptureApplication(app, onDisplay: personalDisplay)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n5. Testing global vs display-specific rules:")
        allowlistManager.addBlockedApplication(sharedApp) // Block globally
        
        print("   Global check for \(sharedApp): \(allowlistManager.shouldCaptureApplication(sharedApp) ? "✅ Allowed" : "❌ Blocked")")
        print("   Work display check for \(sharedApp): \(allowlistManager.shouldCaptureApplication(sharedApp, onDisplay: workDisplay) ? "✅ Allowed" : "❌ Blocked")")
        print("   Personal display check for \(sharedApp): \(allowlistManager.shouldCaptureApplication(sharedApp, onDisplay: personalDisplay) ? "✅ Allowed" : "❌ Blocked")")
        
        // Reset for next demo
        allowlistManager.removeDisplayAllowlist(workDisplay)
        allowlistManager.removeDisplayAllowlist(personalDisplay)
        allowlistManager.setBlockedApplications([])
        
        print("\n")
    }
    
    // MARK: - Multi-Monitor Scenario
    
    private func demonstrateMultiMonitorScenario() {
        print("🖥️🖥️🖥️ Multi-Monitor Privacy Scenario Demo")
        print("=========================================")
        
        let workDisplay: CGDirectDisplayID = 1
        let personalDisplay: CGDirectDisplayID = 2
        let sharedDisplay: CGDirectDisplayID = 3
        
        print("\nScenario: User has 3 monitors")
        print("- Work display (1): Only work applications")
        print("- Personal display (2): Only personal applications")
        print("- Shared display (3): General applications, but no sensitive data")
        
        // Configure work display
        let workApps = ["com.microsoft.teams", "com.atlassian.jira", "com.slack.desktop"]
        for app in workApps {
            allowlistManager.addApplicationToDisplay(workDisplay, bundleIdentifier: app)
        }
        
        // Configure personal display
        let personalApps = ["com.spotify.client", "com.apple.mail", "com.apple.safari"]
        for app in personalApps {
            allowlistManager.addApplicationToDisplay(personalDisplay, bundleIdentifier: app)
        }
        
        // Configure shared display (block sensitive apps only)
        let sensitiveApps = ["com.1password.1password", "com.apple.keychain", "com.apple.wallet"]
        for app in sensitiveApps {
            allowlistManager.blockApplicationOnDisplay(sharedDisplay, bundleIdentifier: app)
        }
        
        print("\n1. Work Display Rules:")
        let allApps = workApps + personalApps + sensitiveApps + ["com.apple.finder"]
        for app in allApps {
            let allowed = allowlistManager.shouldCaptureApplication(app, onDisplay: workDisplay)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n2. Personal Display Rules:")
        for app in allApps {
            let allowed = allowlistManager.shouldCaptureApplication(app, onDisplay: personalDisplay)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        print("\n3. Shared Display Rules:")
        for app in allApps {
            let allowed = allowlistManager.shouldCaptureApplication(app, onDisplay: sharedDisplay)
            print("   \(app): \(allowed ? "✅ Allowed" : "❌ Blocked")")
        }
        
        // Reset for next demo
        allowlistManager.removeDisplayAllowlist(workDisplay)
        allowlistManager.removeDisplayAllowlist(personalDisplay)
        allowlistManager.removeDisplayAllowlist(sharedDisplay)
        
        print("\n")
    }
    
    // MARK: - Application Discovery
    
    private func demonstrateApplicationDiscovery() {
        print("🔍 Application Discovery Demo")
        print("============================")
        
        print("\n1. Currently running applications:")
        let runningApps = allowlistManager.getRunningApplications()
        let displayCount = min(runningApps.count, 5) // Show first 5
        
        for i in 0..<displayCount {
            let app = runningApps[i]
            print("   \(app.name) (\(app.bundleIdentifier)) - \(app.isActive ? "Active" : "Background")")
        }
        
        if runningApps.count > displayCount {
            print("   ... and \(runningApps.count - displayCount) more")
        }
        
        print("\n2. Installed applications (sample):")
        let installedApps = allowlistManager.getInstalledApplications()
        let installedDisplayCount = min(installedApps.count, 5) // Show first 5
        
        for i in 0..<installedDisplayCount {
            let app = installedApps[i]
            print("   \(app.name) (\(app.bundleIdentifier))")
        }
        
        if installedApps.count > installedDisplayCount {
            print("   ... and \(installedApps.count - installedDisplayCount) more")
        }
        
        print("\n")
    }
    
    // MARK: - Dynamic Updates
    
    private func demonstrateDynamicUpdates() {
        print("🔄 Dynamic Allowlist Updates Demo")
        print("================================")
        
        let testApp = "com.example.testapp"
        let displayID: CGDirectDisplayID = 12345
        
        print("\nDemonstrating dynamic updates without system restart:")
        
        print("\n1. Initial state:")
        print("   Global: \(allowlistManager.shouldCaptureApplication(testApp) ? "✅ Allowed" : "❌ Blocked")")
        print("   Display \(displayID): \(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID) ? "✅ Allowed" : "❌ Blocked")")
        
        print("\n2. Adding to global allowlist:")
        allowlistManager.addAllowedApplication(testApp)
        print("   Global: \(allowlistManager.shouldCaptureApplication(testApp) ? "✅ Allowed" : "❌ Blocked")")
        print("   Display \(displayID): \(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID) ? "✅ Allowed" : "❌ Blocked")")
        
        print("\n3. Blocking on specific display:")
        allowlistManager.blockApplicationOnDisplay(displayID, bundleIdentifier: testApp)
        print("   Global: \(allowlistManager.shouldCaptureApplication(testApp) ? "✅ Allowed" : "❌ Blocked")")
        print("   Display \(displayID): \(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID) ? "✅ Allowed" : "❌ Blocked")")
        
        print("\n4. Removing from global allowlist:")
        allowlistManager.removeAllowedApplication(testApp)
        print("   Global: \(allowlistManager.shouldCaptureApplication(testApp) ? "✅ Allowed" : "❌ Blocked")")
        print("   Display \(displayID): \(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID) ? "✅ Allowed" : "❌ Blocked")")
        
        print("\n5. Unblocking on specific display:")
        allowlistManager.unblockApplicationOnDisplay(displayID, bundleIdentifier: testApp)
        print("   Global: \(allowlistManager.shouldCaptureApplication(testApp) ? "✅ Allowed" : "❌ Blocked")")
        print("   Display \(displayID): \(allowlistManager.shouldCaptureApplication(testApp, onDisplay: displayID) ? "✅ Allowed" : "❌ Blocked")")
        
        // Reset
        allowlistManager.setAllowedApplications([])
        allowlistManager.removeDisplayAllowlist(displayID)
        
        print("\n")
    }
    
    // MARK: - Helper Methods
    
    private func printAllowlistStatus() {
        print("📢 Allowlist configuration changed!")
    }
}

// MARK: - Demo Runner

public func runAllowlistDemo() {
    let demo = AllowlistDemo()
    demo.runDemo()
}