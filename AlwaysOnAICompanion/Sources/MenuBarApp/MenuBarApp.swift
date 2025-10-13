import SwiftUI
import Shared

@main
struct MenuBarApp: App {
    @StateObject private var menuBarController = MenuBarController()
    
    var body: some Scene {
        MenuBarExtra("Always-On AI Companion", systemImage: "record.circle") {
            MenuBarView()
                .environmentObject(menuBarController)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarView: View {
    @EnvironmentObject var controller: MenuBarController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recording Status Header
            HStack {
                StatusIndicator(state: controller.privacyState)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.privacyState.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if controller.hotkeyResponseTime > 0 {
                        Text("Response: \(controller.hotkeyResponseTime * 1000, specifier: "%.0f")ms")
                            .font(.caption2)
                            .foregroundColor(controller.hotkeyResponseTime > 0.1 ? .red : .green)
                    }
                }
                Spacer()
            }
            
            Divider()
            
            // Performance Metrics with Progress Bars
            VStack(alignment: .leading, spacing: 6) {
                Text("Performance")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                PerformanceMetric(
                    label: "CPU Usage",
                    value: controller.cpuUsage,
                    maxValue: 8.0,
                    unit: "%",
                    warningThreshold: 6.0
                )
                
                PerformanceMetric(
                    label: "Memory",
                    value: controller.memoryUsage,
                    maxValue: 500.0,
                    unit: "MB",
                    warningThreshold: 400.0
                )
                
                PerformanceMetric(
                    label: "Disk I/O",
                    value: controller.diskIO,
                    maxValue: 20.0,
                    unit: "MB/s",
                    warningThreshold: 15.0
                )
            }
            
            Divider()
            
            // Controls with Enhanced Feedback
            VStack(spacing: 6) {
                Button(action: controller.toggleRecording) {
                    HStack {
                        Image(systemName: controller.isRecording ? "pause.circle.fill" : "play.circle.fill")
                        Text(controller.isRecording ? "Pause Recording" : "Resume Recording")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(controller.privacyState == .emergencyStop)
                
                Button(action: controller.togglePrivacyMode) {
                    HStack {
                        Image(systemName: controller.isPrivacyMode ? "eye" : "eye.slash")
                        Text(controller.isPrivacyMode ? "Exit Privacy Mode" : "Privacy Mode")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(controller.privacyState == .emergencyStop)
                
                if controller.privacyState == .emergencyStop {
                    Button(action: controller.resetEmergencyStop) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset Emergency Stop")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                Button(action: controller.openSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings...")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // System Status and Quick Actions
            VStack(spacing: 4) {
                HStack {
                    Text("System Status:")
                    Spacer()
                    SystemHealthIndicator(controller: controller)
                }
                .font(.caption)
                
                HStack {
                    Button("Export Data") {
                        controller.exportData()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    
                    Spacer()
                    
                    Button("Quit") {
                        controller.gracefulShutdown()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            // Version and Build Info
            HStack {
                Text("v1.0.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let buildDate = controller.buildDate {
                    Text(buildDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            controller.startMonitoring()
        }
        .onDisappear {
            // Don't stop monitoring when menu closes, keep running in background
        }
    }
}

struct StatusIndicator: View {
    let state: PrivacyState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(state.color.opacity(0.3), lineWidth: 2)
                        .scaleEffect(state == .recording ? 1.5 : 1.0)
                        .opacity(state == .recording ? 0 : 1)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: state == .recording)
                )
            
            if state == .emergencyStop {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}

struct PerformanceMetric: View {
    let label: String
    let value: Double
    let maxValue: Double
    let unit: String
    let warningThreshold: Double
    
    private var percentage: Double {
        min(value / maxValue, 1.0)
    }
    
    private var isWarning: Bool {
        value > warningThreshold
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value, specifier: "%.1f")\(unit)")
                    .foregroundColor(isWarning ? .orange : .primary)
            }
            .font(.caption)
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: isWarning ? .orange : .blue))
                .scaleEffect(y: 0.5)
        }
    }
}

struct SystemHealthIndicator: View {
    @ObservedObject var controller: MenuBarController
    
    private var healthStatus: (String, Color) {
        let cpuOK = controller.cpuUsage <= 8.0
        let memoryOK = controller.memoryUsage <= 500.0
        let diskOK = controller.diskIO <= 20.0
        let responseOK = controller.hotkeyResponseTime <= 0.1
        
        if cpuOK && memoryOK && diskOK && responseOK {
            return ("Healthy", .green)
        } else if !responseOK || controller.cpuUsage > 10.0 {
            return ("Warning", .orange)
        } else {
            return ("Degraded", .red)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(healthStatus.1)
                .frame(width: 6, height: 6)
            Text(healthStatus.0)
                .foregroundColor(healthStatus.1)
        }
    }
}

extension PrivacyState {
    var displayName: String {
        switch self {
        case .recording: return "Recording Active"
        case .paused: return "Recording Paused"
        case .privacyMode: return "Privacy Mode"
        case .emergencyStop: return "Emergency Stop"
        }
    }
    
    var color: Color {
        switch self {
        case .recording: return .green
        case .paused: return .orange
        case .privacyMode: return .blue
        case .emergencyStop: return .red
        }
    }
}