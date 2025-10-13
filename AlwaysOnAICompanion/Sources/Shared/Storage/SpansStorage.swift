import Foundation
import SQLite

/// Represents a span in the system - a time-bounded activity or session
public struct Span {
    public let spanId: String
    public let kind: String
    public let startTime: Date
    public let endTime: Date
    public let title: String
    public let summaryMarkdown: String?
    public let tags: [String]
    public let createdAt: Date
    
    public init(
        spanId: String = UUID().uuidString,
        kind: String,
        startTime: Date,
        endTime: Date,
        title: String,
        summaryMarkdown: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.spanId = spanId
        self.kind = kind
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.summaryMarkdown = summaryMarkdown
        self.tags = tags
        self.createdAt = createdAt
    }
}

/// Errors that can occur during spans storage operations
public enum SpansStorageError: Error, LocalizedError {
    case databaseNotInitialized
    case invalidSpanData(String)
    case migrationFailed(String)
    case transactionFailed(String)
    case queryFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database has not been initialized"
        case .invalidSpanData(let message):
            return "Invalid span data: \(message)"
        case .migrationFailed(let message):
            return "Database migration failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        }
    }
}

/// Query parameters for filtering spans
public struct SpanQuery {
    public let startTime: Date?
    public let endTime: Date?
    public let kinds: [String]?
    public let tags: [String]?
    public let limit: Int?
    public let offset: Int?
    
    public init(
        startTime: Date? = nil,
        endTime: Date? = nil,
        kinds: [String]? = nil,
        tags: [String]? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.kinds = kinds
        self.tags = tags
        self.limit = limit
        self.offset = offset
    }
}

/// SQLite-based storage system for spans with encryption support
public class SpansStorage {
    private var connection: Connection?
    private let encryptionManager: EncryptionManager?
    private let databasePath: URL
    
    // Table definition
    private let spans = Table("spans")
    private let spanId = Expression<String>("span_id")
    private let kind = Expression<String>("kind")
    private let startTimeNs = Expression<Int64>("t_start")
    private let endTimeNs = Expression<Int64>("t_end")
    private let title = Expression<String>("title")
    private let summaryMd = Expression<String?>("summary_md")
    private let tags = Expression<String>("tags")
    private let createdAt = Expression<Int64>("created_at")
    
    /// Initialize spans storage with optional encryption
    /// - Parameters:
    ///   - databasePath: Path to the SQLite database file
    ///   - encryptionManager: Optional encryption manager for data protection
    public init(databasePath: URL, encryptionManager: EncryptionManager? = nil) {
        self.databasePath = databasePath
        self.encryptionManager = encryptionManager
    }
    
    /// Initialize the database and create tables if needed
    public func initialize() throws {
        // Create directory if it doesn't exist
        let directory = databasePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Open database connection
        connection = try Connection(databasePath.path)
        
        // Enable WAL mode for better concurrency
        try connection?.execute("PRAGMA journal_mode = WAL")
        
        // Run migrations
        let migrationManager = SpansMigrationManager(connection: connection!)
        try migrationManager.migrate()
    }
    
    /// Close the database connection
    public func close() throws {
        connection = nil
    }
    
    /// Insert a new span into the database
    /// - Parameter span: The span to insert
    /// - Returns: The inserted span with any generated values
    @discardableResult
    public func insertSpan(_ span: Span) throws -> Span {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        let tagsJson = try encodeTagsToJson(span.tags)
        
        try db.transaction {
            try db.run(spans.insert(
                spanId <- span.spanId,
                kind <- span.kind,
                startTimeNs <- Int64(span.startTime.timeIntervalSince1970 * 1_000_000_000),
                endTimeNs <- Int64(span.endTime.timeIntervalSince1970 * 1_000_000_000),
                title <- span.title,
                summaryMd <- span.summaryMarkdown,
                tags <- tagsJson,
                createdAt <- Int64(span.createdAt.timeIntervalSince1970)
            ))
        }
        
        return span
    }
    
    /// Update an existing span
    /// - Parameter span: The span to update
    public func updateSpan(_ span: Span) throws {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        let tagsJson = try encodeTagsToJson(span.tags)
        let spanRow = spans.filter(spanId == span.spanId)
        
        try db.transaction {
            let updated = try db.run(spanRow.update(
                kind <- span.kind,
                startTimeNs <- Int64(span.startTime.timeIntervalSince1970 * 1_000_000_000),
                endTimeNs <- Int64(span.endTime.timeIntervalSince1970 * 1_000_000_000),
                title <- span.title,
                summaryMd <- span.summaryMarkdown,
                tags <- tagsJson
            ))
            
            if updated == 0 {
                throw SpansStorageError.queryFailed("No span found with ID: \(span.spanId)")
            }
        }
    }
    
    /// Delete a span by ID
    /// - Parameter spanId: The ID of the span to delete
    public func deleteSpan(spanId: String) throws {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        let spanRow = spans.filter(self.spanId == spanId)
        
        try db.transaction {
            let deleted = try db.run(spanRow.delete())
            if deleted == 0 {
                throw SpansStorageError.queryFailed("No span found with ID: \(spanId)")
            }
        }
    }
    
    /// Retrieve a span by ID
    /// - Parameter spanId: The ID of the span to retrieve
    /// - Returns: The span if found, nil otherwise
    public func getSpan(spanId: String) throws -> Span? {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        let query = spans.filter(self.spanId == spanId).limit(1)
        
        for row in try db.prepare(query) {
            return try parseSpanFromRow(row)
        }
        
        return nil
    }
    
    /// Query spans with filtering and pagination
    /// - Parameter query: Query parameters for filtering
    /// - Returns: Array of matching spans
    public func querySpans(_ query: SpanQuery = SpanQuery()) throws -> [Span] {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        var sqlQuery = spans.select(spans[*])
        
        // Apply time range filters
        if let startTime = query.startTime {
            let startNs = Int64(startTime.timeIntervalSince1970 * 1_000_000_000)
            sqlQuery = sqlQuery.filter(endTimeNs >= startNs)
        }
        
        if let endTime = query.endTime {
            let endNs = Int64(endTime.timeIntervalSince1970 * 1_000_000_000)
            sqlQuery = sqlQuery.filter(startTimeNs <= endNs)
        }
        
        // Apply kind filter
        if let kinds = query.kinds, !kinds.isEmpty {
            sqlQuery = sqlQuery.filter(kinds.contains(kind))
        }
        
        // Apply tag filter (requires JSON search)
        if let queryTags = query.tags, !queryTags.isEmpty {
            for tag in queryTags {
                sqlQuery = sqlQuery.filter(tags.like("%\"\(tag)\"%"))
            }
        }
        
        // Apply ordering (most recent first)
        sqlQuery = sqlQuery.order(startTimeNs.desc)
        
        // Apply pagination
        if let limit = query.limit {
            sqlQuery = sqlQuery.limit(limit, offset: query.offset ?? 0)
        }
        
        var results: [Span] = []
        for row in try db.prepare(sqlQuery) {
            results.append(try parseSpanFromRow(row))
        }
        
        return results
    }
    
    /// Get spans that overlap with a given time range
    /// - Parameters:
    ///   - startTime: Start of the time range
    ///   - endTime: End of the time range
    /// - Returns: Array of overlapping spans
    public func getOverlappingSpans(startTime: Date, endTime: Date) throws -> [Span] {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        let startNs = Int64(startTime.timeIntervalSince1970 * 1_000_000_000)
        let endNs = Int64(endTime.timeIntervalSince1970 * 1_000_000_000)
        
        // Spans overlap if: span_start <= query_end AND span_end >= query_start
        let query = spans.filter(startTimeNs <= endNs && endTimeNs >= startNs)
            .order(startTimeNs.asc)
        
        var results: [Span] = []
        for row in try db.prepare(query) {
            results.append(try parseSpanFromRow(row))
        }
        
        return results
    }
    
    /// Get count of spans matching query criteria
    /// - Parameter query: Query parameters for filtering
    /// - Returns: Count of matching spans
    public func getSpanCount(_ query: SpanQuery = SpanQuery()) throws -> Int {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        var sqlQuery = spans.select(spans[*])
        
        // Apply same filters as querySpans
        if let startTime = query.startTime {
            let startNs = Int64(startTime.timeIntervalSince1970 * 1_000_000_000)
            sqlQuery = sqlQuery.filter(endTimeNs >= startNs)
        }
        
        if let endTime = query.endTime {
            let endNs = Int64(endTime.timeIntervalSince1970 * 1_000_000_000)
            sqlQuery = sqlQuery.filter(startTimeNs <= endNs)
        }
        
        if let kinds = query.kinds, !kinds.isEmpty {
            sqlQuery = sqlQuery.filter(kinds.contains(kind))
        }
        
        if let queryTags = query.tags, !queryTags.isEmpty {
            for tag in queryTags {
                sqlQuery = sqlQuery.filter(tags.like("%\"\(tag)\"%"))
            }
        }
        
        return try db.scalar(sqlQuery.count)
    }
    
    // MARK: - Private Methods
    

    
    /// Get current database schema version
    /// - Returns: Current migration version
    public func getDatabaseVersion() throws -> Int {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        let migrationManager = SpansMigrationManager(connection: db)
        return try migrationManager.getCurrentVersion()
    }
    
    /// Get list of applied migrations
    /// - Returns: Array of applied migrations with metadata
    public func getAppliedMigrations() throws -> [(version: Int, description: String, appliedAt: Date)] {
        guard let db = connection else {
            throw SpansStorageError.databaseNotInitialized
        }
        
        let migrationManager = SpansMigrationManager(connection: db)
        return try migrationManager.getAppliedMigrations()
    }
    
    private func parseSpanFromRow(_ row: Row) throws -> Span {
        let startTimeInterval = TimeInterval(row[startTimeNs]) / 1_000_000_000
        let endTimeInterval = TimeInterval(row[endTimeNs]) / 1_000_000_000
        let createdAtInterval = TimeInterval(row[createdAt])
        
        let parsedTags = try decodeTagsFromJson(row[tags])
        
        return Span(
            spanId: row[spanId],
            kind: row[kind],
            startTime: Date(timeIntervalSince1970: startTimeInterval),
            endTime: Date(timeIntervalSince1970: endTimeInterval),
            title: row[title],
            summaryMarkdown: row[summaryMd],
            tags: parsedTags,
            createdAt: Date(timeIntervalSince1970: createdAtInterval)
        )
    }
    
    private func encodeTagsToJson(_ tags: [String]) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: tags)
        return String(data: jsonData, encoding: .utf8) ?? "[]"
    }
    
    private func decodeTagsFromJson(_ json: String) throws -> [String] {
        guard let data = json.data(using: .utf8) else {
            return []
        }
        
        do {
            let tags = try JSONSerialization.jsonObject(with: data) as? [String]
            return tags ?? []
        } catch {
            // Return empty array if JSON parsing fails
            return []
        }
    }
}