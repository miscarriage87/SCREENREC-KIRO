import Foundation
import SwiftUI

/// Provides contextual help and guidance throughout the application
public class HelpSystem: ObservableObject {
    public static let shared = HelpSystem()
    
    @Published public var isHelpVisible: Bool = false
    @Published public var currentContext: HelpContext = .general
    @Published public var searchQuery: String = ""
    
    private let helpContent: HelpContentManager
    private let analytics: HelpAnalytics
    
    private init() {
        self.helpContent = HelpContentManager()
        self.analytics = HelpAnalytics()
    }
    
    // MARK: - Public Interface
    
    /// Show help for a specific context
    public func showHelp(for context: HelpContext) {
        currentContext = context
        isHelpVisible = true
        analytics.trackHelpAccess(context: context)
    }
    
    /// Hide the help system
    public func hideHelp() {
        isHelpVisible = false
        searchQuery = ""
    }
    
    /// Get help content for current context
    public func getContextualHelp() -> [HelpItem] {
        return helpContent.getHelpItems(for: currentContext, searchQuery: searchQuery)
    }
    
    /// Search help content
    public func searchHelp(_ query: String) {
        searchQuery = query
        analytics.trackHelpSearch(query: query)
    }
    
    /// Get quick tips for current context
    public func getQuickTips() -> [QuickTip] {
        return helpContent.getQuickTips(for: currentContext)
    }
    
    /// Get troubleshooting steps for current context
    public func getTroubleshootingSteps() -> [TroubleshootingStep] {
        return helpContent.getTroubleshootingSteps(for: currentContext)
    }
}

// MARK: - Help Context

public enum HelpContext: String, CaseIterable {
    case general = "general"
    case installation = "installation"
    case recording = "recording"
    case privacy = "privacy"
    case settings = "settings"
    case performance = "performance"
    case plugins = "plugins"
    case reports = "reports"
    case troubleshooting = "troubleshooting"
    
    public var displayName: String {
        switch self {
        case .general: return "General Help"
        case .installation: return "Installation & Setup"
        case .recording: return "Recording & Capture"
        case .privacy: return "Privacy & Security"
        case .settings: return "Settings & Configuration"
        case .performance: return "Performance & Optimization"
        case .plugins: return "Plugins & Extensions"
        case .reports: return "Reports & Analysis"
        case .troubleshooting: return "Troubleshooting"
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "questionmark.circle"
        case .installation: return "arrow.down.circle"
        case .recording: return "record.circle"
        case .privacy: return "lock.shield"
        case .settings: return "gearshape"
        case .performance: return "speedometer"
        case .plugins: return "puzzlepiece"
        case .reports: return "doc.text"
        case .troubleshooting: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Help Content Manager

public class HelpContentManager {
    private let helpItems: [HelpContext: [HelpItem]]
    private let quickTips: [HelpContext: [QuickTip]]
    private let troubleshootingSteps: [HelpContext: [TroubleshootingStep]]
    
    public init() {
        self.helpItems = Self.loadHelpItems()
        self.quickTips = Self.loadQuickTips()
        self.troubleshootingSteps = Self.loadTroubleshootingSteps()
    }
    
    public func getHelpItems(for context: HelpContext, searchQuery: String = "") -> [HelpItem] {
        let items = helpItems[context] ?? []
        
        if searchQuery.isEmpty {
            return items
        }
        
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(searchQuery) ||
            item.content.localizedCaseInsensitiveContains(searchQuery) ||
            item.keywords.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    public func getQuickTips(for context: HelpContext) -> [QuickTip] {
        return quickTips[context] ?? []
    }
    
    public func getTroubleshootingSteps(for context: HelpContext) -> [TroubleshootingStep] {
        return troubleshootingSteps[context] ?? []
    }
    
    // MARK: - Content Loading
    
    private static func loadHelpItems() -> [HelpContext: [HelpItem]] {
        return [
            .general: [
                HelpItem(
                    id: "what-is-ai-companion",
                    title: "What is Always-On AI Companion?",
                    content: """
                    Always-On AI Companion is a comprehensive system that continuously records, analyzes, and summarizes your screen activity across multiple monitors. It provides an AI companion with complete context of your activities through:
                    
                    • **Stable Background Recording**: Captures all screen activity using native macOS ScreenCaptureKit
                    • **Intelligent Analysis**: OCR text extraction and event detection
                    • **Privacy First**: Local processing with comprehensive privacy controls
                    • **Activity Summaries**: Automated reports and workflow documentation
                    • **Plugin Architecture**: Extensible parsing for specialized applications
                    """,
                    keywords: ["overview", "features", "introduction"],
                    category: .overview
                ),
                HelpItem(
                    id: "getting-started",
                    title: "Getting Started",
                    content: """
                    To get started with Always-On AI Companion:
                    
                    1. **Grant Permissions**: Allow Screen Recording and Accessibility access
                    2. **Configure Displays**: Select which monitors to record
                    3. **Set Privacy Preferences**: Configure allowlists and PII protection
                    4. **Start Recording**: Click the record button in the menu bar
                    5. **Review Reports**: Access activity summaries and insights
                    
                    The system will automatically start recording on future logins.
                    """,
                    keywords: ["setup", "start", "begin", "first time"],
                    category: .quickStart
                ),
                HelpItem(
                    id: "system-requirements",
                    title: "System Requirements",
                    content: """
                    **Minimum Requirements:**
                    • macOS 14.0 (Sonoma) or later
                    • 8GB RAM
                    • 50GB available storage
                    • Screen Recording permission
                    • Accessibility permission
                    
                    **Recommended:**
                    • macOS 15.0 (Sequoia) or later
                    • 16GB RAM
                    • 200GB available storage
                    • Apple Silicon Mac (for optimal performance)
                    • SSD storage
                    """,
                    keywords: ["requirements", "compatibility", "hardware"],
                    category: .reference
                )
            ],
            
            .installation: [
                HelpItem(
                    id: "installation-process",
                    title: "Installation Process",
                    content: """
                    **Automated Installation:**
                    1. Download the installer package
                    2. Run the installer with administrator privileges
                    3. Grant requested permissions when prompted
                    4. Launch the application from Applications folder
                    
                    **Manual Installation:**
                    1. Clone the repository or download source
                    2. Build using Xcode or command line tools
                    3. Install system components manually
                    4. Configure LaunchAgent for automatic startup
                    
                    See the full installation guide for detailed instructions.
                    """,
                    keywords: ["install", "setup", "download"],
                    category: .procedure
                ),
                HelpItem(
                    id: "permissions-setup",
                    title: "Setting Up Permissions",
                    content: """
                    The application requires two key permissions:
                    
                    **Screen Recording Permission:**
                    • System Settings → Privacy & Security → Screen Recording
                    • Add "Always-On AI Companion" and enable
                    
                    **Accessibility Permission:**
                    • System Settings → Privacy & Security → Accessibility
                    • Add "Always-On AI Companion" and enable
                    
                    These permissions are required for the system to function properly.
                    """,
                    keywords: ["permissions", "privacy", "security", "access"],
                    category: .procedure
                )
            ],
            
            .recording: [
                HelpItem(
                    id: "start-recording",
                    title: "Starting and Stopping Recording",
                    content: """
                    **Start Recording:**
                    • Click the menu bar icon and select "Start Recording"
                    • Use the hotkey Cmd+Shift+R (configurable)
                    • Recording starts automatically on system boot
                    
                    **Stop Recording:**
                    • Click the menu bar icon and select "Stop Recording"
                    • Use the same hotkey to toggle
                    
                    **Pause Recording:**
                    • Use Cmd+Shift+P for quick pause
                    • Emergency pause: Cmd+Shift+Esc
                    """,
                    keywords: ["record", "start", "stop", "pause", "hotkey"],
                    category: .procedure
                ),
                HelpItem(
                    id: "multi-monitor-setup",
                    title: "Multi-Monitor Recording",
                    content: """
                    The system can record multiple displays simultaneously:
                    
                    **Configuration:**
                    • Settings → Display → Select Monitors
                    • Choose which displays to record
                    • Set quality settings per display
                    
                    **Performance Considerations:**
                    • Each additional display increases CPU usage
                    • Consider reducing quality for secondary displays
                    • Monitor system performance metrics
                    """,
                    keywords: ["multi-monitor", "displays", "external", "multiple"],
                    category: .configuration
                )
            ],
            
            .privacy: [
                HelpItem(
                    id: "privacy-controls",
                    title: "Privacy Controls Overview",
                    content: """
                    Always-On AI Companion provides comprehensive privacy protection:
                    
                    **Immediate Controls:**
                    • Pause hotkey (Cmd+Shift+P) - 100ms response time
                    • Emergency stop (Cmd+Shift+Esc)
                    • Privacy mode toggle
                    
                    **Application Controls:**
                    • Allowlist/blocklist for applications
                    • Per-application recording rules
                    • Window title filtering
                    
                    **Data Protection:**
                    • PII detection and masking
                    • Local-only processing
                    • End-to-end encryption
                    """,
                    keywords: ["privacy", "security", "protection", "pii", "mask"],
                    category: .overview
                ),
                HelpItem(
                    id: "pii-protection",
                    title: "PII Protection and Masking",
                    content: """
                    The system automatically detects and masks sensitive information:
                    
                    **Automatically Detected:**
                    • Credit card numbers
                    • Social Security numbers
                    • Email addresses
                    • Phone numbers
                    
                    **Configuration:**
                    • Settings → Privacy → PII Protection
                    • Add custom patterns
                    • Adjust sensitivity levels
                    • Review masking rules
                    
                    **Verification:**
                    • Run privacy audit to check existing data
                    • Review OCR results for proper masking
                    """,
                    keywords: ["pii", "sensitive", "mask", "protect", "personal"],
                    category: .configuration
                )
            ],
            
            .performance: [
                HelpItem(
                    id: "performance-optimization",
                    title: "Performance Optimization",
                    content: """
                    Optimize system performance with these settings:
                    
                    **Recording Quality:**
                    • Use "Balanced" mode for most users
                    • Reduce frame rate to 15fps if needed
                    • Lower resolution for secondary displays
                    
                    **System Resources:**
                    • Monitor CPU usage (should be <8%)
                    • Ensure sufficient disk space
                    • Use SSD storage for best performance
                    
                    **Advanced Settings:**
                    • Adjust processing intervals
                    • Enable hardware acceleration
                    • Configure memory limits
                    """,
                    keywords: ["performance", "optimize", "cpu", "memory", "speed"],
                    category: .configuration
                ),
                HelpItem(
                    id: "troubleshooting-performance",
                    title: "Troubleshooting Performance Issues",
                    content: """
                    If experiencing performance problems:
                    
                    **High CPU Usage:**
                    • Reduce recording quality
                    • Limit monitored displays
                    • Check for conflicting software
                    
                    **Memory Issues:**
                    • Restart the application
                    • Clear processing caches
                    • Reduce buffer sizes
                    
                    **Storage Problems:**
                    • Clean up old data
                    • Move to faster storage
                    • Enable compression
                    """,
                    keywords: ["slow", "cpu", "memory", "performance", "lag"],
                    category: .troubleshooting
                )
            ]
        ]
    }
    
    private static func loadQuickTips() -> [HelpContext: [QuickTip]] {
        return [
            .general: [
                QuickTip(
                    id: "menu-bar-access",
                    title: "Quick Access",
                    content: "Click the menu bar icon for instant access to recording controls and system status."
                ),
                QuickTip(
                    id: "hotkey-shortcuts",
                    title: "Keyboard Shortcuts",
                    content: "Use Cmd+Shift+P to quickly pause recording, or Cmd+Shift+Esc for emergency stop."
                )
            ],
            .recording: [
                QuickTip(
                    id: "auto-start",
                    title: "Automatic Recording",
                    content: "Recording starts automatically when you log in. No need to manually start each time."
                ),
                QuickTip(
                    id: "segment-duration",
                    title: "Video Segments",
                    content: "Videos are automatically split into 2-minute segments for efficient processing."
                )
            ],
            .privacy: [
                QuickTip(
                    id: "local-processing",
                    title: "Local Processing",
                    content: "All analysis happens on your Mac. No data is sent to external servers."
                ),
                QuickTip(
                    id: "quick-pause",
                    title: "Quick Privacy",
                    content: "The pause hotkey responds within 100ms for immediate privacy protection."
                )
            ]
        ]
    }
    
    private static func loadTroubleshootingSteps() -> [HelpContext: [TroubleshootingStep]] {
        return [
            .recording: [
                TroubleshootingStep(
                    id: "recording-not-starting",
                    problem: "Recording won't start",
                    steps: [
                        "Check Screen Recording permission in System Settings",
                        "Verify sufficient disk space (>10GB free)",
                        "Restart the application",
                        "Check system logs for error messages"
                    ],
                    severity: .high
                ),
                TroubleshootingStep(
                    id: "poor-video-quality",
                    problem: "Poor video quality",
                    steps: [
                        "Increase recording resolution in settings",
                        "Check display scaling settings",
                        "Verify hardware acceleration is enabled",
                        "Test with single display first"
                    ],
                    severity: .medium
                )
            ],
            .performance: [
                TroubleshootingStep(
                    id: "high-cpu-usage",
                    problem: "High CPU usage",
                    steps: [
                        "Reduce recording quality to 'Balanced' mode",
                        "Lower frame rate to 15fps",
                        "Disable secondary display recording",
                        "Check for other screen recording software"
                    ],
                    severity: .high
                ),
                TroubleshootingStep(
                    id: "memory-issues",
                    problem: "High memory usage",
                    steps: [
                        "Restart the application",
                        "Clear processing caches",
                        "Reduce buffer sizes in advanced settings",
                        "Check for memory leaks in logs"
                    ],
                    severity: .medium
                )
            ]
        ]
    }
}

// MARK: - Data Models

public struct HelpItem: Identifiable {
    public let id: String
    public let title: String
    public let content: String
    public let keywords: [String]
    public let category: HelpCategory
    
    public enum HelpCategory {
        case overview
        case quickStart
        case procedure
        case configuration
        case reference
        case troubleshooting
    }
}

public struct QuickTip: Identifiable {
    public let id: String
    public let title: String
    public let content: String
}

public struct TroubleshootingStep: Identifiable {
    public let id: String
    public let problem: String
    public let steps: [String]
    public let severity: Severity
    
    public enum Severity {
        case low
        case medium
        case high
        case critical
        
        public var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

// MARK: - Help Analytics

public class HelpAnalytics {
    private let userDefaults = UserDefaults.standard
    
    public func trackHelpAccess(context: HelpContext) {
        let key = "help_access_\(context.rawValue)"
        let count = userDefaults.integer(forKey: key)
        userDefaults.set(count + 1, forKey: key)
    }
    
    public func trackHelpSearch(query: String) {
        let key = "help_searches"
        var searches = userDefaults.stringArray(forKey: key) ?? []
        searches.append(query)
        
        // Keep only last 100 searches
        if searches.count > 100 {
            searches = Array(searches.suffix(100))
        }
        
        userDefaults.set(searches, forKey: key)
    }
    
    public func getMostAccessedContexts() -> [HelpContext] {
        return HelpContext.allCases.sorted { context1, context2 in
            let count1 = userDefaults.integer(forKey: "help_access_\(context1.rawValue)")
            let count2 = userDefaults.integer(forKey: "help_access_\(context2.rawValue)")
            return count1 > count2
        }
    }
}