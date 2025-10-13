// Shared module for Always-On AI Companion
// This file serves as the main entry point for the shared module

import Foundation

// Re-export all public types and classes for easy importing
@_exported import struct Foundation.URL
@_exported import struct Foundation.Date
@_exported import struct Foundation.UUID
@_exported import class Foundation.Timer
@_exported import class Foundation.FileManager
@_exported import class Foundation.ProcessInfo

// Version information
public struct AlwaysOnAICompanionVersion {
    public static let major = 1
    public static let minor = 0
    public static let patch = 0
    
    public static var string: String {
        return "\(major).\(minor).\(patch)"
    }
    
    public static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    public static var fullVersion: String {
        return "\(string) (\(buildNumber))"
    }
}

// System information
public struct SystemInfo {
    public static var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    public static var isAppleSilicon: Bool {
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        
        var result: Int32 = 0
        sysctlbyname("hw.optional.arm64", &result, &size, nil, 0)
        
        return result == 1
    }
    
    public static var architecture: String {
        return isAppleSilicon ? "Apple Silicon" : "Intel"
    }
    
    public static var systemDescription: String {
        return "macOS \(macOSVersion) (\(architecture))"
    }
}

// Re-export monitoring types for easier access
public typealias SystemMonitorType = SystemMonitor
public typealias LogManagerType = LogManager

// Logging utilities - using ConfigLogLevel from ConfigurationManager

public class Logger {
    public static let shared = Logger()
    
    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.alwaysonai.logging", qos: .utility)
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    public func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logQueue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let filename = URL(fileURLWithPath: file).lastPathComponent
            let logMessage = "\(timestamp) ℹ️ [INFO] \(filename):\(line) \(function) - \(message)"
            
            print(logMessage)
            
            // TODO: Write to log file in future implementation
        }
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logQueue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let filename = URL(fileURLWithPath: file).lastPathComponent
            let logMessage = "\(timestamp) 🔍 [DEBUG] \(filename):\(line) \(function) - \(message)"
            print(logMessage)
        }
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logQueue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let filename = URL(fileURLWithPath: file).lastPathComponent
            let logMessage = "\(timestamp) ⚠️ [WARNING] \(filename):\(line) \(function) - \(message)"
            print(logMessage)
        }
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logQueue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let filename = URL(fileURLWithPath: file).lastPathComponent
            let logMessage = "\(timestamp) ❌ [ERROR] \(filename):\(line) \(function) - \(message)"
            print(logMessage)
        }
    }
}