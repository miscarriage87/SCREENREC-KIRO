import XCTest
import CoreGraphics
@testable import Shared

class TerminalParsingPluginTests: XCTestCase {
    
    var plugin: TerminalParsingPlugin!
    var mockContext: ApplicationContext!
    
    override func setUp() {
        super.setUp()
        plugin = TerminalParsingPlugin()
        mockContext = ApplicationContext(
            bundleID: "com.apple.Terminal",
            appName: "Terminal",
            windowTitle: "Terminal — bash — 80×24",
            processID: 1234
        )
    }
    
    override func tearDown() {
        plugin = nil
        mockContext = nil
        super.tearDown()
    }
    
    // MARK: - Basic Command Detection Tests
    
    func testCommandLineDetection() {
        let ocrResults = [
            createOCRResult(text: "$ ls -la", confidence: 0.9),
            createOCRResult(text: "% cd /Users/test", confidence: 0.85),
            createOCRResult(text: "# sudo apt update", confidence: 0.95)
        ]
        
        let expectation = XCTestExpectation(description: "Command detection")
        
        Task {
            do {
                let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: mockContext, frame: createMockImage())
                
                let commandResults = enhanced.filter { $0.semanticType == "command_line" }
                XCTAssertEqual(commandResults.count, 3, "Should detect all three command lines")
                
                // Test first command
                let firstCommand = commandResults[0]
                XCTAssertEqual(firstCommand.structuredData["command"] as? String, "ls")
                XCTAssertEqual(firstCommand.structuredData["command_type"] as? String, "file_listing")
                XCTAssertEqual(firstCommand.structuredData["is_sudo"] as? Bool, false)
                
                // Test sudo command
                let sudoCommand = commandResults.first { ($0.structuredData["is_sudo"] as? Bool) == true }
                XCTAssertNotNil(sudoCommand, "Should detect sudo command")
                XCTAssertEqual(sudoCommand?.structuredData["command"] as? String, "apt")
                
                expectation.fulfill()
            } catch {
                XCTFail("Command detection failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCommandClassification() {
        let testCases = [
            ("ls", "file_listing"),
            ("cd", "navigation"),
            ("mkdir", "file_management"),
            ("cat", "file_viewing"),
            ("grep", "search"),
            ("ps", "process_management"),
            ("chmod", "permissions"),
            ("git", "version_control"),
            ("npm", "package_management"),
            ("docker", "containerization"),
            ("ssh", "network"),
            ("tar", "compression")
        ]
        
        for (command, expectedType) in testCases {
            let ocrResults = [createOCRResult(text: "$ \(command) test", confidence: 0.9)]
            
            let expectation = XCTestExpectation(description: "Command classification for \(command)")
            
            Task {
                do {
                    let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: mockContext, frame: createMockImage())
                    let commandResult = enhanced.first { $0.semanticType == "command_line" }
                    
                    XCTAssertNotNil(commandResult, "Should detect command: \(command)")
                    XCTAssertEqual(commandResult?.structuredData["command_type"] as? String, expectedType, 
                                 "Command \(command) should be classified as \(expectedType)")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Command classification failed for \(command): \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    // MARK: - Session Tracking Tests
    
    func testSessionStartAndEnd() {
        // Test session start
        let sessionStartResults = [
            createOCRResult(text: "Welcome to Terminal", confidence: 0.9),
            createOCRResult(text: "Last login: Mon Oct 10 10:00:00", confidence: 0.8)
        ]
        
        let expectation1 = XCTestExpectation(description: "Session start detection")
        
        Task {
            do {
                let enhanced = try await plugin.enhanceOCRResults(sessionStartResults, context: mockContext, frame: createMockImage())
                let sessionStart = enhanced.first { $0.semanticType == "session_start" }
                
                XCTAssertNotNil(sessionStart, "Should detect session start")
                XCTAssertEqual(sessionStart?.structuredData["session_type"] as? String, "local")
                
                expectation1.fulfill()
            } catch {
                XCTFail("Session start detection failed: \(error)")
            }
        }
        
        wait(for: [expectation1], timeout: 5.0)
        
        // Test session end
        let sessionEndResults = [createOCRResult(text: "logout", confidence: 0.9)]
        
        let expectation2 = XCTestExpectation(description: "Session end detection")
        
        Task {
            do {
                let enhanced = try await plugin.enhanceOCRResults(sessionEndResults, context: mockContext, frame: createMockImage())
                let sessionEnd = enhanced.first { $0.semanticType == "session_end" }
                
                XCTAssertNotNil(sessionEnd, "Should detect session end")
                
                expectation2.fulfill()
            } catch {
                XCTFail("Session end detection failed: \(error)")
            }
        }
        
        wait(for: [expectation2], timeout: 5.0)
    }
    
    func testCommandHistoryTracking() {
        let commands = [
            "$ git status",
            "$ git add .",
            "$ git commit -m 'test'",
            "$ git push origin main"
        ]
        
        let expectation = XCTestExpectation(description: "Command history tracking")
        
        Task {
            do {
                // Process commands sequentially
                for (index, command) in commands.enumerated() {
                    let ocrResults = [createOCRResult(text: command, confidence: 0.9)]
                    let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: mockContext, frame: createMockImage())
                    
                    let commandResult = enhanced.first { $0.semanticType == "command_line" }
                    XCTAssertNotNil(commandResult, "Should detect command: \(command)")
                    
                    let sequencePosition = commandResult?.structuredData["command_sequence_position"] as? Int
                    XCTAssertEqual(sequencePosition, index + 1, "Command sequence position should be correct")
                }
                
                // Extract structured data to check workflow patterns
                let structuredData = try await plugin.extractStructuredData(from: [], context: mockContext)
                let workflowPatterns = structuredData.filter { $0.type == "workflow_pattern" }
                
                XCTAssertTrue(workflowPatterns.contains { $0.value == "git_workflow" }, 
                            "Should detect git workflow pattern")
                
                expectation.fulfill()
            } catch {
                XCTFail("Command history tracking failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Output and Error Detection Tests
    
    func testErrorMessageDetection() {
        let errorResults = [
            createOCRResult(text: "bash: command not found: nonexistent", confidence: 0.9),
            createOCRResult(text: "Permission denied: /etc/shadow", confidence: 0.85),
            createOCRResult(text: "No such file or directory: missing.txt", confidence: 0.8),
            createOCRResult(text: "fatal: not a git repository", confidence: 0.9)
        ]
        
        let expectation = XCTestExpectation(description: "Error message detection")
        
        Task {
            do {
                let enhanced = try await plugin.enhanceOCRResults(errorResults, context: mockContext, frame: createMockImage())
                let errorMessages = enhanced.filter { $0.semanticType == "error_message" }
                
                XCTAssertEqual(errorMessages.count, 4, "Should detect all error messages")
                
                // Test error classification
                let errorTypes = errorMessages.compactMap { $0.structuredData["error_type"] as? String }
                XCTAssertTrue(errorTypes.contains("command_not_found"), "Should classify command not found error")
                XCTAssertTrue(errorTypes.contains("permission_error"), "Should classify permission error")
                XCTAssertTrue(errorTypes.contains("file_not_found"), "Should classify file not found error")
                
                expectation.fulfill()
            } catch {
                XCTFail("Error message detection failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFileListingParsing() {
        let fileListingResults = [
            createOCRResult(text: "drwxr-xr-x  3 user staff  96 Oct 10 10:00 Documents", confidence: 0.9),
            createOCRResult(text: "-rw-r--r--  1 user staff 1024 Oct 10 09:30 file.txt", confidence: 0.85),
            createOCRResult(text: "lrwxr-xr-x  1 user staff   10 Oct 10 08:00 link -> target", confidence: 0.8)
        ]
        
        let expectation = XCTestExpectation(description: "File listing parsing")
        
        Task {
            do {
                let enhanced = try await plugin.enhanceOCRResults(fileListingResults, context: mockContext, frame: createMockImage())
                let fileListings = enhanced.filter { $0.semanticType == "file_listing" }
                
                XCTAssertEqual(fileListings.count, 3, "Should detect all file listings")
                
                // Test directory detection
                let directory = fileListings.first { ($0.structuredData["is_directory"] as? Bool) == true }
                XCTAssertNotNil(directory, "Should detect directory")
                XCTAssertEqual(directory?.structuredData["filename"] as? String, "Documents")
                
                // Test regular file
                let regularFile = fileListings.first { ($0.structuredData["filename"] as? String) == "file.txt" }
                XCTAssertNotNil(regularFile, "Should detect regular file")
                XCTAssertEqual(regularFile?.structuredData["size"] as? String, "1024")
                
                expectation.fulfill()
            } catch {
                XCTFail("File listing parsing failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Workflow Pattern Tests
    
    func testGitWorkflowDetection() {
        let gitCommands = [
            "$ git status",
            "$ git add file.txt",
            "$ git commit -m 'Add new feature'",
            "$ git push origin main"
        ]
        
        let expectation = XCTestExpectation(description: "Git workflow detection")
        
        Task {
            do {
                // Process git workflow
                for command in gitCommands {
                    let ocrResults = [createOCRResult(text: command, confidence: 0.9)]
                    _ = try await plugin.enhanceOCRResults(ocrResults, context: mockContext, frame: createMockImage())
                }
                
                // Check for workflow pattern detection
                let structuredData = try await plugin.extractStructuredData(from: [], context: mockContext)
                let workflowPatterns = structuredData.filter { $0.type == "workflow_pattern" }
                let gitWorkflow = workflowPatterns.first { $0.value == "git_workflow" }
                
                XCTAssertNotNil(gitWorkflow, "Should detect git workflow pattern")
                XCTAssertGreaterThan(gitWorkflow?.metadata["confidence"] as? Double ?? 0, 0.5, 
                                   "Git workflow confidence should be high")
                
                expectation.fulfill()
            } catch {
                XCTFail("Git workflow detection failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testBuildWorkflowDetection() {
        let buildCommands = [
            "$ npm install",
            "$ npm run build",
            "$ npm test"
        ]
        
        let expectation = XCTestExpectation(description: "Build workflow detection")
        
        Task {
            do {
                // Process build workflow
                for command in buildCommands {
                    let ocrResults = [createOCRResult(text: command, confidence: 0.9)]
                    _ = try await plugin.enhanceOCRResults(ocrResults, context: mockContext, frame: createMockImage())
                }
                
                // Check for workflow pattern detection
                let structuredData = try await plugin.extractStructuredData(from: [], context: mockContext)
                let workflowPatterns = structuredData.filter { $0.type == "workflow_pattern" }
                let buildWorkflow = workflowPatterns.first { $0.value == "build_workflow" }
                
                XCTAssertNotNil(buildWorkflow, "Should detect build workflow pattern")
                
                expectation.fulfill()
            } catch {
                XCTFail("Build workflow detection failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Session Metrics Tests
    
    func testSessionMetricsExtraction() {
        let expectation = XCTestExpectation(description: "Session metrics extraction")
        
        Task {
            do {
                // Start a session and execute some commands
                let commands = [
                    "$ ls -la",
                    "$ cd Documents",
                    "$ git status",
                    "$ npm test"
                ]
                
                for command in commands {
                    let ocrResults = [createOCRResult(text: command, confidence: 0.9)]
                    _ = try await plugin.enhanceOCRResults(ocrResults, context: mockContext, frame: createMockImage())
                }
                
                // Extract session metrics
                let structuredData = try await plugin.extractStructuredData(from: [], context: mockContext)
                let sessionMetrics = structuredData.filter { $0.type == "session_metrics" }
                
                XCTAssertFalse(sessionMetrics.isEmpty, "Should extract session metrics")
                
                let metrics = sessionMetrics.first
                XCTAssertNotNil(metrics?.metadata["command_count"], "Should track command count")
                XCTAssertNotNil(metrics?.metadata["duration_seconds"], "Should track session duration")
                XCTAssertNotNil(metrics?.metadata["productivity_score"], "Should calculate productivity score")
                
                let commandCount = metrics?.metadata["command_count"] as? Int
                XCTAssertEqual(commandCount, 4, "Should track correct command count")
                
                expectation.fulfill()
            } catch {
                XCTFail("Session metrics extraction failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Path and Navigation Tests
    
    func testPathDetection() {
        let pathResults = [
            createOCRResult(text: "/Users/test/Documents/file.txt", confidence: 0.9),
            createOCRResult(text: "./relative/path", confidence: 0.85),
            createOCRResult(text: "../parent/directory", confidence: 0.8),
            createOCRResult(text: "~/home/path", confidence: 0.9)
        ]
        
        let expectation = XCTestExpectation(description: "Path detection")
        
        Task {
            do {
                let enhanced = try await plugin.enhanceOCRResults(pathResults, context: mockContext, frame: createMockImage())
                let filePaths = enhanced.filter { $0.semanticType == "file_path" }
                
                XCTAssertEqual(filePaths.count, 4, "Should detect all file paths")
                
                // Test path classification
                let pathTypes = filePaths.compactMap { $0.structuredData["path_type"] as? String }
                XCTAssertTrue(pathTypes.contains("absolute"), "Should detect absolute path")
                XCTAssertTrue(pathTypes.contains("relative_current"), "Should detect relative current path")
                XCTAssertTrue(pathTypes.contains("relative_parent"), "Should detect relative parent path")
                XCTAssertTrue(pathTypes.contains("home_relative"), "Should detect home relative path")
                
                expectation.fulfill()
            } catch {
                XCTFail("Path detection failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Complex Scenario Tests
    
    func testComplexTerminalSession() {
        let sessionScenario = [
            "Welcome to Terminal",
            "user@hostname:~$ cd /project",
            "user@hostname:/project$ git status",
            "On branch main",
            "Changes not staged for commit:",
            "  modified:   src/main.swift",
            "user@hostname:/project$ git add .",
            "user@hostname:/project$ git commit -m 'Fix bug'",
            "[main abc1234] Fix bug",
            " 1 file changed, 5 insertions(+), 2 deletions(-)",
            "user@hostname:/project$ npm test",
            "✓ All tests passed",
            "user@hostname:/project$ logout"
        ]
        
        let expectation = XCTestExpectation(description: "Complex terminal session")
        
        Task {
            do {
                var allEnhanced: [EnhancedOCRResult] = []
                
                // Process entire session
                for line in sessionScenario {
                    let ocrResults = [createOCRResult(text: line, confidence: 0.9)]
                    let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: mockContext, frame: createMockImage())
                    allEnhanced.append(contentsOf: enhanced)
                }
                
                // Verify session tracking
                let sessionStarts = allEnhanced.filter { $0.semanticType == "session_start" }
                let sessionEnds = allEnhanced.filter { $0.semanticType == "session_end" }
                let commands = allEnhanced.filter { $0.semanticType == "command_line" }
                let outputs = allEnhanced.filter { $0.semanticType == "command_output" }
                
                XCTAssertEqual(sessionStarts.count, 1, "Should detect session start")
                XCTAssertEqual(sessionEnds.count, 1, "Should detect session end")
                XCTAssertGreaterThan(commands.count, 0, "Should detect commands")
                XCTAssertGreaterThan(outputs.count, 0, "Should detect command outputs")
                
                // Verify workflow detection
                let structuredData = try await plugin.extractStructuredData(from: [], context: mockContext)
                let workflowPatterns = structuredData.filter { $0.type == "workflow_pattern" }
                
                XCTAssertTrue(workflowPatterns.contains { $0.value == "git_workflow" }, 
                            "Should detect git workflow in complex session")
                
                expectation.fulfill()
            } catch {
                XCTFail("Complex terminal session test failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Helper Methods
    
    private func createOCRResult(text: String, confidence: Float) -> OCRResult {
        return OCRResult(
            text: text,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
            confidence: confidence
        )
    }
    
    private func createMockImage() -> CGImage {
        let width = 800
        let height = 600
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        
        return context.makeImage()!
    }
}