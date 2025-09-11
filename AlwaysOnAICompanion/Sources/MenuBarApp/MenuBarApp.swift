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
            // Recording Status
            HStack {
                Circle()
                    .fill(controller.isRecording ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(controller.isRecording ? "Recording" : "Stopped")
                    .font(.headline)
            }
            
            Divider()
            
            // Performance Metrics
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("CPU Usage:")
                    Spacer()
                    Text("\(controller.cpuUsage, specifier: "%.1f")%")
                }
                .font(.caption)
                
                HStack {
                    Text("Memory:")
                    Spacer()
                    Text("\(controller.memoryUsage, specifier: "%.1f") MB")
                }
                .font(.caption)
                
                HStack {
                    Text("Disk I/O:")
                    Spacer()
                    Text("\(controller.diskIO, specifier: "%.1f") MB/s")
                }
                .font(.caption)
            }
            
            Divider()
            
            // Controls
            VStack(spacing: 4) {
                Button(action: controller.toggleRecording) {
                    Text(controller.isRecording ? "Pause Recording" : "Resume Recording")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: controller.togglePrivacyMode) {
                    Text(controller.isPrivacyMode ? "Exit Privacy Mode" : "Privacy Mode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: controller.openSettings) {
                    Text("Settings...")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Quick Actions
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 250)
        .onAppear {
            controller.startMonitoring()
        }
    }
}