import Foundation
import Shared

@main
struct LaunchAgentInstaller {
    static func main() async {
        print("Always-On AI Companion LaunchAgent Installer")
        print("============================================")
        
        let launchAgentManager = LaunchAgentManager()
        
        // Parse command line arguments
        let arguments = CommandLine.arguments
        
        if arguments.contains("--uninstall") {
            await uninstallLaunchAgent(manager: launchAgentManager)
            return
        }
        
        if arguments.contains("--status") {
            checkStatus(manager: launchAgentManager)
            return
        }
        
        if arguments.contains("--permissions") {
            await checkPermissions(manager: launchAgentManager)
            return
        }
        
        if arguments.contains("--help") || arguments.contains("-h") {
            printHelp()
            return
        }
        
        // Default action: install
        await installLaunchAgent(manager: launchAgentManager)
    }
    
    static func installLaunchAgent(manager: LaunchAgentManager) async {
        print("\n🔧 Installing LaunchAgent...")
        
        do {
            // Check permissions first
            print("Checking required permissions...")
            let permissions = manager.checkRequiredPermissions()
            
            var missingRequired = false
            for permission in permissions {
                print("  \(permission.description)")
                if permission.required && !permission.granted {
                    missingRequired = true
                }
            }
            
            if missingRequired {
                print("\n⚠️  Missing required permissions!")
                print("Would you like to request permissions now? (y/n): ", terminator: "")
                
                if let input = readLine(), input.lowercased() == "y" {
                    let granted = await manager.requestPermissions()
                    if !granted {
                        print("❌ Some permissions were not granted. Opening System Preferences...")
                        manager.requestPermissionsInteractive()
                        print("Please grant the required permissions and run the installer again.")
                        return
                    }
                } else {
                    print("Installation cancelled. Permissions are required for proper operation.")
                    return
                }
            }
            
            // Install the LaunchAgent
            try manager.installLaunchAgent()
            
            print("✅ LaunchAgent installed successfully!")
            print("\nThe RecorderDaemon will now start automatically on system boot.")
            
            // Check if it's running
            if manager.isLaunchAgentLoaded() {
                print("✅ RecorderDaemon is currently running")
            } else {
                print("⚠️  RecorderDaemon is not currently running. It will start on next boot.")
            }
            
        } catch {
            print("❌ Installation failed: \(error)")
            exit(1)
        }
    }
    
    static func uninstallLaunchAgent(manager: LaunchAgentManager) async {
        print("\n🗑️  Uninstalling LaunchAgent...")
        
        do {
            try manager.uninstallLaunchAgent()
            print("✅ LaunchAgent uninstalled successfully!")
            print("Note: You may want to manually remove permissions from System Preferences > Privacy & Security")
        } catch {
            print("❌ Uninstallation failed: \(error)")
            exit(1)
        }
    }
    
    static func checkStatus(manager: LaunchAgentManager) {
        print("\n📊 LaunchAgent Status")
        print("====================")
        
        let isInstalled = manager.isLaunchAgentInstalled()
        let isLoaded = manager.isLaunchAgentLoaded()
        
        print("Installed: \(isInstalled ? "✅ Yes" : "❌ No")")
        print("Running: \(isLoaded ? "✅ Yes" : "❌ No")")
        
        if let daemonPath = manager.getDaemonExecutablePath() {
            print("Daemon Path: \(daemonPath)")
        } else {
            print("Daemon Path: ❌ Not found")
        }
        
        print("\nPermissions:")
        let permissions = manager.checkRequiredPermissions()
        for permission in permissions {
            print("  \(permission.description)")
        }
        
        // Check log files
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let logURL = homeURL
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("AlwaysOnAICompanion")
        
        let stdoutLog = logURL.appendingPathComponent("stdout.log")
        let stderrLog = logURL.appendingPathComponent("stderr.log")
        
        print("\nLog Files:")
        print("  stdout: \(FileManager.default.fileExists(atPath: stdoutLog.path) ? "✅" : "❌") \(stdoutLog.path)")
        print("  stderr: \(FileManager.default.fileExists(atPath: stderrLog.path) ? "✅" : "❌") \(stderrLog.path)")
        
        if FileManager.default.fileExists(atPath: stderrLog.path) {
            print("\nRecent errors:")
            do {
                let errorContent = try String(contentsOf: stderrLog)
                let lines = errorContent.components(separatedBy: .newlines).suffix(5)
                for line in lines where !line.isEmpty {
                    print("  \(line)")
                }
            } catch {
                print("  Could not read error log: \(error)")
            }
        }
    }
    
    static func checkPermissions(manager: LaunchAgentManager) async {
        print("\n🔐 Permission Check")
        print("==================")
        
        let permissions = manager.checkRequiredPermissions()
        
        for permission in permissions {
            print("\(permission.description)")
        }
        
        let missingRequired = permissions.filter { $0.required && !$0.granted }
        
        if !missingRequired.isEmpty {
            print("\n⚠️  Missing required permissions!")
            print("Would you like to request permissions now? (y/n): ", terminator: "")
            
            if let input = readLine(), input.lowercased() == "y" {
                let granted = await manager.requestPermissions()
                if granted {
                    print("✅ All permissions granted!")
                } else {
                    print("❌ Some permissions were not granted. Opening System Preferences...")
                    manager.requestPermissionsInteractive()
                }
            }
        } else {
            print("\n✅ All required permissions are granted!")
        }
    }
    
    static func printHelp() {
        print("""
        Always-On AI Companion LaunchAgent Installer
        
        Usage: LaunchAgentInstaller [options]
        
        Options:
          --install      Install the LaunchAgent (default)
          --uninstall    Uninstall the LaunchAgent
          --status       Show current status
          --permissions  Check and request permissions
          --help, -h     Show this help message
        
        Examples:
          LaunchAgentInstaller                 # Install LaunchAgent
          LaunchAgentInstaller --status        # Check status
          LaunchAgentInstaller --uninstall     # Remove LaunchAgent
          LaunchAgentInstaller --permissions   # Check permissions
        """)
    }
}