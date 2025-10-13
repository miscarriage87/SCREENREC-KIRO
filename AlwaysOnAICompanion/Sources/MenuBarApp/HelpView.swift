import SwiftUI

/// Main help interface for the Always-On AI Companion
public struct HelpView: View {
    @ObservedObject private var helpSystem = HelpSystem.shared
    @State private var selectedContext: HelpContext = .general
    @State private var searchText: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar with help categories
            HelpSidebar(selectedContext: $selectedContext)
        } detail: {
            // Main help content
            HelpContentView(
                context: selectedContext,
                searchText: $searchText
            )
        }
        .navigationTitle("Help & Support")
        .searchable(text: $searchText, prompt: "Search help topics...")
        .onChange(of: searchText) { newValue in
            helpSystem.searchHelp(newValue)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Close") {
                    helpSystem.hideHelp()
                }
            }
        }
    }
}

// MARK: - Help Sidebar

struct HelpSidebar: View {
    @Binding var selectedContext: HelpContext
    @ObservedObject private var helpSystem = HelpSystem.shared
    
    var body: some View {
        List(HelpContext.allCases, id: \.self, selection: $selectedContext) { context in
            HelpContextRow(context: context)
        }
        .navigationTitle("Topics")
        .listStyle(SidebarListStyle())
    }
}

struct HelpContextRow: View {
    let context: HelpContext
    
    var body: some View {
        HStack {
            Image(systemName: context.icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(context.displayName)
                .font(.body)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Help Content View

struct HelpContentView: View {
    let context: HelpContext
    @Binding var searchText: String
    @ObservedObject private var helpSystem = HelpSystem.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Context header
                HelpContextHeader(context: context)
                
                // Quick tips section
                QuickTipsSection(context: context)
                
                // Main help content
                HelpItemsSection(context: context, searchText: searchText)
                
                // Troubleshooting section
                TroubleshootingSection(context: context)
                
                // Additional resources
                AdditionalResourcesSection(context: context)
            }
            .padding()
        }
        .navigationTitle(context.displayName)
        .onAppear {
            helpSystem.showHelp(for: context)
        }
    }
}

// MARK: - Context Header

struct HelpContextHeader: View {
    let context: HelpContext
    
    var body: some View {
        HStack {
            Image(systemName: context.icon)
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(context.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(contextDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom)
    }
    
    private var contextDescription: String {
        switch context {
        case .general:
            return "Overview and getting started information"
        case .installation:
            return "Installation, setup, and initial configuration"
        case .recording:
            return "Screen recording and capture settings"
        case .privacy:
            return "Privacy controls and security features"
        case .settings:
            return "Configuration and customization options"
        case .performance:
            return "Performance optimization and monitoring"
        case .plugins:
            return "Plugin management and development"
        case .reports:
            return "Activity reports and data analysis"
        case .troubleshooting:
            return "Common issues and solutions"
        }
    }
}

// MARK: - Quick Tips Section

struct QuickTipsSection: View {
    let context: HelpContext
    @ObservedObject private var helpSystem = HelpSystem.shared
    
    var body: some View {
        let tips = helpSystem.getQuickTips()
        
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("Quick Tips")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(tips) { tip in
                        QuickTipCard(tip: tip)
                    }
                }
            }
            .padding(.bottom)
        }
    }
}

struct QuickTipCard: View {
    let tip: QuickTip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tip.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(tip.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Help Items Section

struct HelpItemsSection: View {
    let context: HelpContext
    let searchText: String
    @ObservedObject private var helpSystem = HelpSystem.shared
    
    var body: some View {
        let helpItems = helpSystem.getContextualHelp()
        
        if !helpItems.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("Help Articles")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ForEach(helpItems) { item in
                    HelpItemCard(item: item, searchText: searchText)
                }
            }
        } else if !searchText.isEmpty {
            NoSearchResultsView(searchText: searchText)
        }
    }
}

struct HelpItemCard: View {
    let item: HelpItem
    let searchText: String
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(highlightedTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(highlightedContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                
                if !item.keywords.isEmpty {
                    HStack {
                        Text("Keywords:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(item.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            // Auto-expand if this item matches the search
            if !searchText.isEmpty && item.title.localizedCaseInsensitiveContains(searchText) {
                isExpanded = true
            }
        }
    }
    
    private var highlightedTitle: AttributedString {
        highlightText(item.title, searchTerm: searchText)
    }
    
    private var highlightedContent: AttributedString {
        highlightText(item.content, searchTerm: searchText)
    }
    
    private func highlightText(_ text: String, searchTerm: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        if !searchTerm.isEmpty {
            let ranges = text.ranges(of: searchTerm, options: .caseInsensitive)
            for range in ranges {
                let attributedRange = Range(range, in: attributedString)!
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attributedRange].foregroundColor = .primary
            }
        }
        
        return attributedString
    }
}

struct NoSearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No results found for '\(searchText)'")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try different keywords or browse the help categories")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Troubleshooting Section

struct TroubleshootingSection: View {
    let context: HelpContext
    @ObservedObject private var helpSystem = HelpSystem.shared
    
    var body: some View {
        let troubleshootingSteps = helpSystem.getTroubleshootingSteps()
        
        if !troubleshootingSteps.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(.orange)
                    Text("Troubleshooting")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ForEach(troubleshootingSteps) { step in
                    TroubleshootingCard(step: step)
                }
            }
        }
    }
}

struct TroubleshootingCard: View {
    let step: TroubleshootingStep
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Circle()
                        .fill(step.severity.color)
                        .frame(width: 8, height: 8)
                    
                    Text(step.problem)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(step.steps.enumerated()), id: \.offset) { index, stepText in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            Text(stepText)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(step.severity.color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Additional Resources Section

struct AdditionalResourcesSection: View {
    let context: HelpContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.blue)
                Text("Additional Resources")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ResourceLink(
                    title: "User Guide",
                    description: "Comprehensive user documentation",
                    action: { openUserGuide() }
                )
                
                ResourceLink(
                    title: "Developer Guide",
                    description: "Plugin development and system extension",
                    action: { openDeveloperGuide() }
                )
                
                ResourceLink(
                    title: "Troubleshooting Guide",
                    description: "Detailed troubleshooting and diagnostics",
                    action: { openTroubleshootingGuide() }
                )
                
                ResourceLink(
                    title: "System Diagnostics",
                    description: "Run comprehensive system check",
                    action: { runDiagnostics() }
                )
                
                ResourceLink(
                    title: "Contact Support",
                    description: "Get help from our support team",
                    action: { contactSupport() }
                )
            }
        }
        .padding(.top)
    }
    
    private func openUserGuide() {
        if let url = Bundle.main.url(forResource: "USER_GUIDE", withExtension: "md", subdirectory: "Documentation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openDeveloperGuide() {
        if let url = Bundle.main.url(forResource: "DEVELOPER_GUIDE", withExtension: "md", subdirectory: "Documentation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openTroubleshootingGuide() {
        if let url = Bundle.main.url(forResource: "TROUBLESHOOTING", withExtension: "md", subdirectory: "Documentation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func runDiagnostics() {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "cd /Applications/AlwaysOnAICompanion.app/Contents/Resources/Scripts && ./diagnose.sh --comprehensive"]
        task.launch()
    }
    
    private func contactSupport() {
        if let url = URL(string: "mailto:support@yourorg.com?subject=Always-On%20AI%20Companion%20Support") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct ResourceLink: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - String Extension for Search Highlighting

extension String {
    func ranges(of searchString: String, options: CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = self.startIndex
        
        while searchStartIndex < self.endIndex,
              let range = self.range(of: searchString, options: options, range: searchStartIndex..<self.endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }
        
        return ranges
    }
}

// MARK: - Preview

#if DEBUG
struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
            .frame(width: 800, height: 600)
    }
}
#endif