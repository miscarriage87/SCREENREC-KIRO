import Foundation
import SwiftUI
import AppKit

/// Visual status indicator for recording and privacy states
public class StatusIndicatorManager: ObservableObject {
    public static let shared = StatusIndicatorManager()
    
    @Published public private(set) var currentIndicator: StatusIndicator = .stopped
    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var shouldPulse: Bool = false
    
    private var indicatorWindow: NSWindow?
    private var pulseTimer: Timer?
    private let logger = Logger.shared
    
    private init() {}
    
    deinit {
        hideIndicator()
        pulseTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    /// Updates the status indicator based on privacy state
    public func updateIndicator(for privacyState: PrivacyState) {
        let newIndicator = StatusIndicator.from(privacyState: privacyState)
        
        DispatchQueue.main.async {
            self.currentIndicator = newIndicator
            self.shouldPulse = newIndicator.shouldPulse
            
            if newIndicator.shouldShow {
                self.showIndicator()
            } else {
                self.hideIndicator()
            }
            
            if self.shouldPulse {
                self.startPulseAnimation()
            } else {
                self.stopPulseAnimation()
            }
        }
        
        logger.info("Status indicator updated: \(newIndicator.description)")
    }
    
    /// Shows a temporary notification indicator
    public func showTemporaryNotification(_ message: String, type: StatusIndicator.NotificationType, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            let notification = StatusIndicator.notification(message: message, type: type)
            self.currentIndicator = notification
            self.showIndicator()
            
            // Hide after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.hideIndicator()
            }
        }
    }
    
    /// Manually shows the indicator
    public func showIndicator() {
        guard !isVisible else { return }
        
        DispatchQueue.main.async {
            self.createIndicatorWindow()
            self.isVisible = true
        }
    }
    
    /// Manually hides the indicator
    public func hideIndicator() {
        guard isVisible else { return }
        
        DispatchQueue.main.async {
            self.indicatorWindow?.close()
            self.indicatorWindow = nil
            self.isVisible = false
            self.stopPulseAnimation()
        }
    }
    
    // MARK: - Private Methods
    
    private func createIndicatorWindow() {
        // Create a small overlay window in the top-right corner
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = NSSize(width: 200, height: 60)
        let windowFrame = NSRect(
            x: screenFrame.maxX - windowSize.width - 20,
            y: screenFrame.maxY - windowSize.height - 20,
            width: windowSize.width,
            height: windowSize.height
        )
        
        indicatorWindow = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = indicatorWindow else { return }
        
        // Configure window properties
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Create the content view
        let contentView = StatusIndicatorView(indicator: currentIndicator)
        window.contentView = NSHostingView(rootView: contentView)
        
        // Show the window
        window.orderFrontRegardless()
        
        logger.debug("Status indicator window created and shown")
    }
    
    private func startPulseAnimation() {
        stopPulseAnimation()
        
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                // Trigger pulse animation by updating the view
                self?.objectWillChange.send()
            }
        }
    }
    
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}

// MARK: - Status Indicator Model
public struct StatusIndicator {
    public let type: IndicatorType
    public let color: Color
    public let icon: String
    public let text: String
    public let shouldShow: Bool
    public let shouldPulse: Bool
    
    public enum IndicatorType {
        case recording
        case paused
        case privacyMode
        case emergencyStop
        case notification(NotificationType)
        case stopped
    }
    
    public enum NotificationType {
        case info
        case warning
        case error
        case success
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
    
    public var description: String {
        return "\(type) - \(text)"
    }
    
    // MARK: - Factory Methods
    
    public static func from(privacyState: PrivacyState) -> StatusIndicator {
        switch privacyState {
        case .recording:
            return StatusIndicator(
                type: .recording,
                color: .red,
                icon: "record.circle.fill",
                text: "Recording",
                shouldShow: true,
                shouldPulse: true
            )
        case .paused:
            return StatusIndicator(
                type: .paused,
                color: .orange,
                icon: "pause.circle.fill",
                text: "Paused",
                shouldShow: true,
                shouldPulse: false
            )
        case .privacyMode:
            return StatusIndicator(
                type: .privacyMode,
                color: .blue,
                icon: "eye.slash.circle.fill",
                text: "Privacy Mode",
                shouldShow: true,
                shouldPulse: true
            )
        case .emergencyStop:
            return StatusIndicator(
                type: .emergencyStop,
                color: .red,
                icon: "stop.circle.fill",
                text: "Emergency Stop",
                shouldShow: true,
                shouldPulse: false
            )
        }
    }
    
    public static func notification(message: String, type: NotificationType) -> StatusIndicator {
        return StatusIndicator(
            type: .notification(type),
            color: type.color,
            icon: type.icon,
            text: message,
            shouldShow: true,
            shouldPulse: false
        )
    }
    
    public static let stopped = StatusIndicator(
        type: .stopped,
        color: .gray,
        icon: "stop.circle",
        text: "Stopped",
        shouldShow: false,
        shouldPulse: false
    )
}

// MARK: - SwiftUI View
struct StatusIndicatorView: View {
    let indicator: StatusIndicator
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: indicator.icon)
                .foregroundColor(indicator.color)
                .font(.system(size: 16, weight: .medium))
                .scaleEffect(indicator.shouldPulse ? pulseScale : 1.0)
                .animation(
                    indicator.shouldPulse ? 
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                        .none,
                    value: pulseScale
                )
            
            Text(indicator.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            if indicator.shouldPulse {
                pulseScale = 1.2
            }
        }
    }
}

// MARK: - Menu Bar Status Item
public class MenuBarStatusItem {
    public static let shared = MenuBarStatusItem()
    
    private var statusItem: NSStatusItem?
    private let logger = Logger.shared
    
    private init() {}
    
    /// Creates or updates the menu bar status item
    public func updateStatusItem(for privacyState: PrivacyState) {
        DispatchQueue.main.async {
            if self.statusItem == nil {
                self.createStatusItem()
            }
            
            self.updateStatusItemAppearance(for: privacyState)
        }
    }
    
    /// Removes the status item from the menu bar
    public func removeStatusItem() {
        DispatchQueue.main.async {
            if let statusItem = self.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }
    
    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else {
            logger.error("Failed to create menu bar status item")
            return
        }
        
        // Set up the button
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        logger.info("Menu bar status item created")
    }
    
    private func updateStatusItemAppearance(for privacyState: PrivacyState) {
        guard let button = statusItem?.button else { return }
        
        let (icon, color) = iconAndColor(for: privacyState)
        
        // Create attributed string with icon and color
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 16, weight: .medium)
        ]
        
        button.attributedTitle = NSAttributedString(string: icon, attributes: attributes)
        button.toolTip = "Always-On AI Companion - \(privacyState.description)"
    }
    
    private func iconAndColor(for privacyState: PrivacyState) -> (String, NSColor) {
        switch privacyState {
        case .recording:
            return ("●", .systemRed)
        case .paused:
            return ("⏸", .systemOrange)
        case .privacyMode:
            return ("👁", .systemBlue)
        case .emergencyStop:
            return ("⏹", .systemRed)
        }
    }
    
    @objc private func statusItemClicked() {
        // Handle status item clicks - could show menu or toggle state
        logger.info("Menu bar status item clicked")
        
        // For now, just toggle recording state
        PrivacyController.shared.toggleRecording()
    }
}