import Foundation
import SQLite3

/// Privacy audit event types
public enum PrivacyEventType: String, CaseIterable {
    case piiDetected = "pii_detected"
    case piiMasked = "pii_masked"
    case piiStored = "pii_stored"
    case piiAccessed = "pii_accessed"
    case piiDeleted = "pii_deleted"
    case configChanged = "config_changed"
    case auditViewed = "audit_viewed"
    
    var description: String {
        switch self {
        case .piiDetected: return "PII Detected"
        case .piiMasked: return "PII Masked"
        case .piiStored: return "PII Stored"
        case .piiAccessed: return "PII Accessed"
        case .piiDeleted: return "PII Deleted"
        case .configChanged: return "Configuration Changed"
        case .auditViewed: return "Audit Log Viewed"
        }
    }
}

/// Privacy audit event record
public struct PrivacyAuditEvent {
    public let id: UUID
    public let timestamp: Date
    public let eventType: PrivacyEventType
    public let piiTypes: Set<PIIType>
    public let context: String
    public let sourceComponent: String
    public let severity: PrivacySeverity
    public let metadata: [String: String]
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: PrivacyEventType,
        piiTypes: Set<PIIType> = [],
        context: String,
        sourceComponent: String,
        severity: PrivacySeverity = .medium,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.piiTypes = piiTypes
        self.context = context
        self.sourceComponent = sourceComponent
        self.severity = severity
        self.metadata = metadata
    }
}

/// Privacy event severity levels
public enum PrivacySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

/// Privacy audit statistics
public struct PrivacyAuditStats {
    public let totalEvents: Int
    public let eventsByType: [PrivacyEventType: Int]
    public let eventsBySeverity: [PrivacySeverity: Int]
    public let piiTypeFrequency: [PIIType: Int]
    public let timeRange: DateInterval
    public let topSources: [(String, Int)]
    
    public init(
        totalEvents: Int,
        eventsByType: [PrivacyEventType: Int],
        eventsBySeverity: [PrivacySeverity: Int],
        piiTypeFrequency: [PIIType: Int],
        timeRange: DateInterval,
        topSources: [(String, Int)]
    ) {
        self.totalEvents = totalEvents
        self.eventsByType = eventsByType
        self.eventsBySeverity = eventsBySeverity
        self.piiTypeFrequency = piiTypeFrequency
        self.timeRange = timeRange
        self.topSources = topSources
    }
}

/// Privacy audit configuration
public struct PrivacyAuditConfig {
    public let retentionDays: Int
    public let enabledEventTypes: Set<PrivacyEventType>
    public let minimumSeverity: PrivacySeverity
    public let maxEventsPerHour: Int
    public let enableRealTimeAlerts: Bool
    
    public init(
        retentionDays: Int = 90,
        enabledEventTypes: Set<PrivacyEventType> = Set(PrivacyEventType.allCases),
        minimumSeverity: PrivacySeverity = .low,
        maxEventsPerHour: Int = 1000,
        enableRealTimeAlerts: Bool = true
    ) {
        self.retentionDays = retentionDays
        self.enabledEventTypes = enabledEventTypes
        self.minimumSeverity = minimumSeverity
        self.maxEventsPerHour = maxEventsPerHour
        self.enableRealTimeAlerts = enableRealTimeAlerts
    }
    
    public static let `default` = PrivacyAuditConfig()
}

/// Privacy audit system for tracking and reporting PII handling
public class PrivacyAuditor {
    private let config: PrivacyAuditConfig
    private let databasePath: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "privacy.auditor", qos: .utility)
    
    public init(config: PrivacyAuditConfig = .default, databasePath: URL? = nil) {
        self.config = config
        self.databasePath = databasePath ?? Self.defaultDatabasePath()
        
        setupDatabase()
        startMaintenanceTimer()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    /// Log a privacy audit event
    public func logEvent(_ event: PrivacyAuditEvent) {
        guard config.enabledEventTypes.contains(event.eventType),
              event.severity.rawValue >= config.minimumSeverity.rawValue else {
            return
        }
        
        queue.async { [weak self] in
            self?.insertEvent(event)
            
            if self?.config.enableRealTimeAlerts == true && event.severity == .critical {
                self?.handleCriticalEvent(event)
            }
        }
    }
    
    /// Log PII detection event
    public func logPIIDetection(piiTypes: Set<PIIType>, context: String, source: String) {
        let event = PrivacyAuditEvent(
            eventType: .piiDetected,
            piiTypes: piiTypes,
            context: context,
            sourceComponent: source,
            severity: determineSeverity(for: piiTypes),
            metadata: ["count": String(piiTypes.count)]
        )
        logEvent(event)
    }
    
    /// Log PII masking event
    public func logPIIMasking(piiTypes: Set<PIIType>, maskingResult: MaskingResult, source: String) {
        let event = PrivacyAuditEvent(
            eventType: .piiMasked,
            piiTypes: piiTypes,
            context: "Masked \(maskingResult.maskedCount) PII instances",
            sourceComponent: source,
            severity: .low,
            metadata: [
                "masked_count": String(maskingResult.maskedCount),
                "masking_map": maskingResult.maskingMap.description
            ]
        )
        logEvent(event)
    }
    
    /// Log configuration change
    public func logConfigChange(component: String, changes: [String: String]) {
        let event = PrivacyAuditEvent(
            eventType: .configChanged,
            context: "Privacy configuration updated",
            sourceComponent: component,
            severity: .medium,
            metadata: changes
        )
        logEvent(event)
    }
    
    /// Get audit statistics for a time period
    public func getAuditStats(from startDate: Date, to endDate: Date) -> PrivacyAuditStats? {
        return queue.sync {
            return calculateStats(from: startDate, to: endDate)
        }
    }
    
    /// Get recent audit events
    public func getRecentEvents(limit: Int = 100) -> [PrivacyAuditEvent] {
        return queue.sync {
            return fetchRecentEvents(limit: limit)
        }
    }
    
    /// Get events by type
    public func getEvents(ofType type: PrivacyEventType, limit: Int = 100) -> [PrivacyAuditEvent] {
        return queue.sync {
            return fetchEventsByType(type, limit: limit)
        }
    }
    
    /// Generate privacy audit report
    public func generateAuditReport(from startDate: Date, to endDate: Date) -> String {
        guard let stats = getAuditStats(from: startDate, to: endDate) else {
            return "No audit data available for the specified period."
        }
        
        return formatAuditReport(stats: stats, startDate: startDate, endDate: endDate)
    }
    
    /// Clear old audit records based on retention policy
    public func cleanupOldRecords() {
        queue.async { [weak self] in
            self?.performCleanup()
        }
    }
    
    // MARK: - Private Methods
    
    private static func defaultDatabasePath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("AlwaysOnAICompanion")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("privacy_audit.db")
    }
    
    private func setupDatabase() {
        guard sqlite3_open(databasePath.path, &db) == SQLITE_OK else {
            print("Failed to open privacy audit database")
            return
        }
        
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS privacy_events (
                id TEXT PRIMARY KEY,
                timestamp INTEGER NOT NULL,
                event_type TEXT NOT NULL,
                pii_types TEXT,
                context TEXT,
                source_component TEXT,
                severity TEXT,
                metadata TEXT
            );
            
            CREATE INDEX IF NOT EXISTS idx_timestamp ON privacy_events(timestamp);
            CREATE INDEX IF NOT EXISTS idx_event_type ON privacy_events(event_type);
            CREATE INDEX IF NOT EXISTS idx_severity ON privacy_events(severity);
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("Failed to create privacy audit tables")
        }
    }
    
    private func insertEvent(_ event: PrivacyAuditEvent) {
        let insertSQL = """
            INSERT INTO privacy_events 
            (id, timestamp, event_type, pii_types, context, source_component, severity, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        let piiTypesJSON = try? JSONEncoder().encode(Array(event.piiTypes.map { $0.rawValue }))
        let metadataJSON = try? JSONEncoder().encode(event.metadata)
        
        sqlite3_bind_text(statement, 1, event.id.uuidString, -1, nil)
        sqlite3_bind_int64(statement, 2, Int64(event.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 3, event.eventType.rawValue, -1, nil)
        sqlite3_bind_text(statement, 4, String(data: piiTypesJSON ?? Data(), encoding: .utf8), -1, nil)
        sqlite3_bind_text(statement, 5, event.context, -1, nil)
        sqlite3_bind_text(statement, 6, event.sourceComponent, -1, nil)
        sqlite3_bind_text(statement, 7, event.severity.rawValue, -1, nil)
        sqlite3_bind_text(statement, 8, String(data: metadataJSON ?? Data(), encoding: .utf8), -1, nil)
        
        sqlite3_step(statement)
    }
    
    private func fetchRecentEvents(limit: Int) -> [PrivacyAuditEvent] {
        let selectSQL = """
            SELECT id, timestamp, event_type, pii_types, context, source_component, severity, metadata
            FROM privacy_events
            ORDER BY timestamp DESC
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(limit))
        
        var events: [PrivacyAuditEvent] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let event = parseEventFromRow(statement) {
                events.append(event)
            }
        }
        
        return events
    }
    
    private func fetchEventsByType(_ type: PrivacyEventType, limit: Int) -> [PrivacyAuditEvent] {
        let selectSQL = """
            SELECT id, timestamp, event_type, pii_types, context, source_component, severity, metadata
            FROM privacy_events
            WHERE event_type = ?
            ORDER BY timestamp DESC
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, type.rawValue, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        var events: [PrivacyAuditEvent] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let event = parseEventFromRow(statement) {
                events.append(event)
            }
        }
        
        return events
    }
    
    private func parseEventFromRow(_ statement: OpaquePointer?) -> PrivacyAuditEvent? {
        guard let statement = statement else { return nil }
        
        let idString = String(cString: sqlite3_column_text(statement, 0))
        let timestamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 1)))
        let eventTypeString = String(cString: sqlite3_column_text(statement, 2))
        let piiTypesString = String(cString: sqlite3_column_text(statement, 3))
        let context = String(cString: sqlite3_column_text(statement, 4))
        let sourceComponent = String(cString: sqlite3_column_text(statement, 5))
        let severityString = String(cString: sqlite3_column_text(statement, 6))
        let metadataString = String(cString: sqlite3_column_text(statement, 7))
        
        guard let id = UUID(uuidString: idString),
              let eventType = PrivacyEventType(rawValue: eventTypeString),
              let severity = PrivacySeverity(rawValue: severityString) else {
            return nil
        }
        
        let piiTypes = parsePIITypes(from: piiTypesString)
        let metadata = parseMetadata(from: metadataString)
        
        return PrivacyAuditEvent(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            piiTypes: piiTypes,
            context: context,
            sourceComponent: sourceComponent,
            severity: severity,
            metadata: metadata
        )
    }
    
    private func parsePIITypes(from json: String) -> Set<PIIType> {
        guard let data = json.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        
        return Set(strings.compactMap { PIIType(rawValue: $0) })
    }
    
    private func parseMetadata(from json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let metadata = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        
        return metadata
    }
    
    private func calculateStats(from startDate: Date, to endDate: Date) -> PrivacyAuditStats? {
        // Implementation would calculate comprehensive statistics
        // This is a simplified version
        let events = fetchEventsInRange(from: startDate, to: endDate)
        
        var eventsByType: [PrivacyEventType: Int] = [:]
        var eventsBySeverity: [PrivacySeverity: Int] = [:]
        var piiTypeFrequency: [PIIType: Int] = [:]
        var sourceFrequency: [String: Int] = [:]
        
        for event in events {
            eventsByType[event.eventType, default: 0] += 1
            eventsBySeverity[event.severity, default: 0] += 1
            sourceFrequency[event.sourceComponent, default: 0] += 1
            
            for piiType in event.piiTypes {
                piiTypeFrequency[piiType, default: 0] += 1
            }
        }
        
        let topSources = sourceFrequency.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
        
        return PrivacyAuditStats(
            totalEvents: events.count,
            eventsByType: eventsByType,
            eventsBySeverity: eventsBySeverity,
            piiTypeFrequency: piiTypeFrequency,
            timeRange: DateInterval(start: startDate, end: endDate),
            topSources: Array(topSources)
        )
    }
    
    private func fetchEventsInRange(from startDate: Date, to endDate: Date) -> [PrivacyAuditEvent] {
        let selectSQL = """
            SELECT id, timestamp, event_type, pii_types, context, source_component, severity, metadata
            FROM privacy_events
            WHERE timestamp BETWEEN ? AND ?
            ORDER BY timestamp DESC
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int64(statement, 1, Int64(startDate.timeIntervalSince1970))
        sqlite3_bind_int64(statement, 2, Int64(endDate.timeIntervalSince1970))
        
        var events: [PrivacyAuditEvent] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let event = parseEventFromRow(statement) {
                events.append(event)
            }
        }
        
        return events
    }
    
    private func determineSeverity(for piiTypes: Set<PIIType>) -> PrivacySeverity {
        let criticalTypes: Set<PIIType> = [.ssn, .creditCard, .passport, .driversLicense]
        let highTypes: Set<PIIType> = [.email, .phone, .dateOfBirth]
        
        if !piiTypes.isDisjoint(with: criticalTypes) {
            return .critical
        } else if !piiTypes.isDisjoint(with: highTypes) {
            return .high
        } else if piiTypes.count > 3 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func handleCriticalEvent(_ event: PrivacyAuditEvent) {
        // In a real implementation, this would send alerts, notifications, etc.
        print("CRITICAL PRIVACY EVENT: \(event.eventType) - \(event.context)")
    }
    
    private func formatAuditReport(stats: PrivacyAuditStats, startDate: Date, endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var report = """
        # Privacy Audit Report
        
        **Period:** \(formatter.string(from: startDate)) - \(formatter.string(from: endDate))
        **Total Events:** \(stats.totalEvents)
        
        ## Events by Type
        """
        
        for (type, count) in stats.eventsByType.sorted(by: { $0.value > $1.value }) {
            report += "\n- \(type.description): \(count)"
        }
        
        report += "\n\n## Events by Severity"
        for (severity, count) in stats.eventsBySeverity.sorted(by: { $0.value > $1.value }) {
            report += "\n- \(severity.description): \(count)"
        }
        
        report += "\n\n## PII Types Detected"
        for (piiType, count) in stats.piiTypeFrequency.sorted(by: { $0.value > $1.value }) {
            report += "\n- \(piiType.description): \(count)"
        }
        
        report += "\n\n## Top Sources"
        for (source, count) in stats.topSources {
            report += "\n- \(source): \(count)"
        }
        
        return report
    }
    
    private func performCleanup() {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(config.retentionDays * 24 * 60 * 60))
        
        let deleteSQL = "DELETE FROM privacy_events WHERE timestamp < ?"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int64(statement, 1, Int64(cutoffDate.timeIntervalSince1970))
        sqlite3_step(statement)
    }
    
    private func startMaintenanceTimer() {
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.cleanupOldRecords()
        }
    }
}