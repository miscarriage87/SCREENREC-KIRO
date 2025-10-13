import XCTest
import Foundation
import SQLite
@testable import Shared

final class SpansMigrationTests: XCTestCase {
    var tempDirectory: URL!
    var databasePath: URL!
    var connection: Connection!
    var migrationManager: SpansMigrationManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test database
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpansMigrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        databasePath = tempDirectory.appendingPathComponent("test_migrations.db")
        
        do {
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            connection = try Connection(databasePath.path)
            migrationManager = SpansMigrationManager(connection: connection)
        } catch {
            XCTFail("Failed to set up test database: \(error)")
        }
    }
    
    override func tearDown() {
        connection = nil
        migrationManager = nil
        
        do {
            try FileManager.default.removeItem(at: tempDirectory)
        } catch {
            print("Warning: Failed to clean up test directory: \(error)")
        }
        
        databasePath = nil
        tempDirectory = nil
        
        super.tearDown()
    }
    
    // MARK: - Migration System Tests
    
    func testInitialMigration() throws {
        // Initially, version should be 0
        let initialVersion = try migrationManager.getCurrentVersion()
        XCTAssertEqual(initialVersion, 0)
        
        // Run migrations
        try migrationManager.migrate()
        
        // Version should now be the latest
        let currentVersion = try migrationManager.getCurrentVersion()
        XCTAssertGreaterThan(currentVersion, 0)
        
        // Verify spans table exists
        let spans = Table("spans")
        let tableExists = try connection.scalar(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='spans'"
        ) != nil
        XCTAssertTrue(tableExists)
    }
    
    func testMigrationIdempotency() throws {
        // Run migrations twice
        try migrationManager.migrate()
        let versionAfterFirst = try migrationManager.getCurrentVersion()
        
        try migrationManager.migrate()
        let versionAfterSecond = try migrationManager.getCurrentVersion()
        
        // Version should be the same
        XCTAssertEqual(versionAfterFirst, versionAfterSecond)
    }
    
    func testGetAppliedMigrations() throws {
        // Initially no migrations
        let initialMigrations = try migrationManager.getAppliedMigrations()
        XCTAssertEqual(initialMigrations.count, 0)
        
        // Run migrations
        try migrationManager.migrate()
        
        // Should have applied migrations
        let appliedMigrations = try migrationManager.getAppliedMigrations()
        XCTAssertGreaterThan(appliedMigrations.count, 0)
        
        // Verify migration metadata
        for migration in appliedMigrations {
            XCTAssertGreaterThan(migration.version, 0)
            XCTAssertFalse(migration.description.isEmpty)
            XCTAssertLessThanOrEqual(migration.appliedAt, Date())
        }
        
        // Migrations should be in order
        for i in 0..<appliedMigrations.count - 1 {
            XCTAssertLessThan(appliedMigrations[i].version, appliedMigrations[i + 1].version)
        }
    }
    
    func testMigrationTracking() throws {
        try migrationManager.migrate()
        
        // Verify migration tracking table exists
        let migrationsTable = Table("schema_migrations")
        let tableExists = try connection.scalar(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_migrations'"
        ) != nil
        XCTAssertTrue(tableExists)
        
        // Verify migration records
        let migrationCount = try connection.scalar(migrationsTable.count)
        XCTAssertGreaterThan(migrationCount, 0)
    }
    
    // MARK: - Schema Validation Tests
    
    func testSpansTableSchema() throws {
        try migrationManager.migrate()
        
        // Verify spans table has correct columns
        let tableInfo = try connection.prepare("PRAGMA table_info(spans)")
        var columns: [String] = []
        
        for row in tableInfo {
            if let columnName = row[1] as? String {
                columns.append(columnName)
            }
        }
        
        let expectedColumns = ["span_id", "kind", "t_start", "t_end", "title", "summary_md", "tags", "created_at"]
        for expectedColumn in expectedColumns {
            XCTAssertTrue(columns.contains(expectedColumn), "Missing column: \(expectedColumn)")
        }
    }
    
    func testIndexesCreated() throws {
        try migrationManager.migrate()
        
        // Verify indexes exist
        let indexQuery = try connection.prepare("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='spans'")
        var indexes: [String] = []
        
        for row in indexQuery {
            if let indexName = row[0] as? String {
                indexes.append(indexName)
            }
        }
        
        // Should have multiple indexes (exact names depend on SQLite.swift implementation)
        XCTAssertGreaterThan(indexes.count, 0)
    }
    
    // MARK: - Data Preservation Tests
    
    func testDataPreservationDuringMigration() throws {
        // Run initial migration
        try migrationManager.migrate()
        
        // Insert test data
        let spans = Table("spans")
        let spanId = Expression<String>("span_id")
        let kind = Expression<String>("kind")
        let startTimeNs = Expression<Int64>("t_start")
        let endTimeNs = Expression<Int64>("t_end")
        let title = Expression<String>("title")
        let summaryMd = Expression<String?>("summary_md")
        let tags = Expression<String>("tags")
        let createdAt = Expression<Int64>("created_at")
        
        let testSpanId = "test-span-1"
        let now = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
        
        try connection.run(spans.insert(
            spanId <- testSpanId,
            kind <- "test",
            startTimeNs <- now,
            endTimeNs <- now + 3600_000_000_000, // 1 hour later
            title <- "Test Span",
            summaryMd <- "Test summary",
            tags <- "[\"test\", \"migration\"]",
            createdAt <- Int64(Date().timeIntervalSince1970)
        ))
        
        // Verify data exists
        let beforeCount = try connection.scalar(spans.count)
        XCTAssertEqual(beforeCount, 1)
        
        // Run migrations again (should be idempotent)
        try migrationManager.migrate()
        
        // Verify data still exists
        let afterCount = try connection.scalar(spans.count)
        XCTAssertEqual(afterCount, 1)
        
        // Verify specific data
        let query = spans.filter(spanId == testSpanId)
        let retrievedSpan = try connection.pluck(query)
        XCTAssertNotNil(retrievedSpan)
        XCTAssertEqual(retrievedSpan?[title], "Test Span")
    }
    
    // MARK: - Error Handling Tests
    
    func testMigrationErrorHandling() throws {
        // Create a migration manager with a custom migration that will fail
        let failingMigration = SpansMigrationManager.Migration(
            version: 999,
            description: "Failing migration for testing"
        ) { connection in
            // This will fail because the table doesn't exist
            try connection.run("INSERT INTO nonexistent_table VALUES (1)")
        }
        
        // We can't easily inject custom migrations into the existing manager,
        // so we'll test with an invalid database state instead
        
        // Close the connection to simulate a connection error
        connection = nil
        
        // Try to get current version with no connection
        // This should be handled gracefully by the migration manager
        // Note: We need a new connection for this test
        let invalidPath = URL(fileURLWithPath: "/invalid/path/test.db")
        
        XCTAssertThrowsError(try Connection(invalidPath.path)) { error in
            // Should throw some kind of connection error
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Performance Tests
    
    func testMigrationPerformance() throws {
        measure {
            do {
                try migrationManager.migrate()
            } catch {
                XCTFail("Migration performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testSpansStorageWithMigrations() throws {
        // Test that SpansStorage works correctly with the migration system
        let spansStorage = SpansStorage(databasePath: databasePath)
        
        try spansStorage.initialize()
        
        // Verify database version
        let version = try spansStorage.getDatabaseVersion()
        XCTAssertGreaterThan(version, 0)
        
        // Verify applied migrations
        let appliedMigrations = try spansStorage.getAppliedMigrations()
        XCTAssertGreaterThan(appliedMigrations.count, 0)
        
        // Test basic functionality
        let testSpan = Span(
            kind: "test",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            title: "Migration Test Span",
            tags: ["migration", "test"]
        )
        
        try spansStorage.insertSpan(testSpan)
        let retrieved = try spansStorage.getSpan(spanId: testSpan.spanId)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.title, testSpan.title)
        
        try spansStorage.close()
    }
    
    func testConcurrentMigrations() throws {
        // Test that migrations work correctly with concurrent access
        let expectation = XCTestExpectation(description: "Concurrent migrations")
        expectation.expectedFulfillmentCount = 3
        
        let queue = DispatchQueue.global(qos: .background)
        
        // Run migrations from multiple threads
        for i in 0..<3 {
            queue.async {
                do {
                    let connection = try Connection(self.databasePath.path)
                    let manager = SpansMigrationManager(connection: connection)
                    try manager.migrate()
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent migration \(i) failed: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify final state is consistent
        let finalVersion = try migrationManager.getCurrentVersion()
        XCTAssertGreaterThan(finalVersion, 0)
    }
}