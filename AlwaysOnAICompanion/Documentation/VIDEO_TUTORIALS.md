# Video Tutorial Scripts and Production Guide

## Overview

This document contains scripts and production guidelines for creating video tutorials for the Always-On AI Companion system. These tutorials provide visual, step-by-step guidance for key system features and workflows.

## Tutorial Series Structure

### 1. Getting Started Series (5-7 minutes each)

#### Tutorial 1.1: Installation and Setup
**Duration**: 6 minutes  
**Target Audience**: New users  
**Prerequisites**: None

**Script**:

```
[INTRO - 0:00-0:15]
"Welcome to Always-On AI Companion! I'm going to show you how to install and set up the system in just a few minutes. By the end of this tutorial, you'll have a fully functional AI companion recording and analyzing your screen activity."

[DOWNLOAD AND INSTALL - 0:15-1:30]
"First, let's download the installer. Go to our releases page and download the latest installer package."

[Show browser navigation to releases page]
[Download the .pkg file]

"Once downloaded, double-click the installer package. You'll need administrator privileges, so enter your password when prompted."

[Show installer running]
[Demonstrate permission prompts]

"The installer will automatically set up all system components and request the necessary permissions."

[PERMISSION SETUP - 1:30-3:00]
"The system needs two key permissions to function properly. First is Screen Recording permission."

[Show System Settings navigation]
[Navigate to Privacy & Security → Screen Recording]
[Add and enable Always-On AI Companion]

"Next, we need Accessibility permission for hotkey functionality and window detection."

[Navigate to Privacy & Security → Accessibility]
[Add and enable Always-On AI Companion]

"These permissions are essential for the system to capture and analyze your screen activity securely."

[FIRST LAUNCH - 3:00-4:30]
"Now let's launch the application. You'll find it in your Applications folder, or it may have started automatically."

[Show Applications folder]
[Launch the app]
[Show menu bar icon appearing]

"The menu bar icon indicates the system is running. Let's click it to see the initial setup wizard."

[Click menu bar icon]
[Show setup wizard]

"The setup wizard will guide you through initial configuration. First, select which displays you want to monitor."

[Show display selection]
[Configure quality settings]

[VERIFICATION - 4:30-5:30]
"Let's verify everything is working correctly. The menu bar icon should show a green dot, indicating active recording."

[Show recording status]
[Demonstrate pause/resume functionality]

"You can pause recording anytime using the hotkey Cmd+Shift+P, or click the menu bar icon."

[WRAP UP - 5:30-6:00]
"That's it! Your Always-On AI Companion is now set up and recording. In the next tutorial, we'll explore the privacy controls and how to customize your recording preferences."
```

#### Tutorial 1.2: Privacy Controls and Security
**Duration**: 7 minutes  
**Target Audience**: New users concerned about privacy  
**Prerequisites**: Tutorial 1.1

**Script**:

```
[INTRO - 0:00-0:20]
"Privacy is a core principle of Always-On AI Companion. In this tutorial, I'll show you all the privacy controls available and how to configure them for your needs. Everything we'll cover happens locally on your Mac - no data leaves your computer unless you explicitly choose to sync it."

[IMMEDIATE PRIVACY CONTROLS - 0:20-1:30]
"Let's start with immediate privacy controls. The fastest way to pause recording is the hotkey Cmd+Shift+P."

[Demonstrate hotkey]
[Show menu bar icon changing to paused state]

"For emergency situations, use Cmd+Shift+Esc for an immediate stop that responds within 100 milliseconds."

[Demonstrate emergency hotkey]

"You can also use Privacy Mode for temporary protection."

[Show Privacy Mode toggle in menu]
[Demonstrate visual indicators]

[APPLICATION ALLOWLISTS - 1:30-3:30]
"Now let's configure which applications to monitor. Open Settings from the menu bar."

[Navigate to Settings → Privacy → Application Allowlist]

"You can choose to monitor all applications, or create a custom allowlist. Let's add a specific application."

[Demonstrate adding applications to allowlist]
[Show per-application rules]

"For each application, you can set different monitoring levels - always monitor, never monitor, or conditional monitoring based on window titles."

[Configure different monitoring rules]

[PII PROTECTION - 3:30-5:00]
"The system automatically detects and masks sensitive information like credit card numbers and social security numbers."

[Navigate to PII Protection settings]
[Show automatic detection patterns]

"You can add custom patterns for your organization's sensitive data."

[Demonstrate adding custom PII patterns]
[Show masking in action with sample data]

[SCREEN-SPECIFIC PRIVACY - 5:00-6:00]
"For multi-monitor setups, you can configure different privacy levels per display."

[Navigate to Display Settings]
[Show per-display privacy configuration]

"This is useful if you have a dedicated monitor for sensitive work."

[AUDIT AND VERIFICATION - 6:00-6:40]
"You can run a privacy audit to check your existing data for any sensitive information."

[Demonstrate privacy audit tool]
[Show audit results]

[WRAP UP - 6:40-7:00]
"These privacy controls ensure your sensitive information stays protected while still providing valuable insights about your work patterns. Next, we'll explore how to generate and customize activity reports."
```

### 2. Advanced Features Series (8-10 minutes each)

#### Tutorial 2.1: Activity Reports and Analysis
**Duration**: 9 minutes  
**Target Audience**: Users familiar with basic operation  
**Prerequisites**: Tutorials 1.1, 1.2

**Script**:

```
[INTRO - 0:00-0:20]
"Now that you have Always-On AI Companion running, let's explore one of its most powerful features - activity reports and analysis. I'll show you how to generate comprehensive reports about your work patterns and share actionable insights with your team."

[ACCESSING REPORTS - 0:20-1:00]
"To access reports, click the menu bar icon and select 'Reports'. You'll see several options for different types of analysis."

[Show Reports menu]
[Navigate through different report types]

"Let's start with a daily activity summary."

[DAILY ACTIVITY SUMMARY - 1:00-2:30]
"Select 'Daily Summary' and choose yesterday's date. The system will generate a comprehensive report of your activities."

[Generate daily summary]
[Show report generation progress]

"The report includes a narrative summary of your work, time spent in different applications, and key events detected throughout the day."

[Review generated report sections]
[Highlight narrative summary]
[Show application time breakdown]
[Point out detected events]

[WORKFLOW ANALYSIS - 2:30-4:00]
"The workflow analysis shows patterns in how you work. Notice how it identifies task switching, focus periods, and interruptions."

[Navigate to workflow section]
[Explain focus time analysis]
[Show interruption patterns]

"This heat map shows your most productive hours and when you're most likely to be interrupted."

[Explain productivity heat map]

[CUSTOM REPORTS - 4:00-5:30]
"You can create custom reports for specific date ranges or projects. Let's create a weekly report for a specific project."

[Navigate to Custom Reports]
[Set date range]
[Configure project filters]
[Generate custom report]

"The system can filter activities by application, window titles, or even specific keywords detected in your screen content."

[EXPORTING AND SHARING - 5:30-7:00]
"Reports can be exported in multiple formats. Markdown is great for documentation, CSV for data analysis, and JSON for integration with other tools."

[Demonstrate export options]
[Export sample report in different formats]
[Show exported files]

"For team collaboration, the Playbook feature creates step-by-step guides based on your actual workflows."

[Generate playbook from workflow]
[Show playbook format]

[EVIDENCE LINKING - 7:00-8:00]
"Every insight in your reports links back to the original evidence. Click any event or summary to see the source screenshots and data."

[Demonstrate evidence linking]
[Show source frames]
[Navigate back to report]

[AUTOMATION AND SCHEDULING - 8:00-8:40]
"You can schedule automatic report generation for regular team updates or personal review."

[Configure scheduled reports]
[Set up email delivery]

[WRAP UP - 8:40-9:00]
"Activity reports transform your screen recordings into actionable insights. Experiment with different report types to find what works best for your workflow. In our next tutorial, we'll explore the plugin system for specialized applications."
```

#### Tutorial 2.2: Plugin System and Customization
**Duration**: 10 minutes  
**Target Audience**: Advanced users, developers  
**Prerequisites**: All previous tutorials

**Script**:

```
[INTRO - 0:00-0:25]
"The plugin system is what makes Always-On AI Companion truly powerful for specialized workflows. In this tutorial, I'll show you how to install, configure, and even create custom plugins for your specific applications and needs."

[PLUGIN OVERVIEW - 0:25-1:15]
"Plugins extend the system's ability to understand application-specific content. Let's see what plugins are available."

[Navigate to Settings → Plugins]
[Show available plugins list]

"We have built-in plugins for web browsers, productivity tools like Jira and Salesforce, and terminal applications. Each plugin provides specialized parsing for better understanding of your workflows."

[INSTALLING PLUGINS - 1:15-2:30]
"Let's install the Web Browser plugin to enhance web application analysis."

[Select Web Browser plugin]
[Show plugin details and permissions]
[Install plugin]

"Plugins run in sandboxed environments for security. This plugin requests OCR access and event generation permissions."

[Show plugin installation progress]
[Verify plugin is active]

[CONFIGURING PLUGINS - 2:30-4:00]
"Each plugin has its own configuration options. Let's configure the Web Browser plugin for better analysis of web applications."

[Open plugin configuration]
[Configure URL patterns]
[Set up DOM analysis rules]
[Adjust sensitivity settings]

"You can specify which websites to analyze more deeply, and configure how the plugin interprets different web application interfaces."

[PLUGIN IN ACTION - 4:00-5:30]
"Let's see the plugin in action. I'll navigate to a web application and show how the enhanced parsing works."

[Open web browser]
[Navigate to sample web application]
[Show enhanced OCR results]
[Demonstrate improved event detection]

"Notice how the plugin now detects form submissions, navigation events, and application-specific workflows that weren't visible before."

[PRODUCTIVITY PLUGINS - 5:30-6:45]
"The Productivity plugin provides specialized parsing for tools like Jira and Salesforce."

[Enable Productivity plugin]
[Configure for Jira]
[Show Jira-specific event detection]

"It can detect ticket status changes, comment additions, and workflow progressions automatically."

[TERMINAL PLUGIN - 6:45-7:30]
"For developers, the Terminal plugin analyzes command-line activities."

[Enable Terminal plugin]
[Show terminal session analysis]
[Demonstrate command detection]

"It tracks command execution, error detection, and can even identify deployment workflows."

[CREATING CUSTOM PLUGINS - 7:30-9:00]
"For advanced users, you can create custom plugins. The Developer Guide provides complete documentation, but let me show you the basics."

[Open plugin development template]
[Show plugin structure]
[Explain key interfaces]

"A plugin implements the PluginProtocol interface and provides methods for parsing OCR results and detecting events specific to your application."

[Show code example]
[Explain plugin lifecycle]

[PLUGIN MANAGEMENT - 9:00-9:40]
"You can enable, disable, and update plugins as needed. The system automatically checks for plugin updates."

[Show plugin management interface]
[Demonstrate enable/disable]
[Check for updates]

[WRAP UP - 9:40-10:00]
"Plugins make Always-On AI Companion adaptable to any workflow. Start with the built-in plugins, then explore creating custom ones for your specific needs. Check the Developer Guide for complete plugin development documentation."
```

### 3. Troubleshooting Series (5-8 minutes each)

#### Tutorial 3.1: Performance Optimization
**Duration**: 7 minutes  
**Target Audience**: Users experiencing performance issues  
**Prerequisites**: Basic familiarity with the system

**Script**:

```
[INTRO - 0:00-0:20]
"If you're experiencing performance issues with Always-On AI Companion, this tutorial will help you optimize the system for your hardware and usage patterns. We'll cover monitoring, diagnosis, and optimization techniques."

[PERFORMANCE MONITORING - 0:20-1:30]
"First, let's check current performance metrics. Click the menu bar icon and select 'System Status'."

[Show system status interface]
[Highlight CPU usage]
[Show memory consumption]
[Display storage usage]

"Healthy operation should show CPU usage below 8%, memory usage under 500MB, and adequate storage space."

[Point out performance indicators]

[IDENTIFYING BOTTLENECKS - 1:30-2:45]
"If you see high resource usage, let's identify the bottleneck. Open the performance monitor for detailed analysis."

[Navigate to performance monitor]
[Show real-time metrics]
[Identify high CPU components]

"The breakdown shows which components are using the most resources. Recording and OCR processing are typically the most intensive."

[OPTIMIZING RECORDING SETTINGS - 2:45-4:15]
"Let's optimize recording settings for better performance. Go to Settings → Recording."

[Navigate to recording settings]
[Show quality options]

"Reducing from 'High' to 'Balanced' quality can significantly improve performance while maintaining good analysis quality."

[Change quality setting]
[Adjust frame rate to 15fps]
[Configure single display if needed]

"For multi-monitor setups, consider recording only your primary display during intensive work."

[OPTIMIZING PROCESSING - 4:15-5:30]
"Next, let's optimize processing intervals. Go to Settings → Advanced."

[Navigate to advanced settings]
[Adjust OCR processing interval]
[Configure event detection frequency]

"Increasing processing intervals reduces CPU usage at the cost of slightly delayed analysis."

[Show before/after performance metrics]

[STORAGE OPTIMIZATION - 5:30-6:15]
"Storage performance affects the entire system. Enable compression and configure aggressive cleanup."

[Navigate to storage settings]
[Enable compression]
[Configure retention policies]
[Set up automatic cleanup]

[HARDWARE RECOMMENDATIONS - 6:15-6:45]
"For optimal performance, consider these hardware upgrades: SSD storage provides the biggest improvement, followed by additional RAM for multi-monitor setups."

[Show performance comparison chart]

[WRAP UP - 6:45-7:00]
"These optimizations should significantly improve performance. Monitor the system status regularly and adjust settings based on your usage patterns."
```

## Production Guidelines

### Technical Requirements

#### Recording Setup
- **Resolution**: 1920x1080 minimum, 4K preferred for screen recordings
- **Frame Rate**: 30fps for smooth demonstration
- **Audio**: Clear narration with noise cancellation
- **Screen Recording Software**: Use native macOS screen recording or professional tools

#### Post-Production
- **Editing Software**: Final Cut Pro, Adobe Premiere, or DaVinci Resolve
- **Compression**: H.264 with high quality settings
- **Captions**: Include accurate closed captions for accessibility
- **Thumbnails**: Create engaging thumbnails with clear titles

### Visual Guidelines

#### Screen Recording Best Practices
1. **Clean Desktop**: Remove distracting elements from desktop
2. **Consistent Cursor**: Use cursor highlighting for important actions
3. **Zoom Effects**: Zoom in on small UI elements for clarity
4. **Smooth Transitions**: Use smooth panning between different areas
5. **Consistent Timing**: Allow sufficient time for viewers to read text

#### UI Highlighting
- **Mouse Clicks**: Highlight clicks with visual effects
- **Keyboard Shortcuts**: Show on-screen keyboard visualization
- **Important Areas**: Use callout boxes or arrows for emphasis
- **Color Coding**: Consistent color scheme for different types of actions

### Audio Guidelines

#### Narration Standards
- **Pace**: Moderate speaking pace (150-160 words per minute)
- **Clarity**: Clear pronunciation and enunciation
- **Tone**: Professional but friendly and approachable
- **Pauses**: Strategic pauses for complex concepts
- **Volume**: Consistent audio levels throughout

#### Script Guidelines
- **Conversational**: Write as you would speak, not formal documentation
- **Active Voice**: Use active voice for clearer instructions
- **Step-by-Step**: Break complex procedures into clear steps
- **Anticipate Questions**: Address common questions proactively

### Accessibility Requirements

#### Visual Accessibility
- **High Contrast**: Ensure sufficient contrast in all demonstrations
- **Text Size**: Use readable text sizes in all UI elements
- **Color Independence**: Don't rely solely on color to convey information
- **Motion Sensitivity**: Avoid rapid flashing or excessive motion

#### Audio Accessibility
- **Closed Captions**: Accurate, synchronized captions for all speech
- **Audio Descriptions**: Describe important visual elements
- **Multiple Formats**: Provide transcripts alongside videos
- **Language Support**: Consider multiple language versions

### Distribution Strategy

#### Platform Optimization
- **YouTube**: Optimized for search and discovery
- **Documentation Site**: Embedded in help documentation
- **In-App**: Accessible through the help system
- **Social Media**: Shorter clips for social platforms

#### SEO and Discovery
- **Titles**: Clear, searchable titles with relevant keywords
- **Descriptions**: Detailed descriptions with timestamps
- **Tags**: Relevant tags for categorization
- **Thumbnails**: Eye-catching thumbnails that represent content

### Quality Assurance

#### Review Checklist
- [ ] Audio quality is clear and consistent
- [ ] Visual quality is sharp and readable
- [ ] All steps are accurate and reproducible
- [ ] Timing allows for comfortable following
- [ ] Captions are accurate and synchronized
- [ ] No sensitive information is visible
- [ ] Branding is consistent throughout
- [ ] Call-to-actions are clear and appropriate

#### Testing Process
1. **Internal Review**: Team members follow tutorial steps
2. **User Testing**: External users test with fresh installations
3. **Accessibility Testing**: Verify with screen readers and accessibility tools
4. **Performance Testing**: Ensure tutorials work across different hardware
5. **Update Verification**: Confirm tutorials remain accurate with software updates

### Maintenance and Updates

#### Version Control
- **Script Versioning**: Track changes to tutorial scripts
- **Video Versioning**: Maintain version history of video files
- **Update Schedule**: Regular review and update cycle
- **Change Documentation**: Track what changes require tutorial updates

#### Analytics and Improvement
- **View Analytics**: Monitor which tutorials are most/least viewed
- **User Feedback**: Collect and analyze user feedback
- **Completion Rates**: Track where users drop off in tutorials
- **Search Queries**: Analyze help system search queries for content gaps

### Future Tutorial Topics

#### Planned Tutorials
1. **Advanced Privacy Configuration**: Deep dive into privacy settings
2. **Enterprise Deployment**: Installation and management for organizations
3. **API Integration**: Using the system with external tools
4. **Custom Plugin Development**: Complete plugin development workflow
5. **Data Analysis Workflows**: Advanced report generation and analysis
6. **Backup and Recovery**: Data protection and disaster recovery
7. **Multi-User Environments**: Shared system configurations
8. **Performance Tuning**: Advanced optimization techniques

#### Community Contributions
- **User-Generated Content**: Encourage community tutorial creation
- **Guest Experts**: Collaborate with power users for specialized content
- **Localization**: Translate popular tutorials to other languages
- **Platform-Specific**: Tutorials for specific industries or use cases