import Foundation
import CoreGraphics
import Shared

/// Demo showcasing terminal and command-line parsing capabilities
public class TerminalParsingDemo {
    
    private let plugin = TerminalParsingPlugin()
    
    public init() {}
    
    public func runDemo() {
        print("=== Terminal Parsing Plugin Demo ===\n")
        
        demonstrateBasicCommandParsing()
        demonstrateSessionTracking()
        demonstrateWorkflowAnalysis()
        demonstrateErrorDetection()
        demonstrateComplexScenario()
    }
    
    // MARK: - Basic Command Parsing Demo
    
    private func demonstrateBasicCommandParsing() {
        print("1. Basic Command Parsing")
        print("------------------------")
        
        let commands = [
            "$ ls -la /Users/developer",
            "% cd ~/Documents/projects",
            "# sudo apt update && apt upgrade",
            "$ git status --porcelain",
            "$ npm install --save-dev typescript",
            "$ docker run -it ubuntu:latest bash"
        ]
        
        let context = createMockContext()
        
        for command in commands {
            let ocrResults = [createOCRResult(text: command)]
            
            Task {
                do {
                    let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: context, frame: createMockImage())
                    
                    if let commandResult = enhanced.first(where: { $0.semanticType == "command_line" }) {
                        print("Command: \(command)")
                        print("  - Type: \(commandResult.structuredData["command_type"] ?? "unknown")")
                        print("  - Is Sudo: \(commandResult.structuredData["is_sudo"] ?? false)")
                        print("  - Arguments: \(commandResult.structuredData["arguments"] ?? [])")
                        print()
                    }
                } catch {
                    print("Error processing command: \(error)")
                }
            }
        }
        
        // Wait a moment for async operations
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    // MARK: - Session Tracking Demo
    
    private func demonstrateSessionTracking() {
        print("2. Session Tracking")
        print("-------------------")
        
        let sessionFlow = [
            "Welcome to Terminal",
            "Last login: Mon Oct 10 10:00:00 on ttys000",
            "developer@macbook:~$ pwd",
            "/Users/developer",
            "developer@macbook:~$ cd projects/my-app",
            "developer@macbook:~/projects/my-app$ ls",
            "src/  package.json  README.md  node_modules/",
            "developer@macbook:~/projects/my-app$ git log --oneline -5",
            "abc1234 Fix authentication bug",
            "def5678 Add user profile page",
            "ghi9012 Update dependencies",
            "developer@macbook:~/projects/my-app$ logout"
        ]
        
        let context = createMockContext()
        
        print("Processing terminal session...")
        
        for (index, line) in sessionFlow.enumerated() {
            let ocrResults = [createOCRResult(text: line)]
            
            Task {
                do {
                    let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: context, frame: createMockImage())
                    
                    for result in enhanced {
                        switch result.semanticType {
                        case "session_start":
                            print("📍 Session started: \(result.structuredData["session_type"] ?? "unknown")")
                        case "session_end":
                            print("🏁 Session ended")
                        case "command_line":
                            let cmd = result.structuredData["command"] ?? "unknown"
                            let pos = result.structuredData["command_sequence_position"] ?? 0
                            print("⚡ Command #\(pos): \(cmd)")
                        case "shell_prompt":
                            let user = result.structuredData["username"] ?? "unknown"
                            let dir = result.structuredData["current_directory"] ?? "unknown"
                            print("💻 Prompt: \(user) in \(dir)")
                        default:
                            break
                        }
                    }
                } catch {
                    print("Error processing line \(index): \(error)")
                }
            }
        }
        
        Thread.sleep(forTimeInterval: 2.0)
        print()
    }
    
    // MARK: - Workflow Analysis Demo
    
    private func demonstrateWorkflowAnalysis() {
        print("3. Workflow Analysis")
        print("--------------------")
        
        let workflows = [
            // Git workflow
            [
                "$ git status",
                "$ git add .",
                "$ git commit -m 'Implement new feature'",
                "$ git push origin feature-branch"
            ],
            // Build workflow
            [
                "$ npm install",
                "$ npm run lint",
                "$ npm run test",
                "$ npm run build"
            ],
            // Docker workflow
            [
                "$ docker build -t myapp .",
                "$ docker run -p 3000:3000 myapp",
                "$ docker ps",
                "$ docker logs myapp"
            ]
        ]
        
        let context = createMockContext()
        
        for (workflowIndex, workflow) in workflows.enumerated() {
            print("Workflow \(workflowIndex + 1):")
            
            for command in workflow {
                let ocrResults = [createOCRResult(text: command)]
                
                Task {
                    do {
                        let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: context, frame: createMockImage())
                        
                        if let commandResult = enhanced.first(where: { $0.semanticType == "command_line" }) {
                            let cmd = commandResult.structuredData["command"] ?? "unknown"
                            let type = commandResult.structuredData["command_type"] ?? "unknown"
                            print("  - \(cmd) (\(type))")
                        }
                    } catch {
                        print("Error processing workflow command: \(error)")
                    }
                }
            }
            
            // Extract workflow patterns
            Task {
                do {
                    let structuredData = try await plugin.extractStructuredData(from: [], context: context)
                    let patterns = structuredData.filter { $0.type == "workflow_pattern" }
                    
                    for pattern in patterns {
                        let confidence = pattern.metadata["confidence"] as? Double ?? 0.0
                        print("  🔍 Detected: \(pattern.value) (confidence: \(String(format: "%.2f", confidence)))")
                    }
                } catch {
                    print("Error extracting workflow patterns: \(error)")
                }
            }
            
            print()
        }
        
        Thread.sleep(forTimeInterval: 2.0)
    }
    
    // MARK: - Error Detection Demo
    
    private func demonstrateErrorDetection() {
        print("4. Error Detection")
        print("------------------")
        
        let errorScenarios = [
            "bash: nonexistent: command not found",
            "Permission denied: /etc/shadow",
            "No such file or directory: missing.txt",
            "fatal: not a git repository (or any of the parent directories): .git",
            "npm ERR! Missing script: \"nonexistent\"",
            "docker: Error response from daemon: pull access denied",
            "ssh: connect to host example.com port 22: Connection refused"
        ]
        
        let context = createMockContext()
        
        for error in errorScenarios {
            let ocrResults = [createOCRResult(text: error)]
            
            Task {
                do {
                    let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: context, frame: createMockImage())
                    
                    if let errorResult = enhanced.first(where: { $0.semanticType == "error_message" }) {
                        let errorType = errorResult.structuredData["error_type"] ?? "unknown"
                        let severity = errorResult.structuredData["severity"] ?? "unknown"
                        print("❌ \(errorType) (\(severity)): \(error)")
                    }
                } catch {
                    print("Error processing error message: \(error)")
                }
            }
        }
        
        Thread.sleep(forTimeInterval: 1.0)
        print()
    }
    
    // MARK: - Complex Scenario Demo
    
    private func demonstrateComplexScenario() {
        print("5. Complex Development Session")
        print("------------------------------")
        
        let developmentSession = [
            "Welcome to Terminal",
            "developer@macbook:~$ cd ~/projects/web-app",
            "developer@macbook:~/projects/web-app$ git status",
            "On branch feature/user-auth",
            "Changes not staged for commit:",
            "  modified:   src/auth/login.js",
            "  modified:   tests/auth.test.js",
            "developer@macbook:~/projects/web-app$ npm test",
            "✓ should authenticate valid user",
            "✓ should reject invalid credentials",
            "✗ should handle missing password",
            "npm ERR! Test failed. See above for more details.",
            "developer@macbook:~/projects/web-app$ vim tests/auth.test.js",
            "developer@macbook:~/projects/web-app$ npm test",
            "✓ should authenticate valid user",
            "✓ should reject invalid credentials", 
            "✓ should handle missing password",
            "All tests passed!",
            "developer@macbook:~/projects/web-app$ git add .",
            "developer@macbook:~/projects/web-app$ git commit -m 'Fix authentication tests'",
            "[feature/user-auth abc1234] Fix authentication tests",
            " 2 files changed, 15 insertions(+), 3 deletions(-)",
            "developer@macbook:~/projects/web-app$ git push origin feature/user-auth",
            "Enumerating objects: 7, done.",
            "Total 7 (delta 4), reused 0 (delta 0)",
            "To github.com:user/web-app.git",
            "   def5678..abc1234  feature/user-auth -> feature/user-auth",
            "developer@macbook:~/projects/web-app$ logout"
        ]
        
        let context = createMockContext()
        var sessionMetrics: [String: Any] = [:]
        
        print("Processing complex development session...")
        
        for (index, line) in developmentSession.enumerated() {
            let ocrResults = [createOCRResult(text: line)]
            
            Task {
                do {
                    let enhanced = try await plugin.enhanceOCRResults(ocrResults, context: context, frame: createMockImage())
                    
                    for result in enhanced {
                        switch result.semanticType {
                        case "session_start":
                            print("🚀 Development session started")
                        case "command_line":
                            let cmd = result.structuredData["command"] ?? "unknown"
                            let type = result.structuredData["command_type"] ?? "unknown"
                            print("📝 \(cmd) [\(type)]")
                        case "error_message":
                            let errorType = result.structuredData["error_type"] ?? "unknown"
                            print("⚠️  Error detected: \(errorType)")
                        case "command_output":
                            let outputType = result.structuredData["output_type"] ?? "unknown"
                            if outputType == "error" {
                                print("❌ Test failure detected")
                            } else if line.contains("✓") {
                                print("✅ Test success detected")
                            }
                        case "session_end":
                            print("🏁 Development session completed")
                        default:
                            break
                        }
                    }
                } catch {
                    print("Error processing line \(index): \(error)")
                }
            }
        }
        
        // Extract final session metrics
        Task {
            do {
                let structuredData = try await plugin.extractStructuredData(from: [], context: context)
                
                // Get workflow patterns
                let patterns = structuredData.filter { $0.type == "workflow_pattern" }
                if !patterns.isEmpty {
                    print("\n🔍 Detected Workflows:")
                    for pattern in patterns {
                        let confidence = pattern.metadata["confidence"] as? Double ?? 0.0
                        print("  - \(pattern.value) (confidence: \(String(format: "%.2f", confidence)))")
                    }
                }
                
                // Get session metrics
                let metrics = structuredData.filter { $0.type == "session_metrics" }
                if let sessionMetric = metrics.first {
                    print("\n📊 Session Metrics:")
                    if let commandCount = sessionMetric.metadata["command_count"] as? Int {
                        print("  - Commands executed: \(commandCount)")
                    }
                    if let productivity = sessionMetric.metadata["productivity_score"] as? Double {
                        print("  - Productivity score: \(String(format: "%.2f", productivity))")
                    }
                    if let errorRate = sessionMetric.metadata["error_rate"] as? Double {
                        print("  - Error rate: \(String(format: "%.2f", errorRate))")
                    }
                }
            } catch {
                print("Error extracting final metrics: \(error)")
            }
        }
        
        Thread.sleep(forTimeInterval: 3.0)
        print("\n=== Demo Complete ===")
    }
    
    // MARK: - Helper Methods
    
    private func createMockContext() -> ApplicationContext {
        return ApplicationContext(
            bundleID: "com.apple.Terminal",
            appName: "Terminal",
            windowTitle: "Terminal — bash — 80×24",
            processID: 1234
        )
    }
    
    private func createOCRResult(text: String) -> OCRResult {
        return OCRResult(
            text: text,
            boundingBox: CGRect(x: 0, y: 0, width: 800, height: 20),
            confidence: 0.9
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

// MARK: - Demo Runner

public func runTerminalParsingDemo() {
    let demo = TerminalParsingDemo()
    demo.runDemo()
}