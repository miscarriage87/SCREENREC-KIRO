import Foundation

/// Groups related events into coherent activity sessions
public class ActivitySessionGrouper {
    
    /// Configuration for session grouping behavior
    public struct Configuration {
        /// Maximum gap between events to consider them part of the same session (seconds)
        public let maxEventGap: TimeInterval
        /// Minimum duration for a valid session (seconds)
        public let minSessionDuration: TimeInterval
        /// Minimum number of events required for a session
        public let minEventsPerSession: Int
        /// Maximum number of events in a single session before splitting
        public let maxEventsPerSession: Int
        /// Similarity threshold for grouping events by application/context
        public let contextSimilarityThreshold: Float
        
        public init(
            maxEventGap: TimeInterval = 300, // 5 minutes
            minSessionDuration: TimeInterval = 60, // 1 minute
            minEventsPerSession: Int = 3,
            maxEventsPerSession: Int = 50,
            contextSimilarityThreshold: Float = 0.7
        ) {
            self.maxEventGap = maxEventGap
            self.minSessionDuration = minSessionDuration
            self.minEventsPerSession = minEventsPerSession
            self.maxEventsPerSession = maxEventsPerSession
            self.contextSimilarityThreshold = contextSimilarityThreshold
        }
    }
    
    private let configuration: Configuration
    
    /// Initialize the session grouper
    /// - Parameter configuration: Configuration for grouping behavior
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    /// Group events into coherent activity sessions
    /// - Parameter events: Array of events to group
    /// - Returns: Array of activity sessions
    public func groupEventsIntoSessions(_ events: [ActivityEvent]) throws -> [ActivitySession] {
        guard !events.isEmpty else {
            return []
        }
        
        // Sort events chronologically
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        
        // Perform initial temporal grouping
        let temporalGroups = performTemporalGrouping(sortedEvents)
        
        // Refine groups based on context and application
        let contextualGroups = refineGroupsByContext(temporalGroups)
        
        // Convert groups to activity sessions
        var sessions: [ActivitySession] = []
        
        for group in contextualGroups {
            if let session = createActivitySession(from: group) {
                sessions.append(session)
            }
        }
        
        return sessions
    }
    
    /// Perform initial grouping based on temporal proximity
    private func performTemporalGrouping(_ events: [ActivityEvent]) -> [[ActivityEvent]] {
        var groups: [[ActivityEvent]] = []
        var currentGroup: [ActivityEvent] = []
        
        for event in events {
            if currentGroup.isEmpty {
                // Start new group
                currentGroup.append(event)
            } else {
                let lastEvent = currentGroup.last!
                let timeDifference = event.timestamp.timeIntervalSince(lastEvent.timestamp)
                
                if timeDifference <= configuration.maxEventGap {
                    // Add to current group
                    currentGroup.append(event)
                    
                    // Check if group is getting too large
                    if currentGroup.count >= configuration.maxEventsPerSession {
                        groups.append(currentGroup)
                        currentGroup = []
                    }
                } else {
                    // Start new group
                    if !currentGroup.isEmpty {
                        groups.append(currentGroup)
                    }
                    currentGroup = [event]
                }
            }
        }
        
        // Add final group if not empty
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    /// Refine groups based on contextual similarity
    private func refineGroupsByContext(_ temporalGroups: [[ActivityEvent]]) -> [[ActivityEvent]] {
        var refinedGroups: [[ActivityEvent]] = []
        
        for group in temporalGroups {
            let contextualSubgroups = splitByContextualSimilarity(group)
            refinedGroups.append(contentsOf: contextualSubgroups)
        }
        
        return refinedGroups
    }
    
    /// Split a group based on contextual similarity
    private func splitByContextualSimilarity(_ events: [ActivityEvent]) -> [[ActivityEvent]] {
        guard events.count > 1 else {
            return [events]
        }
        
        var subgroups: [[ActivityEvent]] = []
        var currentSubgroup: [ActivityEvent] = [events[0]]
        
        for i in 1..<events.count {
            let currentEvent = events[i]
            let previousEvent = events[i-1]
            
            let similarity = calculateContextualSimilarity(currentEvent, previousEvent)
            
            if similarity >= configuration.contextSimilarityThreshold {
                currentSubgroup.append(currentEvent)
            } else {
                // Start new subgroup
                if !currentSubgroup.isEmpty {
                    subgroups.append(currentSubgroup)
                }
                currentSubgroup = [currentEvent]
            }
        }
        
        // Add final subgroup
        if !currentSubgroup.isEmpty {
            subgroups.append(currentSubgroup)
        }
        
        return subgroups
    }
    
    /// Calculate contextual similarity between two events
    private func calculateContextualSimilarity(_ event1: ActivityEvent, _ event2: ActivityEvent) -> Float {
        var similarity: Float = 0.0
        var factors = 0
        
        // Event type similarity
        if event1.type == event2.type {
            similarity += 1.0
        } else if areRelatedEventTypes(event1.type, event2.type) {
            similarity += 0.7
        }
        factors += 1
        
        // Application context similarity
        let app1 = extractApplicationFromMetadata(event1.metadata)
        let app2 = extractApplicationFromMetadata(event2.metadata)
        
        if let app1 = app1, let app2 = app2 {
            if app1 == app2 {
                similarity += 1.0
            }
            factors += 1
        }
        
        // Target similarity (for related UI elements)
        let targetSimilarity = calculateTargetSimilarity(event1.target, event2.target)
        similarity += targetSimilarity
        factors += 1
        
        // Temporal proximity factor
        let timeDifference = abs(event2.timestamp.timeIntervalSince(event1.timestamp))
        let proximityScore = max(0, 1.0 - Float(timeDifference / configuration.maxEventGap))
        similarity += proximityScore
        factors += 1
        
        return factors > 0 ? similarity / Float(factors) : 0.0
    }
    
    /// Check if two event types are related
    private func areRelatedEventTypes(_ type1: ActivityEventType, _ type2: ActivityEventType) -> Bool {
        let relatedPairs: [(ActivityEventType, ActivityEventType)] = [
            (.fieldChange, .dataEntry),
            (.dataEntry, .formSubmission),
            (.fieldChange, .formSubmission),
            (.navigation, .appSwitch),
            (.click, .navigation),
            (.modalAppearance, .errorDisplay),
            (.click, .modalAppearance)
        ]
        
        return relatedPairs.contains { pair in
            (pair.0 == type1 && pair.1 == type2) || (pair.0 == type2 && pair.1 == type1)
        }
    }
    
    /// Extract application name from event metadata
    private func extractApplicationFromMetadata(_ metadata: [String: String]) -> String? {
        return metadata["app_name"] ?? metadata["application"] ?? metadata["bundle_id"]
    }
    
    /// Calculate similarity between two target strings
    private func calculateTargetSimilarity(_ target1: String, _ target2: String) -> Float {
        if target1 == target2 {
            return 1.0
        }
        
        // Check for common prefixes or suffixes (indicating related UI elements)
        let components1 = target1.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let components2 = target2.components(separatedBy: CharacterSet.alphanumerics.inverted)
        
        let intersection = Set(components1).intersection(Set(components2))
        let union = Set(components1).union(Set(components2))
        
        return union.isEmpty ? 0.0 : Float(intersection.count) / Float(union.count)
    }
    
    /// Create an activity session from a group of events
    private func createActivitySession(from events: [ActivityEvent]) -> ActivitySession? {
        guard events.count >= configuration.minEventsPerSession else {
            return nil
        }
        
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        
        guard let firstEvent = sortedEvents.first,
              let lastEvent = sortedEvents.last else {
            return nil
        }
        
        let duration = lastEvent.timestamp.timeIntervalSince(firstEvent.timestamp)
        
        guard duration >= configuration.minSessionDuration else {
            return nil
        }
        
        // Determine session type based on event analysis
        let sessionType = determineSessionType(from: sortedEvents)
        
        // Extract primary application
        let primaryApplication = determinePrimaryApplication(from: sortedEvents)
        
        return ActivitySession(
            startTime: firstEvent.timestamp,
            endTime: lastEvent.timestamp,
            events: sortedEvents,
            primaryApplication: primaryApplication,
            sessionType: sessionType
        )
    }
    
    /// Determine the session type based on event patterns
    private func determineSessionType(from events: [ActivityEvent]) -> ActivitySessionType {
        let eventTypeCounts = Dictionary(grouping: events, by: { $0.type })
            .mapValues { $0.count }
        
        let totalEvents = events.count
        
        // Analyze event type distribution
        let formEvents = (eventTypeCounts[.formSubmission] ?? 0) + (eventTypeCounts[.fieldChange] ?? 0)
        let dataEvents = eventTypeCounts[.dataEntry] ?? 0
        let navigationEvents = (eventTypeCounts[.navigation] ?? 0) + (eventTypeCounts[.appSwitch] ?? 0)
        let _ = eventTypeCounts[.click] ?? 0 // Simplified assumption for communication events
        
        // Determine primary activity type
        let formRatio = Float(formEvents) / Float(totalEvents)
        let dataRatio = Float(dataEvents) / Float(totalEvents)
        let navigationRatio = Float(navigationEvents) / Float(totalEvents)
        
        if formRatio > 0.5 {
            return .formFilling
        } else if dataRatio > 0.4 {
            return .dataEntry
        } else if navigationRatio > 0.6 {
            return .navigation
        } else if events.contains(where: { $0.type == .errorDisplay }) {
            // Sessions with errors might be troubleshooting
            return .mixed
        } else {
            // Check for specific patterns
            if hasResearchPattern(events) {
                return .research
            } else if hasCommunicationPattern(events) {
                return .communication
            } else if hasDevelopmentPattern(events) {
                return .development
            } else {
                return .mixed
            }
        }
    }
    
    /// Check if events indicate a research pattern
    private func hasResearchPattern(_ events: [ActivityEvent]) -> Bool {
        let navigationCount = events.filter { 
            $0.type == .navigation || $0.type == .appSwitch 
        }.count
        
        let clickCount = events.filter { $0.type == .click }.count
        
        // Research typically involves lots of navigation and clicking with minimal data entry
        return navigationCount > events.count / 3 && clickCount > events.count / 4
    }
    
    /// Check if events indicate a communication pattern
    private func hasCommunicationPattern(_ events: [ActivityEvent]) -> Bool {
        // Look for communication app indicators in metadata
        let communicationApps = ["mail", "messages", "slack", "teams", "zoom", "skype"]
        
        return events.contains { event in
            let appName = extractApplicationFromMetadata(event.metadata)?.lowercased() ?? ""
            return communicationApps.contains { appName.contains($0) }
        }
    }
    
    /// Check if events indicate a development pattern
    private func hasDevelopmentPattern(_ events: [ActivityEvent]) -> Bool {
        // Look for development app indicators in metadata
        let developmentApps = ["xcode", "vscode", "intellij", "terminal", "git", "github"]
        
        return events.contains { event in
            let appName = extractApplicationFromMetadata(event.metadata)?.lowercased() ?? ""
            return developmentApps.contains { appName.contains($0) }
        }
    }
    
    /// Determine the primary application for the session
    private func determinePrimaryApplication(from events: [ActivityEvent]) -> String? {
        // Count application occurrences
        var appCounts: [String: Int] = [:]
        
        for event in events {
            if let app = extractApplicationFromMetadata(event.metadata) {
                appCounts[app, default: 0] += 1
            }
        }
        
        // Return the most frequent application
        return appCounts.max(by: { $0.value < $1.value })?.key
    }
}