import Foundation
import CoreGraphics

/// Plugin for parsing terminal and command-line applications
public class TerminalParsingPlugin: BaseParsingPlugin {
    
    // MARK: - Session Tracking
    private var currentSession: TerminalSession?
    private var commandHistory: [CommandExecution] = []
    private var sessionStartTime: Date?
    private var lastPromptTime: Date?
    
    // MARK: - Workflow Analysis
    private var workflowPatterns: [WorkflowPattern] = []
    private var commandSequences: [CommandSequence] = []
    
    public init() {
        super.init(
            identifier: "com.alwayson.plugins.terminal",
            name: "Terminal Application Parser",
            version: "1.0.0",
            description: "Enhanced parsing for terminal applications and command-line interfaces with session tracking and workflow analysis",
            supportedApplications: [
                "com.apple.Terminal",
                "com.googlecode.iterm2",
                "com.github.wez.wezterm",
                "org.alacritty",
                "com.microsoft.VSCode", // For integrated terminals
                "com.jetbrains.*" // For IDE terminals
            ]
        )
        
        initializeWorkflowPatterns()
    }
    
    // MARK: - Terminal-Specific Parsing
    
    public override func enhanceOCRResults(
        _ results: [OCRResult],
        context: ApplicationContext,
        frame: CGImage
    ) async throws -> [EnhancedOCRResult] {
        var enhancedResults = try await super.enhanceOCRResults(results, context: context, frame: frame)
        
        // Initialize session if not already started
        if currentSession == nil {
            startSession(context: context)
        }
        
        // Update session activity
        currentSession?.lastActivity = Date()
        
        // Detect terminal-specific elements with session tracking
        enhancedResults.append(contentsOf: detectCommandElements(in: results))
        enhancedResults.append(contentsOf: detectOutputElements(in: results))
        enhancedResults.append(contentsOf: detectPromptElements(in: results))
        enhancedResults.append(contentsOf: detectErrorElements(in: results))
        enhancedResults.append(contentsOf: detectPathElements(in: results))
        enhancedResults.append(contentsOf: detectSessionElements(in: results))
        
        return enhancedResults
    }
    
    public override func extractStructuredData(
        from results: [OCRResult],
        context: ApplicationContext
    ) async throws -> [StructuredDataElement] {
        var structuredData = try await super.extractStructuredData(from: results, context: context)
        
        // Extract terminal-specific structured data with workflow analysis
        structuredData.append(contentsOf: extractCommandHistory(from: results))
        structuredData.append(contentsOf: extractFileOperations(from: results))
        structuredData.append(contentsOf: extractSystemInfo(from: results))
        structuredData.append(contentsOf: extractProcessInfo(from: results))
        structuredData.append(contentsOf: extractWorkflowPatterns(from: results))
        structuredData.append(contentsOf: extractSessionMetrics(from: results))
        
        return structuredData
    }
    
    // MARK: - Command Detection
    
    private func detectCommandElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect command lines (usually start with $ or % or contain common commands)
            if isCommandLine(text) {
                let command = extractCommand(from: text)
                
                // Track command execution in session
                trackCommandExecution(command, timestamp: Date())
                
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "command_line",
                    structuredData: [
                        "command": command.command,
                        "arguments": command.arguments,
                        "command_type": classifyCommand(command.command),
                        "is_sudo": command.isSudo,
                        "working_directory": currentSession?.workingDirectory ?? "",
                        "session_id": currentSession?.id ?? "",
                        "command_sequence_position": commandHistory.count
                    ]
                ))
            }
            
            // Detect command options and flags
            if isCommandOption(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "command_option",
                    structuredData: [
                        "option_type": classifyOption(text),
                        "is_long_form": isLongFormOption(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectOutputElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect command output
            if isCommandOutput(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "command_output",
                    structuredData: [
                        "output_type": classifyOutput(text),
                        "contains_data": containsStructuredData(text)
                    ]
                ))
            }
            
            // Detect file listings
            if isFileListingLine(text) {
                let fileInfo = parseFileListingLine(text)
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "file_listing",
                    structuredData: [
                        "filename": fileInfo.name,
                        "permissions": fileInfo.permissions,
                        "size": fileInfo.size,
                        "is_directory": fileInfo.isDirectory,
                        "modified_date": fileInfo.modifiedDate
                    ]
                ))
            }
            
            // Detect process listings
            if isProcessListingLine(text) {
                let processInfo = parseProcessListingLine(text)
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "process_listing",
                    structuredData: [
                        "pid": processInfo.pid,
                        "process_name": processInfo.name,
                        "cpu_usage": processInfo.cpuUsage,
                        "memory_usage": processInfo.memoryUsage
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectPromptElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isPrompt(text) {
                let promptInfo = parsePrompt(text)
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "shell_prompt",
                    structuredData: [
                        "username": promptInfo.username,
                        "hostname": promptInfo.hostname,
                        "current_directory": promptInfo.currentDirectory,
                        "shell_type": promptInfo.shellType,
                        "is_root": promptInfo.isRoot
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectErrorElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isErrorMessage(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "error_message",
                    structuredData: [
                        "error_type": classifyError(text),
                        "severity": determineErrorSeverity(text),
                        "command_related": extractRelatedCommand(text)
                    ]
                ))
            }
            
            if isWarningMessage(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "warning_message",
                    structuredData: [
                        "warning_type": classifyWarning(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectPathElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isFilePath(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "file_path",
                    structuredData: [
                        "path_type": classifyPath(text),
                        "is_absolute": isAbsolutePath(text),
                        "file_extension": extractFileExtension(text),
                        "directory_depth": calculateDirectoryDepth(text)
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    private func detectSessionElements(in results: [OCRResult]) -> [EnhancedOCRResult] {
        var enhanced: [EnhancedOCRResult] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Detect session start indicators
            if isSessionStart(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "session_start",
                    structuredData: [
                        "session_type": detectSessionType(text),
                        "timestamp": Date().timeIntervalSince1970
                    ]
                ))
            }
            
            // Detect session end indicators
            if isSessionEnd(text) {
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "session_end",
                    structuredData: [
                        "session_id": currentSession?.id ?? "",
                        "duration": currentSession?.lastActivity.timeIntervalSince(currentSession?.startTime ?? Date()) ?? 0
                    ]
                ))
                endSession()
            }
            
            // Detect command completion
            if isCommandCompletion(text) {
                let exitCode = extractExitCode(text)
                updateLastCommandExitCode(exitCode)
                
                enhanced.append(createEnhancedResult(
                    from: result,
                    semanticType: "command_completion",
                    structuredData: [
                        "exit_code": exitCode,
                        "success": exitCode == 0
                    ]
                ))
            }
        }
        
        return enhanced
    }
    
    // MARK: - Data Extraction
    
    private func extractCommandHistory(from results: [OCRResult]) -> [StructuredDataElement] {
        var commands: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isCommandLine(text) {
                let command = extractCommand(from: text)
                
                commands.append(StructuredDataElement(
                    id: "\(identifier)_command_\(UUID().uuidString)",
                    type: "terminal_command",
                    value: command.fullCommand,
                    metadata: [
                        "command": command.command,
                        "arguments": command.arguments,
                        "command_type": classifyCommand(command.command),
                        "is_sudo": command.isSudo,
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return commands
    }
    
    private func extractFileOperations(from results: [OCRResult]) -> [StructuredDataElement] {
        var operations: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isFileOperation(text) {
                let operation = parseFileOperation(text)
                
                operations.append(StructuredDataElement(
                    id: "\(identifier)_file_op_\(UUID().uuidString)",
                    type: "file_operation",
                    value: operation.operation,
                    metadata: [
                        "operation_type": operation.type,
                        "source_path": operation.sourcePath,
                        "target_path": operation.targetPath,
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return operations
    }
    
    private func extractSystemInfo(from results: [OCRResult]) -> [StructuredDataElement] {
        var systemInfo: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isSystemInfoLine(text) {
                let info = parseSystemInfo(text)
                
                systemInfo.append(StructuredDataElement(
                    id: "\(identifier)_system_info_\(UUID().uuidString)",
                    type: "system_info",
                    value: info.value,
                    metadata: [
                        "info_type": info.type,
                        "metric": info.metric,
                        "unit": info.unit,
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return systemInfo
    }
    
    private func extractProcessInfo(from results: [OCRResult]) -> [StructuredDataElement] {
        var processes: [StructuredDataElement] = []
        
        for result in results {
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isProcessListingLine(text) {
                let processInfo = parseProcessListingLine(text)
                
                processes.append(StructuredDataElement(
                    id: "\(identifier)_process_\(UUID().uuidString)",
                    type: "process_info",
                    value: processInfo.name,
                    metadata: [
                        "pid": processInfo.pid,
                        "cpu_usage": processInfo.cpuUsage,
                        "memory_usage": processInfo.memoryUsage,
                        "confidence": result.confidence
                    ],
                    boundingBox: result.boundingBox
                ))
            }
        }
        
        return processes
    }
    
    private func extractWorkflowPatterns(from results: [OCRResult]) -> [StructuredDataElement] {
        var patterns: [StructuredDataElement] = []
        
        // Extract detected workflow patterns
        for pattern in workflowPatterns {
            patterns.append(StructuredDataElement(
                id: "\(identifier)_workflow_\(UUID().uuidString)",
                type: "workflow_pattern",
                value: pattern.type,
                metadata: [
                    "confidence": pattern.confidence,
                    "description": pattern.description,
                    "session_id": currentSession?.id ?? ""
                ],
                boundingBox: CGRect.zero // Workflow patterns don't have specific bounding boxes
            ))
        }
        
        return patterns
    }
    
    private func extractSessionMetrics(from results: [OCRResult]) -> [StructuredDataElement] {
        var metrics: [StructuredDataElement] = []
        
        if let session = currentSession {
            let sessionDuration = Date().timeIntervalSince(session.startTime)
            let commandsPerMinute = Double(session.commands.count) / (sessionDuration / 60.0)
            
            metrics.append(StructuredDataElement(
                id: "\(identifier)_session_metrics_\(UUID().uuidString)",
                type: "session_metrics",
                value: "active_session",
                metadata: [
                    "session_id": session.id,
                    "duration_seconds": sessionDuration,
                    "command_count": session.commands.count,
                    "commands_per_minute": commandsPerMinute,
                    "working_directory": session.workingDirectory,
                    "productivity_score": calculateProductivityScore(session.commands),
                    "error_rate": calculateErrorRate(session.commands)
                ],
                boundingBox: CGRect.zero
            ))
        }
        
        return metrics
    }
    
    // MARK: - Session Management
    
    public func startSession(context: ApplicationContext) {
        currentSession = TerminalSession(
            id: UUID().uuidString,
            startTime: Date(),
            context: context,
            workingDirectory: extractWorkingDirectoryFromContext(context)
        )
        sessionStartTime = Date()
        commandHistory.removeAll()
        print("Started terminal session: \(currentSession?.id ?? "unknown")")
    }
    
    public func endSession() {
        if let session = currentSession {
            session.endTime = Date()
            analyzeSessionWorkflow(session)
            print("Ended terminal session: \(session.id)")
        }
        currentSession = nil
        sessionStartTime = nil
    }
    
    private func trackCommandExecution(_ command: CommandInfo, timestamp: Date, output: String? = nil) {
        let execution = CommandExecution(
            id: UUID().uuidString,
            command: command,
            timestamp: timestamp,
            sessionId: currentSession?.id ?? "unknown",
            workingDirectory: currentSession?.workingDirectory ?? "",
            output: output,
            exitCode: nil as Int? // Will be updated when we detect completion
        )
        
        commandHistory.append(execution)
        updateCommandSequences(execution)
        
        // Update session
        currentSession?.commands.append(execution)
        currentSession?.lastActivity = timestamp
    }
    
    private func updateCommandSequences(_ execution: CommandExecution) {
        // Look for command patterns and sequences
        if commandHistory.count >= 2 {
            let recentCommands = Array(commandHistory.suffix(5))
            detectWorkflowPatterns(in: recentCommands)
        }
    }
    
    private func analyzeSessionWorkflow(_ session: TerminalSession) {
        let workflow = WorkflowAnalysis(
            sessionId: session.id,
            duration: session.endTime?.timeIntervalSince(session.startTime) ?? 0,
            commandCount: session.commands.count,
            patterns: identifyWorkflowPatterns(in: session.commands),
            productivity: calculateProductivityScore(session.commands),
            errorRate: calculateErrorRate(session.commands)
        )
        
        print("Session workflow analysis: \(workflow)")
    }
    
    // MARK: - Helper Methods and Structures
    
    public struct CommandInfo {
        let fullCommand: String
        let command: String
        let arguments: [String]
        let isSudo: Bool
    }
    
    private struct FileInfo {
        let name: String
        let permissions: String
        let size: String
        let isDirectory: Bool
        let modifiedDate: String
    }
    
    private struct ProcessInfo {
        let pid: String
        let name: String
        let cpuUsage: String
        let memoryUsage: String
    }
    
    private struct PromptInfo {
        let username: String
        let hostname: String
        let currentDirectory: String
        let shellType: String
        let isRoot: Bool
    }
    
    private struct FileOperation {
        let operation: String
        let type: String
        let sourcePath: String
        let targetPath: String
    }
    
    private struct SystemInfo {
        let type: String
        let metric: String
        let value: String
        let unit: String
    }
    
    // MARK: - Detection Methods
    
    private func isCommandLine(_ text: String) -> Bool {
        // Check for common prompt indicators
        if text.hasPrefix("$ ") || text.hasPrefix("% ") || text.hasPrefix("# ") {
            return true
        }
        
        // Check for common commands
        let commonCommands = ["ls", "cd", "pwd", "mkdir", "rm", "cp", "mv", "cat", "grep", "find", 
                             "ps", "top", "kill", "chmod", "chown", "sudo", "git", "npm", "pip", 
                             "docker", "kubectl", "ssh", "scp", "rsync", "tar", "zip", "unzip"]
        
        let words = text.split(separator: " ")
        if let firstWord = words.first {
            return commonCommands.contains(String(firstWord))
        }
        
        return false
    }
    
    private func extractCommand(from text: String) -> CommandInfo {
        var cleanText = text
        
        // Remove prompt indicators
        if cleanText.hasPrefix("$ ") || cleanText.hasPrefix("% ") || cleanText.hasPrefix("# ") {
            cleanText = String(cleanText.dropFirst(2))
        }
        
        let components = cleanText.split(separator: " ", omittingEmptySubsequences: true)
        guard !components.isEmpty else {
            return CommandInfo(fullCommand: text, command: "", arguments: [], isSudo: false)
        }
        
        var isSudo = false
        var commandIndex = 0
        
        if components[0] == "sudo" {
            isSudo = true
            commandIndex = 1
        }
        
        let command = commandIndex < components.count ? String(components[commandIndex]) : ""
        let arguments = Array(components.dropFirst(commandIndex + 1)).map(String.init)
        
        return CommandInfo(
            fullCommand: cleanText,
            command: command,
            arguments: arguments,
            isSudo: isSudo
        )
    }
    
    private func classifyCommand(_ command: String) -> String {
        switch command {
        case "ls", "ll", "la", "dir":
            return "file_listing"
        case "cd", "pushd", "popd":
            return "navigation"
        case "mkdir", "rmdir", "rm", "cp", "mv":
            return "file_management"
        case "cat", "less", "more", "head", "tail":
            return "file_viewing"
        case "grep", "find", "locate", "which":
            return "search"
        case "ps", "top", "htop", "kill", "killall":
            return "process_management"
        case "chmod", "chown", "chgrp":
            return "permissions"
        case "git":
            return "version_control"
        case "npm", "pip", "brew", "apt", "yum":
            return "package_management"
        case "docker", "kubectl":
            return "containerization"
        case "ssh", "scp", "rsync":
            return "network"
        case "tar", "zip", "unzip", "gzip":
            return "compression"
        default:
            return "other"
        }
    }
    
    private func isCommandOption(_ text: String) -> Bool {
        return text.hasPrefix("-") && text.count > 1
    }
    
    private func classifyOption(_ text: String) -> String {
        if text.hasPrefix("--") {
            return "long_option"
        } else if text.hasPrefix("-") {
            return "short_option"
        }
        return "unknown"
    }
    
    private func isLongFormOption(_ text: String) -> Bool {
        return text.hasPrefix("--")
    }
    
    private func isCommandOutput(_ text: String) -> Bool {
        // Command output typically doesn't start with prompt indicators
        return !text.hasPrefix("$ ") && !text.hasPrefix("% ") && !text.hasPrefix("# ") &&
               text.count > 0 && !isCommandLine(text)
    }
    
    private func classifyOutput(_ text: String) -> String {
        if isFileListingLine(text) {
            return "file_listing"
        } else if isProcessListingLine(text) {
            return "process_listing"
        } else if isErrorMessage(text) {
            return "error"
        } else if containsStructuredData(text) {
            return "structured_data"
        }
        return "text"
    }
    
    private func containsStructuredData(_ text: String) -> Bool {
        // Check for common structured data patterns
        return text.contains(":") || text.contains("=") || text.matches(#"\d+\s+\d+"#)
    }
    
    private func isFileListingLine(_ text: String) -> Bool {
        // Check for ls -l format: permissions, links, owner, group, size, date, name
        return text.matches(#"^[drwx-]{10}\s+\d+"#) ||
               text.matches(#"^\d+\s+[A-Za-z]{3}\s+\d+"#) // Simple ls format
    }
    
    private func parseFileListingLine(_ text: String) -> FileInfo {
        let components = text.split(separator: " ", omittingEmptySubsequences: true)
        
        if text.matches(#"^[drwx-]{10}"#) {
            // Long format: permissions links owner group size month day time/year name
            return FileInfo(
                name: components.count > 8 ? String(components[8]) : "",
                permissions: components.count > 0 ? String(components[0]) : "",
                size: components.count > 4 ? String(components[4]) : "",
                isDirectory: text.hasPrefix("d"),
                modifiedDate: components.count > 7 ? "\(components[5]) \(components[6]) \(components[7])" : ""
            )
        } else {
            // Simple format
            return FileInfo(
                name: components.last.map(String.init) ?? "",
                permissions: "",
                size: "",
                isDirectory: false,
                modifiedDate: ""
            )
        }
    }
    
    private func isProcessListingLine(_ text: String) -> Bool {
        // Check for ps format: PID TTY TIME CMD or top format
        return text.matches(#"^\s*\d+\s+"#) && 
               (text.contains("TTY") || text.contains("%CPU") || text.contains("CMD"))
    }
    
    private func parseProcessListingLine(_ text: String) -> ProcessInfo {
        let components = text.split(separator: " ", omittingEmptySubsequences: true)
        
        return ProcessInfo(
            pid: components.count > 0 ? String(components[0]) : "",
            name: components.last.map(String.init) ?? "",
            cpuUsage: components.count > 2 ? String(components[2]) : "",
            memoryUsage: components.count > 3 ? String(components[3]) : ""
        )
    }
    
    private func isPrompt(_ text: String) -> Bool {
        return text.matches(#"[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+:"#) || // user@host:
               text.matches(#"[a-zA-Z0-9_-]+\s*[$%#]\s*$"#) // user $ or user %
    }
    
    private func parsePrompt(_ text: String) -> PromptInfo {
        if text.contains("@") {
            let parts = text.split(separator: "@")
            let username = parts.count > 0 ? String(parts[0]) : ""
            let remaining = parts.count > 1 ? String(parts[1]) : ""
            
            let hostParts = remaining.split(separator: ":")
            let hostname = hostParts.count > 0 ? String(hostParts[0]) : ""
            let directory = hostParts.count > 1 ? String(hostParts[1]).trimmingCharacters(in: CharacterSet(charactersIn: " $%#")) : ""
            
            return PromptInfo(
                username: username,
                hostname: hostname,
                currentDirectory: directory,
                shellType: text.contains("$") ? "bash" : "zsh",
                isRoot: text.contains("#")
            )
        }
        
        return PromptInfo(
            username: "",
            hostname: "",
            currentDirectory: "",
            shellType: "unknown",
            isRoot: text.contains("#")
        )
    }
    
    private func isErrorMessage(_ text: String) -> Bool {
        let errorKeywords = ["error", "Error", "ERROR", "failed", "Failed", "FAILED", 
                           "cannot", "Cannot", "CANNOT", "not found", "Not found", 
                           "permission denied", "Permission denied"]
        
        return errorKeywords.contains { text.contains($0) }
    }
    
    private func classifyError(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("permission denied") {
            return "permission_error"
        } else if lowercased.contains("not found") || lowercased.contains("no such file") {
            return "file_not_found"
        } else if lowercased.contains("command not found") {
            return "command_not_found"
        } else if lowercased.contains("syntax error") {
            return "syntax_error"
        } else if lowercased.contains("connection") {
            return "network_error"
        }
        
        return "general_error"
    }
    
    private func determineErrorSeverity(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("fatal") || lowercased.contains("critical") {
            return "critical"
        } else if lowercased.contains("error") {
            return "error"
        } else if lowercased.contains("warning") {
            return "warning"
        }
        
        return "info"
    }
    
    private func extractRelatedCommand(_ text: String) -> String {
        // Try to extract command name from error messages
        let patterns = [
            #"command '([^']+)' not found"#,
            #"([a-zA-Z0-9_-]+): command not found"#,
            #"([a-zA-Z0-9_-]+): (.+)"#
        ]
        
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                // This is a simplified extraction - in practice, you'd use proper regex groups
                let match = String(text[range])
                return match.components(separatedBy: ":").first ?? ""
            }
        }
        
        return ""
    }
    
    private func isWarningMessage(_ text: String) -> Bool {
        let warningKeywords = ["warning", "Warning", "WARNING", "caution", "Caution"]
        return warningKeywords.contains { text.contains($0) }
    }
    
    private func classifyWarning(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("deprecated") {
            return "deprecation_warning"
        } else if lowercased.contains("security") {
            return "security_warning"
        } else if lowercased.contains("performance") {
            return "performance_warning"
        }
        
        return "general_warning"
    }
    
    private func isFilePath(_ text: String) -> Bool {
        return text.hasPrefix("/") || // Absolute path
               text.hasPrefix("./") || // Relative path
               text.hasPrefix("../") || // Parent directory
               text.hasPrefix("~") || // Home directory
               text.matches(#"[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+"#) // General path pattern
    }
    
    private func classifyPath(_ text: String) -> String {
        if text.hasPrefix("/") {
            return "absolute"
        } else if text.hasPrefix("./") {
            return "relative_current"
        } else if text.hasPrefix("../") {
            return "relative_parent"
        } else if text.hasPrefix("~") {
            return "home_relative"
        }
        return "relative"
    }
    
    private func isAbsolutePath(_ text: String) -> Bool {
        return text.hasPrefix("/")
    }
    
    private func extractFileExtension(_ text: String) -> String {
        if let lastDot = text.lastIndex(of: ".") {
            let fileExtension = String(text[text.index(after: lastDot)...])
            // Only return if it looks like a valid extension (no spaces, reasonable length)
            if !fileExtension.contains(" ") && fileExtension.count <= 10 {
                return fileExtension
            }
        }
        return ""
    }
    
    private func calculateDirectoryDepth(_ text: String) -> Int {
        return text.components(separatedBy: "/").count - 1
    }
    
    private func extractWorkingDirectory(from text: String) -> String {
        // This would typically be extracted from the prompt context
        // For now, return empty string
        return ""
    }
    
    private func isFileOperation(_ text: String) -> Bool {
        let fileOps = ["cp ", "mv ", "rm ", "mkdir ", "rmdir ", "ln ", "chmod ", "chown "]
        return fileOps.contains { text.hasPrefix($0) }
    }
    
    private func parseFileOperation(_ text: String) -> FileOperation {
        let components = text.split(separator: " ", omittingEmptySubsequences: true)
        guard !components.isEmpty else {
            return FileOperation(operation: text, type: "unknown", sourcePath: "", targetPath: "")
        }
        
        let command = String(components[0])
        let type = classifyCommand(command)
        let sourcePath = components.count > 1 ? String(components[1]) : ""
        let targetPath = components.count > 2 ? String(components[2]) : ""
        
        return FileOperation(
            operation: text,
            type: type,
            sourcePath: sourcePath,
            targetPath: targetPath
        )
    }
    
    private func isSystemInfoLine(_ text: String) -> Bool {
        // Check for common system info patterns
        return text.contains("CPU:") || text.contains("Memory:") || text.contains("Disk:") ||
               text.matches(#"\d+%"#) || text.matches(#"\d+\s*(GB|MB|KB)"#)
    }
    
    private func parseSystemInfo(_ text: String) -> SystemInfo {
        let lowercased = text.lowercased()
        
        if lowercased.contains("cpu") {
            return SystemInfo(type: "cpu", metric: "usage", value: extractPercentage(text), unit: "%")
        } else if lowercased.contains("memory") || lowercased.contains("mem") {
            return SystemInfo(type: "memory", metric: "usage", value: extractMemoryValue(text), unit: "MB")
        } else if lowercased.contains("disk") {
            return SystemInfo(type: "disk", metric: "usage", value: extractDiskValue(text), unit: "GB")
        }
        
        return SystemInfo(type: "unknown", metric: "", value: text, unit: "")
    }
    
    private func extractPercentage(_ text: String) -> String {
        if let range = text.range(of: #"\d+(\.\d+)?%"#, options: .regularExpression) {
            return String(text[range])
        }
        return ""
    }
    
    private func extractMemoryValue(_ text: String) -> String {
        if let range = text.range(of: #"\d+(\.\d+)?\s*(GB|MB|KB)"#, options: .regularExpression) {
            return String(text[range])
        }
        return ""
    }
    
    private func extractDiskValue(_ text: String) -> String {
        if let range = text.range(of: #"\d+(\.\d+)?\s*(GB|MB|TB)"#, options: .regularExpression) {
            return String(text[range])
        }
        return ""
    }
    
    // MARK: - Session and Workflow Analysis
    
    private func extractWorkingDirectoryFromContext(_ context: ApplicationContext) -> String {
        // Extract working directory from window title or other context clues
        if context.windowTitle.contains(":") {
            let parts = context.windowTitle.split(separator: ":")
            if parts.count > 1 {
                return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "~" // Default to home directory
    }
    
    private func detectWorkflowPatterns(in commands: [CommandExecution]) {
        // Detect common workflow patterns
        let commandNames = commands.map { $0.command.command }
        
        // Git workflow pattern
        if commandNames.contains("git") {
            let gitCommands = commands.filter { $0.command.command == "git" }
            if gitCommands.count >= 2 {
                let gitPattern = GitWorkflowPattern(commands: gitCommands)
                if !workflowPatterns.contains(where: { $0.type == "git_workflow" }) {
                    workflowPatterns.append(gitPattern)
                }
            }
        }
        
        // Build workflow pattern
        let buildCommands = ["make", "npm", "yarn", "cargo", "mvn", "gradle", "xcodebuild"]
        if buildCommands.contains(where: { commandNames.contains($0) }) {
            let buildPattern = BuildWorkflowPattern(commands: commands.filter { buildCommands.contains($0.command.command) })
            if !workflowPatterns.contains(where: { $0.type == "build_workflow" }) {
                workflowPatterns.append(buildPattern)
            }
        }
        
        // File management workflow
        let fileCommands = ["ls", "cd", "mkdir", "cp", "mv", "rm"]
        if fileCommands.filter({ commandNames.contains($0) }).count >= 3 {
            let filePattern = FileManagementWorkflowPattern(commands: commands.filter { fileCommands.contains($0.command.command) })
            if !workflowPatterns.contains(where: { $0.type == "file_management" }) {
                workflowPatterns.append(filePattern)
            }
        }
    }
    
    private func identifyWorkflowPatterns(in commands: [CommandExecution]) -> [String] {
        var patterns: [String] = []
        
        let commandNames = commands.map { $0.command.command }
        
        // Check for development workflows
        if commandNames.contains("git") && (commandNames.contains("npm") || commandNames.contains("yarn")) {
            patterns.append("web_development")
        }
        
        if commandNames.contains("docker") || commandNames.contains("kubectl") {
            patterns.append("containerization")
        }
        
        if commandNames.contains("ssh") || commandNames.contains("scp") {
            patterns.append("remote_administration")
        }
        
        if commandNames.filter({ ["ls", "cd", "find", "grep"].contains($0) }).count >= 3 {
            patterns.append("file_exploration")
        }
        
        return patterns
    }
    
    private func calculateProductivityScore(_ commands: [CommandExecution]) -> Double {
        guard !commands.isEmpty else { return 0.0 }
        
        let productiveCommands = ["git", "npm", "yarn", "make", "cargo", "mvn", "gradle", "docker", "kubectl"]
        let productiveCount = commands.filter { productiveCommands.contains($0.command.command) }.count
        
        return Double(productiveCount) / Double(commands.count)
    }
    
    private func calculateErrorRate(_ commands: [CommandExecution]) -> Double {
        guard !commands.isEmpty else { return 0.0 }
        
        let errorCount = commands.filter { $0.exitCode != nil && $0.exitCode != 0 }.count
        return Double(errorCount) / Double(commands.count)
    }
    
    private func initializeWorkflowPatterns() {
        // Initialize common workflow patterns for recognition
        workflowPatterns = []
        commandSequences = []
    }
    
    // MARK: - Session Detection Helpers
    
    private func isSessionStart(_ text: String) -> Bool {
        let sessionStartIndicators = [
            "login:",
            "Welcome to",
            "Last login:",
            "Terminal session started",
            "New session",
            "Connected to"
        ]
        
        return sessionStartIndicators.contains { text.contains($0) }
    }
    
    private func isSessionEnd(_ text: String) -> Bool {
        let sessionEndIndicators = [
            "logout",
            "exit",
            "Connection closed",
            "Session ended",
            "Terminal session closed"
        ]
        
        return sessionEndIndicators.contains { text.lowercased().contains($0.lowercased()) }
    }
    
    private func detectSessionType(_ text: String) -> String {
        if text.contains("ssh") || text.contains("Connected to") {
            return "remote_ssh"
        } else if text.contains("docker") {
            return "container"
        } else if text.contains("sudo") {
            return "elevated"
        }
        return "local"
    }
    
    private func isCommandCompletion(_ text: String) -> Bool {
        // Look for prompt indicators that suggest command completion
        return (text.hasPrefix("$ ") || text.hasPrefix("% ") || text.hasPrefix("# ")) &&
               lastPromptTime != nil &&
               Date().timeIntervalSince(lastPromptTime!) > 0.5 // At least 500ms since last prompt
    }
    
    private func extractExitCode(_ text: String) -> Int {
        // Try to extract exit code from various formats
        if let range = text.range(of: #"exit code (\d+)"#, options: .regularExpression) {
            let match = String(text[range])
            if let code = Int(match.components(separatedBy: " ").last ?? "0") {
                return code
            }
        }
        
        // Default to success if we see a new prompt
        return 0
    }
    
    private func updateLastCommandExitCode(_ exitCode: Int) {
        if !commandHistory.isEmpty {
            commandHistory[commandHistory.count - 1].exitCode = exitCode
            if let session = currentSession, !session.commands.isEmpty {
                session.commands[session.commands.count - 1].exitCode = exitCode
            }
        }
    }
}

// MARK: - Enhanced Data Structures

private class TerminalSession {
    let id: String
    let startTime: Date
    var endTime: Date?
    let context: ApplicationContext
    var workingDirectory: String
    var commands: [CommandExecution] = []
    var lastActivity: Date
    
    init(id: String, startTime: Date, context: ApplicationContext, workingDirectory: String) {
        self.id = id
        self.startTime = startTime
        self.context = context
        self.workingDirectory = workingDirectory
        self.lastActivity = startTime
    }
}

private struct CommandExecution {
    let id: String
    let command: TerminalParsingPlugin.CommandInfo
    let timestamp: Date
    let sessionId: String
    let workingDirectory: String
    let output: String?
    var exitCode: Int?
    
    var duration: TimeInterval?
    var errorMessage: String?
}

private struct CommandSequence {
    let id: String
    let commands: [CommandExecution]
    let pattern: String
    let frequency: Int
    let lastSeen: Date
}

private protocol WorkflowPattern {
    var type: String { get }
    var confidence: Double { get }
    var description: String { get }
}

private struct GitWorkflowPattern: WorkflowPattern {
    let type = "git_workflow"
    let commands: [CommandExecution]
    
    var confidence: Double {
        let gitCommands = commands.map { $0.command.arguments.first ?? "" }
        let commonFlow = ["status", "add", "commit", "push"]
        let matches = commonFlow.filter { gitCommands.contains($0) }.count
        return Double(matches) / Double(commonFlow.count)
    }
    
    var description: String {
        return "Git version control workflow detected"
    }
}

private struct BuildWorkflowPattern: WorkflowPattern {
    let type = "build_workflow"
    let commands: [CommandExecution]
    
    var confidence: Double {
        return commands.isEmpty ? 0.0 : 0.8 // High confidence if build commands are present
    }
    
    var description: String {
        return "Software build workflow detected"
    }
}

private struct FileManagementWorkflowPattern: WorkflowPattern {
    let type = "file_management"
    let commands: [CommandExecution]
    
    var confidence: Double {
        return commands.count >= 3 ? 0.7 : 0.3
    }
    
    var description: String {
        return "File management workflow detected"
    }
}

private struct WorkflowAnalysis {
    let sessionId: String
    let duration: TimeInterval
    let commandCount: Int
    let patterns: [String]
    let productivity: Double
    let errorRate: Double
}

// MARK: - String Extension for Regex (if not already defined)

private extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}