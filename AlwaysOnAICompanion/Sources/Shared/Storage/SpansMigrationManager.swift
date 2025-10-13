import Foundation
import SQLite

/// Manages database schema migrations for the spans storage system
public class SpansMigrationManager {
    private let connection: Connection
    private let migrations: [Migration]
    
    /// Represents a single database migration
    public struct Migration {
        let version: Int
        let description: String
        let up: (Connection) throws -> Void
        let down: ((Connection) throws -> Void)?
        
        public init(
            version: Int,
            description: String,
            up: @escaping (Connection) throws -> Void,
            down: ((Connection) throws -> Void)? = nil
        ) {
            self.version = version
            self.description = description
            self.up = up
            self.down = down
        }
    }
    
    /// Migration-related errors
    public enum MigrationError: Error, LocalizedError {
        case migrationFailed(Int, String)
        case rollbackFailed(Int, String)
        case invalidMigrationVersion(Int)
        case migrationTableCreationFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .migrationFailed(let version, let message):
                return "Migration \(version) failed: \(message)"
            case .rollbackFailed(let version, let message):
                return "Rollback of migration \(version) failed: \(message)"
            case .invalidMigrationVersion(let version):
                return "Invalid migration version: \(version)"
            case .migrationTableCreationFailed(let message):
                return "Failed to create migration table: \(message)"
            }
        }
    }
    
    // Migration tracking table
    private let migrationsTable = Table("schema_migrations")
    private let migrationVersion = Expression<Int>("version")
    private let migrationDescription = Expression<String>("description")
    private let appliedAt = Expression<Int64>("applied_at")
    
    /// Initialize the migration manager with a database connection
    /// - Parameter connection: Active SQLite connection
    public init(connection: Connection) {
        self.connection = connection
        self.migrations = Self.createMigrations()
    }
    
    /// Run all pending migrations
    public func migrate() throws {
        try createMigrationsTableIfNeeded()
        
        let currentVersion = try getCurrentVersion()
        let pendingMigrations = migrations.filter { $0.version > currentVersion }
        
        for migration in pendingMigrations.sorted(by: { $0.version < $1.version }) {
            try runMigration(migration)
        }
    }
    
    /// Rollback to a specific version
    /// - Parameter targetVersion: Version to rollback to
    public func rollback(to targetVersion: Int) throws {
        let currentVersion = try getCurrentVersion()
        
        guard targetVersion < currentVersion else {
            return // Nothing to rollback
        }
        
        let migrationsToRollback = migrations
            .filter { $0.version > targetVersion && $0.version <= currentVersion }
            .sorted(by: { $0.version > $1.version }) // Reverse order for rollback
        
        for migration in migrationsToRollback {
            try rollbackMigration(migration)
        }
    }
    
    /// Get the current schema version
    /// - Returns: Current migration version
    public func getCurrentVersion() throws -> Int {
        try createMigrationsTableIfNeeded()
        
        do {
            if let maxVersion = try connection.scalar(migrationsTable.select(migrationVersion.max)) {
                return maxVersion
            }
        } catch {
            // If query fails, assume version 0
        }
        
        return 0
    }
    
    /// Get list of applied migrations
    /// - Returns: Array of applied migration versions with timestamps
    public func getAppliedMigrations() throws -> [(version: Int, description: String, appliedAt: Date)] {
        try createMigrationsTableIfNeeded()
        
        let query = migrationsTable.order(migrationVersion.asc)
        var results: [(version: Int, description: String, appliedAt: Date)] = []
        
        for row in try connection.prepare(query) {
            let appliedDate = Date(timeIntervalSince1970: TimeInterval(row[appliedAt]))
            results.append((
                version: row[migrationVersion],
                description: row[migrationDescription],
                appliedAt: appliedDate
            ))
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func createMigrationsTableIfNeeded() throws {
        do {
            try connection.run(migrationsTable.create(ifNotExists: true) { t in
                t.column(migrationVersion, primaryKey: true)
                t.column(migrationDescription)
                t.column(appliedAt)
            })
        } catch {
            throw MigrationError.migrationTableCreationFailed(error.localizedDescription)
        }
    }
    
    private func runMigration(_ migration: Migration) throws {
        do {
            try connection.transaction {
                // Run the migration
                try migration.up(connection)
                
                // Record the migration
                try connection.run(migrationsTable.insert(
                    migrationVersion <- migration.version,
                    migrationDescription <- migration.description,
                    appliedAt <- Int64(Date().timeIntervalSince1970)
                ))
            }
        } catch {
            throw MigrationError.migrationFailed(migration.version, error.localizedDescription)
        }
    }
    
    private func rollbackMigration(_ migration: Migration) throws {
        guard let rollbackFunction = migration.down else {
            throw MigrationError.rollbackFailed(migration.version, "No rollback function defined")
        }
        
        do {
            try connection.transaction {
                // Run the rollback
                try rollbackFunction(connection)
                
                // Remove the migration record
                let migrationRow = migrationsTable.filter(migrationVersion == migration.version)
                try connection.run(migrationRow.delete())
            }
        } catch {
            throw MigrationError.rollbackFailed(migration.version, error.localizedDescription)
        }
    }
    
    // MARK: - Migration Definitions
    
    private static func createMigrations() -> [Migration] {
        return [
            // Migration 1: Create initial spans table
            Migration(
                version: 1,
                description: "Create spans table with basic schema"
            ) { connection in
                let spans = Table("spans")
                let spanId = Expression<String>("span_id")
                let kind = Expression<String>("kind")
                let startTimeNs = Expression<Int64>("t_start")
                let endTimeNs = Expression<Int64>("t_end")
                let title = Expression<String>("title")
                let summaryMd = Expression<String?>("summary_md")
                let tags = Expression<String>("tags")
                let createdAt = Expression<Int64>("created_at")
                
                try connection.run(spans.create { t in
                    t.column(spanId, primaryKey: true)
                    t.column(kind)
                    t.column(startTimeNs)
                    t.column(endTimeNs)
                    t.column(title)
                    t.column(summaryMd)
                    t.column(tags, defaultValue: "[]")
                    t.column(createdAt, defaultValue: Int64(Date().timeIntervalSince1970))
                })
            } down: { connection in
                let spans = Table("spans")
                try connection.run(spans.drop())
            },
            
            // Migration 2: Add indexes for performance
            Migration(
                version: 2,
                description: "Add indexes for temporal and categorical queries"
            ) { connection in
                // Create indexes for efficient querying
                try connection.execute("CREATE INDEX IF NOT EXISTS idx_spans_time_range ON spans(t_start, t_end)")
                try connection.execute("CREATE INDEX IF NOT EXISTS idx_spans_kind ON spans(kind)")
                try connection.execute("CREATE INDEX IF NOT EXISTS idx_spans_created_at ON spans(created_at)")
                try connection.execute("CREATE INDEX IF NOT EXISTS idx_spans_start_time ON spans(t_start)")
                try connection.execute("CREATE INDEX IF NOT EXISTS idx_spans_end_time ON spans(t_end)")
            } down: { connection in
                // SQLite doesn't have a direct way to drop indexes by column,
                // so we'll drop and recreate the table
                let spans = Table("spans")
                let spanId = Expression<String>("span_id")
                let kind = Expression<String>("kind")
                let startTimeNs = Expression<Int64>("t_start")
                let endTimeNs = Expression<Int64>("t_end")
                let title = Expression<String>("title")
                let summaryMd = Expression<String?>("summary_md")
                let tags = Expression<String>("tags")
                let createdAt = Expression<Int64>("created_at")
                
                // Create temporary table with data
                let tempSpans = Table("spans_temp")
                try connection.run(tempSpans.create { t in
                    t.column(spanId, primaryKey: true)
                    t.column(kind)
                    t.column(startTimeNs)
                    t.column(endTimeNs)
                    t.column(title)
                    t.column(summaryMd)
                    t.column(tags, defaultValue: "[]")
                    t.column(createdAt, defaultValue: Int64(Date().timeIntervalSince1970))
                })
                
                // Copy data
                try connection.run("""
                    INSERT INTO spans_temp 
                    SELECT span_id, kind, t_start, t_end, title, summary_md, tags, created_at 
                    FROM spans
                """)
                
                // Drop original table and rename temp
                try connection.run(spans.drop())
                try connection.run("ALTER TABLE spans_temp RENAME TO spans")
            }
            
            // Future migrations can be added here
            // Migration 3: Add new columns, modify constraints, etc.
        ]
    }
}

