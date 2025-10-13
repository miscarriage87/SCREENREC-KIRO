#!/usr/bin/env swift

import Foundation

/// Validation script for the documentation and help system
/// This script verifies that all documentation components are properly implemented and accessible

print("🔍 Validating Always-On AI Companion Documentation System...")
print("=" * 60)

var validationErrors: [String] = []
var validationWarnings: [String] = []

// MARK: - File Existence Validation

func validateFileExists(_ path: String, description: String) -> Bool {
    let fileManager = FileManager.default
    let exists = fileManager.fileExists(atPath: path)
    
    if exists {
        print("✅ \(description): \(path)")
    } else {
        let error = "❌ Missing \(description): \(path)"
        print(error)
        validationErrors.append(error)
    }
    
    return exists
}

func validateDirectoryExists(_ path: String, description: String) -> Bool {
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
    
    if exists && isDirectory.boolValue {
        print("✅ \(description): \(path)")
    } else {
        let error = "❌ Missing \(description): \(path)"
        print(error)
        validationErrors.append(error)
    }
    
    return exists && isDirectory.boolValue
}

// MARK: - Content Validation

func validateFileContent(_ path: String, requiredContent: [String], description: String) {
    guard let content = try? String(contentsOfFile: path) else {
        let error = "❌ Cannot read \(description): \(path)"
        print(error)
        validationErrors.append(error)
        return
    }
    
    var missingContent: [String] = []
    
    for required in requiredContent {
        if !content.localizedCaseInsensitiveContains(required) {
            missingContent.append(required)
        }
    }
    
    if missingContent.isEmpty {
        print("✅ \(description) content validation passed")
    } else {
        let error = "❌ \(description) missing required content: \(missingContent.joined(separator: ", "))"
        print(error)
        validationErrors.append(error)
    }
}

// MARK: - Documentation Structure Validation

print("\n📁 Validating Documentation Structure...")

let documentationDir = "AlwaysOnAICompanion/Documentation"
validateDirectoryExists(documentationDir, description: "Documentation directory")

let requiredDocFiles = [
    "USER_GUIDE.md": "User Guide",
    "DEVELOPER_GUIDE.md": "Developer Guide", 
    "TROUBLESHOOTING.md": "Troubleshooting Guide",
    "VIDEO_TUTORIALS.md": "Video Tutorial Scripts",
    "README.md": "Documentation Index"
]

for (filename, description) in requiredDocFiles {
    let path = "\(documentationDir)/\(filename)"
    validateFileExists(path, description: description)
}

// MARK: - Source Code Validation

print("\n🔧 Validating Source Code Components...")

let sourceFiles = [
    "AlwaysOnAICompanion/Sources/Shared/Help/HelpSystem.swift": "Help System Core",
    "AlwaysOnAICompanion/Sources/MenuBarApp/HelpView.swift": "Help UI Components",
    "AlwaysOnAICompanion/Tests/DocumentationSystemTests.swift": "Documentation Tests"
]

for (path, description) in sourceFiles {
    validateFileExists(path, description: description)
}

// MARK: - Content Quality Validation

print("\n📝 Validating Documentation Content Quality...")

// Validate User Guide content
let userGuidePath = "\(documentationDir)/USER_GUIDE.md"
if validateFileExists(userGuidePath, description: "User Guide") {
    validateFileContent(userGuidePath, requiredContent: [
        "Table of Contents",
        "Installation",
        "Privacy Controls", 
        "Troubleshooting",
        "System Requirements"
    ], description: "User Guide")
}

// Validate Developer Guide content
let developerGuidePath = "\(documentationDir)/DEVELOPER_GUIDE.md"
if validateFileExists(developerGuidePath, description: "Developer Guide") {
    validateFileContent(developerGuidePath, requiredContent: [
        "Plugin Development",
        "API Reference",
        "Architecture Overview",
        "Testing Guidelines"
    ], description: "Developer Guide")
}

// Validate Troubleshooting Guide content
let troubleshootingPath = "\(documentationDir)/TROUBLESHOOTING.md"
if validateFileExists(troubleshootingPath, description: "Troubleshooting Guide") {
    validateFileContent(troubleshootingPath, requiredContent: [
        "Quick Diagnostics",
        "Performance Issues",
        "Installation Issues",
        "Recording Problems"
    ], description: "Troubleshooting Guide")
}

// MARK: - Help System Code Validation

print("\n💻 Validating Help System Implementation...")

let helpSystemPath = "AlwaysOnAICompanion/Sources/Shared/Help/HelpSystem.swift"
if validateFileExists(helpSystemPath, description: "Help System") {
    validateFileContent(helpSystemPath, requiredContent: [
        "class HelpSystem",
        "HelpContext",
        "showHelp",
        "getContextualHelp",
        "searchHelp"
    ], description: "Help System implementation")
}

let helpViewPath = "AlwaysOnAICompanion/Sources/MenuBarApp/HelpView.swift"
if validateFileExists(helpViewPath, description: "Help View") {
    validateFileContent(helpViewPath, requiredContent: [
        "struct HelpView",
        "NavigationSplitView",
        "searchable",
        "HelpContextHeader"
    ], description: "Help View implementation")
}

// MARK: - Test Coverage Validation

print("\n🧪 Validating Test Coverage...")

let testsPath = "AlwaysOnAICompanion/Tests/DocumentationSystemTests.swift"
if validateFileExists(testsPath, description: "Documentation Tests") {
    validateFileContent(testsPath, requiredContent: [
        "class DocumentationSystemTests",
        "testHelpSystemInitialization",
        "testShowHelpForContext",
        "testSearchHelp",
        "testDocumentationFilesExist"
    ], description: "Documentation test coverage")
}

// MARK: - Integration Validation

print("\n🔗 Validating System Integration...")

let menuBarControllerPath = "AlwaysOnAICompanion/Sources/MenuBarApp/MenuBarController.swift"
if validateFileExists(menuBarControllerPath, description: "Menu Bar Controller") {
    validateFileContent(menuBarControllerPath, requiredContent: [
        "openHelp",
        "showContextualHelp",
        "helpWindow"
    ], description: "Help system integration")
}

// MARK: - Accessibility Validation

print("\n♿ Validating Accessibility Features...")

// Check for accessibility considerations in help system
if let helpViewContent = try? String(contentsOfFile: helpViewPath) {
    let accessibilityFeatures = [
        "navigationTitle": "Navigation titles for screen readers",
        "searchable": "Searchable interface",
        ".accessibility": "Accessibility modifiers"
    ]
    
    for (feature, description) in accessibilityFeatures {
        if helpViewContent.contains(feature) {
            print("✅ \(description) implemented")
        } else {
            let warning = "⚠️  \(description) may need attention"
            print(warning)
            validationWarnings.append(warning)
        }
    }
}

// MARK: - Documentation Completeness Check

print("\n📊 Checking Documentation Completeness...")

func checkDocumentationCompleteness() {
    let expectedSections = [
        "Installation": ["USER_GUIDE.md"],
        "Configuration": ["USER_GUIDE.md"],
        "Privacy": ["USER_GUIDE.md", "TROUBLESHOOTING.md"],
        "Performance": ["TROUBLESHOOTING.md", "USER_GUIDE.md"],
        "Plugin Development": ["DEVELOPER_GUIDE.md"],
        "API Reference": ["DEVELOPER_GUIDE.md"],
        "Video Tutorials": ["VIDEO_TUTORIALS.md"]
    ]
    
    for (section, files) in expectedSections {
        var sectionCovered = false
        
        for filename in files {
            let path = "\(documentationDir)/\(filename)"
            if let content = try? String(contentsOfFile: path),
               content.localizedCaseInsensitiveContains(section) {
                sectionCovered = true
                break
            }
        }
        
        if sectionCovered {
            print("✅ \(section) documentation found")
        } else {
            let warning = "⚠️  \(section) documentation may be incomplete"
            print(warning)
            validationWarnings.append(warning)
        }
    }
}

checkDocumentationCompleteness()

// MARK: - Video Tutorial Validation

print("\n🎥 Validating Video Tutorial Scripts...")

let videoTutorialsPath = "\(documentationDir)/VIDEO_TUTORIALS.md"
if validateFileExists(videoTutorialsPath, description: "Video Tutorial Scripts") {
    validateFileContent(videoTutorialsPath, requiredContent: [
        "Tutorial 1.1: Installation and Setup",
        "Tutorial 1.2: Privacy Controls",
        "Tutorial 2.1: Activity Reports",
        "Production Guidelines",
        "Script"
    ], description: "Video tutorial content")
}

// MARK: - Final Validation Summary

print("\n" + "=" * 60)
print("📋 VALIDATION SUMMARY")
print("=" * 60)

if validationErrors.isEmpty && validationWarnings.isEmpty {
    print("🎉 All validations passed! Documentation system is complete and properly implemented.")
    exit(0)
} else {
    if !validationErrors.isEmpty {
        print("❌ ERRORS FOUND (\(validationErrors.count)):")
        for error in validationErrors {
            print("   \(error)")
        }
    }
    
    if !validationWarnings.isEmpty {
        print("⚠️  WARNINGS (\(validationWarnings.count)):")
        for warning in validationWarnings {
            print("   \(warning)")
        }
    }
    
    print("\n📝 RECOMMENDATIONS:")
    
    if !validationErrors.isEmpty {
        print("1. Address all errors before proceeding with task completion")
        print("2. Ensure all required files are created and properly structured")
        print("3. Verify all source code components are implemented")
    }
    
    if !validationWarnings.isEmpty {
        print("4. Review warnings for potential improvements")
        print("5. Consider enhancing accessibility features")
        print("6. Ensure comprehensive documentation coverage")
    }
    
    print("\n🔧 NEXT STEPS:")
    print("1. Fix any missing files or implementation gaps")
    print("2. Run the test suite to verify functionality")
    print("3. Test the help system integration in the menu bar app")
    print("4. Review documentation for accuracy and completeness")
    
    if !validationErrors.isEmpty {
        exit(1)
    } else {
        exit(0) // Warnings only, still successful
    }
}

// MARK: - Utility Extensions

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}