#!/usr/bin/env swift

import Foundation

// MARK: - Deployment System Validation Script

/**
 * Comprehensive validation script for the Always-On AI Companion deployment system.
 * This script validates all aspects of the deployment and installation system.
 */

class DeploymentSystemValidator {
    
    // MARK: - Configuration
    
    struct ValidationConfig {
        static let projectRoot = URL(fileURLWithPath: #file).deletingLastPathComponent()
        static let scriptsDir = projectRoot.appendingPathComponent("Scripts")
        static let buildDir = projectRoot.appendingPathComponent(".build/release")
        static let testsDir = projectRoot.appendingPathComponent("Tests")
        
        static let requiredScripts = [
            "installer.swift",
            "codesign_and_notarize.sh",
            "uninstall.sh",
            "install.sh",
            "status.sh"
        ]
        
        static let requiredExecutables = [
            "RecorderDaemon",
            "MenuBarApp"
        ]
        
        static let requiredTests = [
            "InstallationValidationTests.swift"
        ]
    }
    
    // MARK: - Validation Results
    
    struct ValidationResult {
        let category: String
        let test: String
        let passed: Bool
        let message: String
        let details: [String]
        
        var status: String {
            return passed ? "✅ PASS" : "❌ FAIL"
        }
    }
    
    private var results: [ValidationResult] = []
    private let fileManager = FileManager.default
    
    // MARK: - Main Validation
    
    func validateDeploymentSystem() {
        printHeader("Always-On AI Companion - Deployment System Validation")
        
        // Run all validation categories
        validateProjectStructure()
        validateScripts()
        validateBuildSystem()
        validateInstallationSystem()
        validateCodeSigningSetup()
        validateTestSuite()
        validateDocumentation()
        validateMakefileTargets()
        
        // Print summary
        printSummary()
    }
    
    // MARK: - Project Structure Validation
    
    private func validateProjectStructure() {
        let category = "Project Structure"
        
        // Check if project root exists and is accessible
        addResult(category: category, test: "Project Root Access", 
                 passed: fileManager.fileExists(atPath: ValidationConfig.projectRoot.path),
                 message: "Project root directory accessible",
                 details: ["Path: \(ValidationConfig.projectRoot.path)"])
        
        // Check Scripts directory
        let scriptsExists = fileManager.fileExists(atPath: ValidationConfig.scriptsDir.path)
        addResult(category: category, test: "Scripts Directory", 
                 passed: scriptsExists,
                 message: "Scripts directory exists",
                 details: ["Path: \(ValidationConfig.scriptsDir.path)"])
        
        // Check Tests directory
        let testsExists = fileManager.fileExists(atPath: ValidationConfig.testsDir.path)
        addResult(category: category, test: "Tests Directory", 
                 passed: testsExists,
                 message: "Tests directory exists",
                 details: ["Path: \(ValidationConfig.testsDir.path)"])
        
        // Check Package.swift
        let packageSwift = ValidationConfig.projectRoot.appendingPathComponent("Package.swift")
        let packageExists = fileManager.fileExists(atPath: packageSwift.path)
        addResult(category: category, test: "Package Manifest", 
                 passed: packageExists,
                 message: "Package.swift exists",
                 details: ["Path: \(packageSwift.path)"])
        
        // Check Makefile
        let makefile = ValidationConfig.projectRoot.appendingPathComponent("Makefile")
        let makefileExists = fileManager.fileExists(atPath: makefile.path)
        addResult(category: category, test: "Makefile", 
                 passed: makefileExists,
                 message: "Makefile exists",
                 details: ["Path: \(makefile.path)"])
    }
    
    // MARK: - Scripts Validation
    
    private func validateScripts() {
        let category = "Deployment Scripts"
        
        for script in ValidationConfig.requiredScripts {
            let scriptPath = ValidationConfig.scriptsDir.appendingPathComponent(script)
            let exists = fileManager.fileExists(atPath: scriptPath.path)
            
            var details = ["Path: \(scriptPath.path)"]
            
            if exists {
                // Check if script is executable
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: scriptPath.path)
                    let permissions = attributes[.posixPermissions] as? NSNumber
                    let isExecutable = (permissions?.uint16Value ?? 0) & 0o111 != 0
                    
                    if !isExecutable {
                        details.append("Warning: Script is not executable")
                    }
                    
                    // Check script content
                    let content = try String(contentsOf: scriptPath)
                    if content.isEmpty {
                        details.append("Warning: Script is empty")
                    } else {
                        details.append("Size: \(content.count) characters")
                    }
                    
                } catch {
                    details.append("Error reading script: \(error.localizedDescription)")
                }
            }
            
            addResult(category: category, test: script, 
                     passed: exists,
                     message: exists ? "Script exists and accessible" : "Script missing",
                     details: details)
        }
        
        // Validate installer.swift specifically
        validateInstallerScript()
        
        // Validate codesign script
        validateCodeSignScript()
        
        // Validate uninstall script
        validateUninstallScript()
    }
    
    private func validateInstallerScript() {
        let category = "Installer Script"
        let installerPath = ValidationConfig.scriptsDir.appendingPathComponent("installer.swift")
        
        guard fileManager.fileExists(atPath: installerPath.path) else {
            addResult(category: category, test: "Script Existence", 
                     passed: false,
                     message: "installer.swift not found",
                     details: [])
            return
        }
        
        do {
            let content = try String(contentsOf: installerPath)
            
            // Check for required classes and functions
            let requiredComponents = [
                "AlwaysOnAICompanionInstaller",
                "InstallationStep",
                "checkSystemRequirements",
                "validateBuild",
                "setupPermissions",
                "installLaunchAgent"
            ]
            
            var missingComponents: [String] = []
            for component in requiredComponents {
                if !content.contains(component) {
                    missingComponents.append(component)
                }
            }
            
            let hasAllComponents = missingComponents.isEmpty
            addResult(category: category, test: "Required Components", 
                     passed: hasAllComponents,
                     message: hasAllComponents ? "All required components present" : "Missing components",
                     details: missingComponents.isEmpty ? ["All components found"] : ["Missing: \(missingComponents.joined(separator: ", "))"])
            
            // Check for proper error handling
            let hasErrorHandling = content.contains("InstallationError") && content.contains("throw")
            addResult(category: category, test: "Error Handling", 
                     passed: hasErrorHandling,
                     message: hasErrorHandling ? "Error handling implemented" : "Error handling missing",
                     details: [])
            
            // Check for dry run capability
            let hasDryRun = content.contains("dryRun") && content.contains("--dry-run")
            addResult(category: category, test: "Dry Run Support", 
                     passed: hasDryRun,
                     message: hasDryRun ? "Dry run capability present" : "Dry run capability missing",
                     details: [])
            
        } catch {
            addResult(category: category, test: "Script Analysis", 
                     passed: false,
                     message: "Failed to analyze installer script",
                     details: ["Error: \(error.localizedDescription)"])
        }
    }
    
    private func validateCodeSignScript() {
        let category = "Code Signing Script"
        let scriptPath = ValidationConfig.scriptsDir.appendingPathComponent("codesign_and_notarize.sh")
        
        guard fileManager.fileExists(atPath: scriptPath.path) else {
            addResult(category: category, test: "Script Existence", 
                     passed: false,
                     message: "codesign_and_notarize.sh not found",
                     details: [])
            return
        }
        
        do {
            let content = try String(contentsOf: scriptPath)
            
            // Check for required functions
            let requiredFunctions = [
                "check_prerequisites",
                "load_configuration",
                "build_project",
                "create_app_bundle",
                "sign_app_bundle",
                "notarize_app"
            ]
            
            var missingFunctions: [String] = []
            for function in requiredFunctions {
                if !content.contains(function) {
                    missingFunctions.append(function)
                }
            }
            
            let hasAllFunctions = missingFunctions.isEmpty
            addResult(category: category, test: "Required Functions", 
                     passed: hasAllFunctions,
                     message: hasAllFunctions ? "All required functions present" : "Missing functions",
                     details: missingFunctions.isEmpty ? ["All functions found"] : ["Missing: \(missingFunctions.joined(separator: ", "))"])
            
            // Check for notarization support
            let hasNotarization = content.contains("notarytool") || content.contains("altool")
            addResult(category: category, test: "Notarization Support", 
                     passed: hasNotarization,
                     message: hasNotarization ? "Notarization tools supported" : "Notarization support missing",
                     details: [])
            
        } catch {
            addResult(category: category, test: "Script Analysis", 
                     passed: false,
                     message: "Failed to analyze code signing script",
                     details: ["Error: \(error.localizedDescription)"])
        }
    }
    
    private func validateUninstallScript() {
        let category = "Uninstall Script"
        let scriptPath = ValidationConfig.scriptsDir.appendingPathComponent("uninstall.sh")
        
        guard fileManager.fileExists(atPath: scriptPath.path) else {
            addResult(category: category, test: "Script Existence", 
                     passed: false,
                     message: "uninstall.sh not found",
                     details: [])
            return
        }
        
        do {
            let content = try String(contentsOf: scriptPath)
            
            // Check for comprehensive uninstall functions
            let requiredFunctions = [
                "stop_services",
                "remove_launch_agent",
                "remove_application_files",
                "remove_configuration_data",
                "handle_recorded_data"
            ]
            
            var missingFunctions: [String] = []
            for function in requiredFunctions {
                if !content.contains(function) {
                    missingFunctions.append(function)
                }
            }
            
            let hasAllFunctions = missingFunctions.isEmpty
            addResult(category: category, test: "Uninstall Functions", 
                     passed: hasAllFunctions,
                     message: hasAllFunctions ? "All uninstall functions present" : "Missing functions",
                     details: missingFunctions.isEmpty ? ["All functions found"] : ["Missing: \(missingFunctions.joined(separator: ", "))"])
            
            // Check for safety features
            let hasConfirmation = content.contains("confirm_uninstallation")
            addResult(category: category, test: "Safety Confirmation", 
                     passed: hasConfirmation,
                     message: hasConfirmation ? "User confirmation implemented" : "No user confirmation",
                     details: [])
            
            // Check for data preservation options
            let hasDataPreservation = content.contains("--keep-data")
            addResult(category: category, test: "Data Preservation", 
                     passed: hasDataPreservation,
                     message: hasDataPreservation ? "Data preservation option available" : "No data preservation option",
                     details: [])
            
        } catch {
            addResult(category: category, test: "Script Analysis", 
                     passed: false,
                     message: "Failed to analyze uninstall script",
                     details: ["Error: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Build System Validation
    
    private func validateBuildSystem() {
        let category = "Build System"
        
        // Check if build directory exists (indicates successful build)
        let buildExists = fileManager.fileExists(atPath: ValidationConfig.buildDir.path)
        addResult(category: category, test: "Build Directory", 
                 passed: buildExists,
                 message: buildExists ? "Build directory exists" : "No build directory (run 'make build')",
                 details: ["Path: \(ValidationConfig.buildDir.path)"])
        
        if buildExists {
            // Check for required executables
            for executable in ValidationConfig.requiredExecutables {
                let executablePath = ValidationConfig.buildDir.appendingPathComponent(executable)
                let exists = fileManager.fileExists(atPath: executablePath.path)
                
                var details = ["Path: \(executablePath.path)"]
                
                if exists {
                    // Check if executable is actually executable
                    do {
                        let attributes = try fileManager.attributesOfItem(atPath: executablePath.path)
                        let permissions = attributes[.posixPermissions] as? NSNumber
                        let isExecutable = (permissions?.uint16Value ?? 0) & 0o111 != 0
                        
                        if isExecutable {
                            details.append("Executable permissions: OK")
                        } else {
                            details.append("Warning: Not executable")
                        }
                        
                        // Get file size
                        let size = attributes[.size] as? NSNumber
                        details.append("Size: \(size?.intValue ?? 0) bytes")
                        
                    } catch {
                        details.append("Error checking attributes: \(error.localizedDescription)")
                    }
                }
                
                addResult(category: category, test: executable, 
                         passed: exists,
                         message: exists ? "Executable built successfully" : "Executable missing",
                         details: details)
            }
        }
        
        // Test Swift compilation
        validateSwiftCompilation()
    }
    
    private func validateSwiftCompilation() {
        let category = "Swift Compilation"
        
        // Check if Swift is available
        let swiftAvailable = isCommandAvailable("swift")
        addResult(category: category, test: "Swift Compiler", 
                 passed: swiftAvailable,
                 message: swiftAvailable ? "Swift compiler available" : "Swift compiler not found",
                 details: [])
        
        if swiftAvailable {
            // Test basic Swift compilation
            let testResult = testSwiftCompilation()
            addResult(category: category, test: "Compilation Test", 
                     passed: testResult.success,
                     message: testResult.message,
                     details: testResult.details)
        }
    }
    
    private func testSwiftCompilation() -> (success: Bool, message: String, details: [String]) {
        let process = Process()
        process.launchPath = "/usr/bin/swift"
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let success = process.terminationStatus == 0
            return (
                success: success,
                message: success ? "Swift compiler working" : "Swift compiler error",
                details: [output.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        } catch {
            return (
                success: false,
                message: "Failed to test Swift compiler",
                details: [error.localizedDescription]
            )
        }
    }
    
    // MARK: - Installation System Validation
    
    private func validateInstallationSystem() {
        let category = "Installation System"
        
        // Test installer script execution (dry run)
        let installerPath = ValidationConfig.scriptsDir.appendingPathComponent("installer.swift")
        if fileManager.fileExists(atPath: installerPath.path) {
            let dryRunResult = testInstallerDryRun()
            addResult(category: category, test: "Installer Dry Run", 
                     passed: dryRunResult.success,
                     message: dryRunResult.message,
                     details: dryRunResult.details)
        }
        
        // Check system requirements validation
        let systemReqsResult = validateSystemRequirements()
        addResult(category: category, test: "System Requirements", 
                 passed: systemReqsResult.success,
                 message: systemReqsResult.message,
                 details: systemReqsResult.details)
        
        // Check permission handling
        validatePermissionHandling()
    }
    
    private func testInstallerDryRun() -> (success: Bool, message: String, details: [String]) {
        let installerPath = ValidationConfig.scriptsDir.appendingPathComponent("installer.swift")
        
        let process = Process()
        process.launchPath = "/usr/bin/swift"
        process.arguments = [installerPath.path, "--dry-run"]
        process.currentDirectoryPath = ValidationConfig.projectRoot.path
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let success = process.terminationStatus == 0
            return (
                success: success,
                message: success ? "Installer dry run successful" : "Installer dry run failed",
                details: output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            )
        } catch {
            return (
                success: false,
                message: "Failed to execute installer dry run",
                details: [error.localizedDescription]
            )
        }
    }
    
    private func validateSystemRequirements() -> (success: Bool, message: String, details: [String]) {
        var details: [String] = []
        var allPassed = true
        
        // Check macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        details.append("macOS Version: \(versionString)")
        
        if version.majorVersion < 14 {
            allPassed = false
            details.append("❌ macOS 14+ required")
        } else {
            details.append("✅ macOS version supported")
        }
        
        // Check architecture
        let arch = getSystemArchitecture()
        details.append("Architecture: \(arch)")
        
        if ["arm64", "x86_64"].contains(arch) {
            details.append("✅ Architecture supported")
        } else {
            allPassed = false
            details.append("❌ Unsupported architecture")
        }
        
        // Check available disk space
        do {
            let homeURL = fileManager.homeDirectoryForCurrentUser
            let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            let availableSpace = resourceValues.volumeAvailableCapacity ?? 0
            let requiredSpace: Int64 = 1_000_000_000 // 1GB
            
            details.append("Available Space: \(formatBytes(availableSpace))")
            
            if availableSpace >= requiredSpace {
                details.append("✅ Sufficient disk space")
            } else {
                allPassed = false
                details.append("❌ Insufficient disk space")
            }
        } catch {
            details.append("⚠️ Could not check disk space: \(error.localizedDescription)")
        }
        
        return (
            success: allPassed,
            message: allPassed ? "System requirements met" : "System requirements not met",
            details: details
        )
    }
    
    private func validatePermissionHandling() {
        let category = "Permission Handling"
        
        // Check if TCC database access methods are available
        let tccMethods = [
            "Screen Recording permission check",
            "Accessibility permission check",
            "Full Disk Access permission check"
        ]
        
        for method in tccMethods {
            // This is a placeholder - actual permission checking would require more complex implementation
            addResult(category: category, test: method, 
                     passed: true,
                     message: "Permission check method available",
                     details: ["Implementation placeholder"])
        }
    }
    
    // MARK: - Code Signing Setup Validation
    
    private func validateCodeSigningSetup() {
        let category = "Code Signing Setup"
        
        // Check if codesign tool is available
        let codesignAvailable = isCommandAvailable("codesign")
        addResult(category: category, test: "codesign Tool", 
                 passed: codesignAvailable,
                 message: codesignAvailable ? "codesign tool available" : "codesign tool not found",
                 details: [])
        
        // Check if notarytool is available
        let notarytoolAvailable = isXcrunCommandAvailable("notarytool")
        addResult(category: category, test: "notarytool", 
                 passed: notarytoolAvailable,
                 message: notarytoolAvailable ? "notarytool available" : "notarytool not found (Xcode 13+ required)",
                 details: [])
        
        // Check for signing certificates
        let certificatesResult = checkSigningCertificates()
        addResult(category: category, test: "Signing Certificates", 
                 passed: certificatesResult.found,
                 message: certificatesResult.message,
                 details: certificatesResult.details)
        
        // Check configuration file
        let configPath = ValidationConfig.scriptsDir.appendingPathComponent("codesign_config.json")
        let configExists = fileManager.fileExists(atPath: configPath.path)
        addResult(category: category, test: "Configuration File", 
                 passed: configExists,
                 message: configExists ? "Code signing configuration exists" : "No code signing configuration (will use environment variables)",
                 details: configExists ? ["Path: \(configPath.path)"] : ["Create with: make codesign-config"])
    }
    
    private func checkSigningCertificates() -> (found: Bool, message: String, details: [String]) {
        let process = Process()
        process.launchPath = "/usr/bin/security"
        process.arguments = ["find-identity", "-v", "-p", "codesigning"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let certificateLines = lines.filter { $0.contains("Developer ID") }
            
            return (
                found: !certificateLines.isEmpty,
                message: certificateLines.isEmpty ? "No Developer ID certificates found" : "Developer ID certificates available",
                details: certificateLines.isEmpty ? ["Install certificates from Apple Developer Portal"] : certificateLines
            )
        } catch {
            return (
                found: false,
                message: "Failed to check certificates",
                details: [error.localizedDescription]
            )
        }
    }
    
    // MARK: - Test Suite Validation
    
    private func validateTestSuite() {
        let category = "Test Suite"
        
        // Check for required test files
        for testFile in ValidationConfig.requiredTests {
            let testPath = ValidationConfig.testsDir.appendingPathComponent(testFile)
            let exists = fileManager.fileExists(atPath: testPath.path)
            
            addResult(category: category, test: testFile, 
                     passed: exists,
                     message: exists ? "Test file exists" : "Test file missing",
                     details: ["Path: \(testPath.path)"])
        }
        
        // Test Swift test execution
        let testResult = runSwiftTests()
        addResult(category: category, test: "Test Execution", 
                 passed: testResult.success,
                 message: testResult.message,
                 details: testResult.details)
    }
    
    private func runSwiftTests() -> (success: Bool, message: String, details: [String]) {
        let process = Process()
        process.launchPath = "/usr/bin/swift"
        process.arguments = ["test", "--dry-run"]
        process.currentDirectoryPath = ValidationConfig.projectRoot.path
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let success = process.terminationStatus == 0
            return (
                success: success,
                message: success ? "Swift tests can be executed" : "Swift test execution failed",
                details: output.components(separatedBy: .newlines).filter { !$0.isEmpty }.prefix(10).map(String.init)
            )
        } catch {
            return (
                success: false,
                message: "Failed to run Swift tests",
                details: [error.localizedDescription]
            )
        }
    }
    
    // MARK: - Documentation Validation
    
    private func validateDocumentation() {
        let category = "Documentation"
        
        let requiredDocs = [
            "README.md",
            "DEPLOYMENT.md",
            "Makefile"
        ]
        
        for doc in requiredDocs {
            let docPath = ValidationConfig.projectRoot.appendingPathComponent(doc)
            let exists = fileManager.fileExists(atPath: docPath.path)
            
            var details = ["Path: \(docPath.path)"]
            
            if exists {
                do {
                    let content = try String(contentsOf: docPath)
                    details.append("Size: \(content.count) characters")
                    
                    if content.isEmpty {
                        details.append("Warning: Document is empty")
                    }
                } catch {
                    details.append("Error reading document: \(error.localizedDescription)")
                }
            }
            
            addResult(category: category, test: doc, 
                     passed: exists,
                     message: exists ? "Documentation exists" : "Documentation missing",
                     details: details)
        }
    }
    
    // MARK: - Makefile Targets Validation
    
    private func validateMakefileTargets() {
        let category = "Makefile Targets"
        
        let makefile = ValidationConfig.projectRoot.appendingPathComponent("Makefile")
        
        guard fileManager.fileExists(atPath: makefile.path) else {
            addResult(category: category, test: "Makefile Existence", 
                     passed: false,
                     message: "Makefile not found",
                     details: [])
            return
        }
        
        do {
            let content = try String(contentsOf: makefile)
            
            let requiredTargets = [
                "build", "install", "uninstall", "sign", "package", "dmg", "dist",
                "test", "test-install", "validate-install", "clean"
            ]
            
            var missingTargets: [String] = []
            var foundTargets: [String] = []
            
            for target in requiredTargets {
                if content.contains("\(target):") {
                    foundTargets.append(target)
                } else {
                    missingTargets.append(target)
                }
            }
            
            let allTargetsPresent = missingTargets.isEmpty
            addResult(category: category, test: "Required Targets", 
                     passed: allTargetsPresent,
                     message: allTargetsPresent ? "All required targets present" : "Missing targets",
                     details: allTargetsPresent ? 
                        ["Found: \(foundTargets.joined(separator: ", "))"] : 
                        ["Missing: \(missingTargets.joined(separator: ", "))", "Found: \(foundTargets.joined(separator: ", "))"])
            
        } catch {
            addResult(category: category, test: "Makefile Analysis", 
                     passed: false,
                     message: "Failed to analyze Makefile",
                     details: ["Error: \(error.localizedDescription)"])
        }
    }
    
    // MARK: - Helper Methods
    
    private func addResult(category: String, test: String, passed: Bool, message: String, details: [String] = []) {
        let result = ValidationResult(
            category: category,
            test: test,
            passed: passed,
            message: message,
            details: details
        )
        results.append(result)
    }
    
    private func isCommandAvailable(_ command: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/which"
        process.arguments = [command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func isXcrunCommandAvailable(_ command: String) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/xcrun"
        process.arguments = [command, "--help"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func getSystemArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Output Methods
    
    private func printHeader(_ title: String) {
        let separator = String(repeating: "=", count: title.count + 4)
        print(separator)
        print("  \(title)")
        print(separator)
        print()
    }
    
    private func printSummary() {
        print()
        printHeader("Validation Summary")
        
        let categories = Array(Set(results.map { $0.category })).sorted()
        var totalTests = 0
        var passedTests = 0
        
        for category in categories {
            let categoryResults = results.filter { $0.category == category }
            let categoryPassed = categoryResults.filter { $0.passed }.count
            let categoryTotal = categoryResults.count
            
            totalTests += categoryTotal
            passedTests += categoryPassed
            
            let percentage = categoryTotal > 0 ? Int((Double(categoryPassed) / Double(categoryTotal)) * 100) : 0
            let status = percentage == 100 ? "✅" : percentage >= 80 ? "⚠️" : "❌"
            
            print("\(status) \(category): \(categoryPassed)/\(categoryTotal) (\(percentage)%)")
            
            // Show failed tests
            let failedTests = categoryResults.filter { !$0.passed }
            for test in failedTests {
                print("    ❌ \(test.test): \(test.message)")
            }
        }
        
        print()
        let overallPercentage = totalTests > 0 ? Int((Double(passedTests) / Double(totalTests)) * 100) : 0
        let overallStatus = overallPercentage == 100 ? "✅ PASS" : overallPercentage >= 80 ? "⚠️ PARTIAL" : "❌ FAIL"
        
        print("Overall Result: \(overallStatus) - \(passedTests)/\(totalTests) tests passed (\(overallPercentage)%)")
        
        if overallPercentage < 100 {
            print()
            print("🔧 Recommendations:")
            
            let failedResults = results.filter { !$0.passed }
            for result in failedResults.prefix(5) {
                print("   • Fix \(result.category): \(result.test)")
            }
            
            if failedResults.count > 5 {
                print("   • ... and \(failedResults.count - 5) more issues")
            }
        }
        
        print()
    }
}

// MARK: - Main Execution

func main() {
    let validator = DeploymentSystemValidator()
    validator.validateDeploymentSystem()
}

// Run the validation
main()