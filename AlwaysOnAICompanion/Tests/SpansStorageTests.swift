import XCTest
import Foundation
@testable import Shared

final class SpansStorageTests: XCTestCase {
    var tempDirectory: URL!
    var databasePath: URL!
    var spansStorage: SpansStorage!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test database
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpansStorageTests")
            .appendingPathComponent(UUID().uuidString)
        
        databasePath = tempDirectory.appendingPathComponent("spans.db")
        spansStorage = SpansStorage(databasePath: databasePath)
        
        do {
            try spansStorage.initialize()
        } catch {
            XCTFail("Failed to initialize spans storage: \(error)")
        }
    }
    
    override func tearDown() {
        do {
            try spansStorage.close()
            try FileManager.default.removeItem(at: tempDirectory)
        } catch {
            print("Warning: Failed to clean up test directory: \(error)")
        }
        
        spansStorage = nil
        databasePath = nil
        tempDirectory = nil
        
        super.tearDown()
    }
    
    // MARK: - Basic CRUD Tests
    
    func testInsertSpan() throws {
        let span = createTestSpan()
        
        let insertedSpan = try spansStorage.insertSpan(span)
        
        XCTAssertEqual(insertedSpan.spanId, span.spanId)
        XCTAssertEqual(insertedSpan.kind, span.kind)
        XCTAssertEqual(insertedSpan.title, span.title)
        XCTAssertEqual(insertedSpan.tags, span.tags)
    }
    
    func testGetSpan() throws {
        let originalSpan = createTestSpan()
        try spansStorage.insertSpan(originalSpan)
        
        let retrievedSpan = try spansStorage.getSpan(spanId: originalSpan.spanId)
        
        XCTAssertNotNil(retrievedSpan)
        XCTAssertEqual(retrievedSpan?.spanId, originalSpan.spanId)
        XCTAssertEqual(retrievedSpan?.kind, originalSpan.kind)
        XCTAssertEqual(retrievedSpan?.title, originalSpan.title)
        XCTAssertEqual(retrievedSpan?.summaryMarkdown, originalSpan.summaryMarkdown)
        XCTAssertEqual(retrievedSpan?.tags, originalSpan.tags)
        
        // Test time precision (should be within 1 second due to nanosecond conversion)
        if let retrieved = retrievedSpan {
            XCTAssertEqual(retrieved.startTime.timeIntervalSince1970, 
                          originalSpan.startTime.timeIntervalSince1970, accuracy: 1.0)
            XCTAssertEqual(retrieved.endTime.timeIntervalSince1970, 
                          originalSpan.endTime.timeIntervalSince1970, accuracy: 1.0)
        }
    }
    
    func testGetNonexistentSpan() throws {
        let result = try spansStorage.getSpan(spanId: "nonexistent-id")
        XCTAssertNil(result)
    }
    
    func testUpdateSpan() throws {
        let originalSpan = createTestSpan()
        try spansStorage.insertSpan(originalSpan)
        
        let updatedSpan = Span(
            spanId: originalSpan.spanId,
            kind: "updated-kind",
            startTime: originalSpan.startTime,
            endTime: originalSpan.endTime,
            title: "Updated Title",
            summaryMarkdown: "Updated summary",
            tags: ["updated", "tags"],
            createdAt: originalSpan.createdAt
        )
        
        try spansStorage.updateSpan(updatedSpan)
        
        let retrievedSpan = try spansStorage.getSpan(spanId: originalSpan.spanId)
        XCTAssertNotNil(retrievedSpan)
        XCTAssertEqual(retrievedSpan?.kind, "updated-kind")
        XCTAssertEqual(retrievedSpan?.title, "Updated Title")
        XCTAssertEqual(retrievedSpan?.summaryMarkdown, "Updated summary")
        XCTAssertEqual(retrievedSpan?.tags, ["updated", "tags"])
    }
    
    func testUpdateNonexistentSpan() {
        let span = createTestSpan()
        
        XCTAssertThrowsError(try spansStorage.updateSpan(span)) { error in
            if case SpansStorageError.queryFailed(let message) = error {
                XCTAssertTrue(message.contains("No span found"))
            } else {
                XCTFail("Expected queryFailed error, got: \(error)")
            }
        }
    }
    
    func testDeleteSpan() throws {
        let span = createTestSpan()
        try spansStorage.insertSpan(span)
        
        // Verify span exists
        let beforeDelete = try spansStorage.getSpan(spanId: span.spanId)
        XCTAssertNotNil(beforeDelete)
        
        // Delete span
        try spansStorage.deleteSpan(spanId: span.spanId)
        
        // Verify span is gone
        let afterDelete = try spansStorage.getSpan(spanId: span.spanId)
        XCTAssertNil(afterDelete)
    }
    
    func testDeleteNonexistentSpan() {
        XCTAssertThrowsError(try spansStorage.deleteSpan(spanId: "nonexistent-id")) { error in
            if case SpansStorageError.queryFailed(let message) = error {
                XCTAssertTrue(message.contains("No span found"))
            } else {
                XCTFail("Expected queryFailed error, got: \(error)")
            }
        }
    }
    
    // MARK: - Query Tests
    
    func testQueryAllSpans() throws {
        let spans = createMultipleTestSpans()
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let results = try spansStorage.querySpans()
        
        XCTAssertEqual(results.count, spans.count)
        
        // Results should be ordered by start time descending (most recent first)
        for i in 0..<results.count - 1 {
            XCTAssertGreaterThanOrEqual(results[i].startTime, results[i + 1].startTime)
        }
    }
    
    func testQuerySpansByTimeRange() throws {
        let baseTime = Date()
        let spans = [
            createTestSpan(
                kind: "old",
                startTime: baseTime.addingTimeInterval(-3600), // 1 hour ago
                endTime: baseTime.addingTimeInterval(-1800)   // 30 min ago
            ),
            createTestSpan(
                kind: "recent",
                startTime: baseTime.addingTimeInterval(-1800), // 30 min ago
                endTime: baseTime.addingTimeInterval(-900)    // 15 min ago
            ),
            createTestSpan(
                kind: "current",
                startTime: baseTime.addingTimeInterval(-900),  // 15 min ago
                endTime: baseTime                             // now
            )
        ]
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        // Query for spans in the last 20 minutes
        let query = SpanQuery(
            startTime: baseTime.addingTimeInterval(-1200), // 20 min ago
            endTime: baseTime
        )
        
        let results = try spansStorage.querySpans(query)
        
        XCTAssertEqual(results.count, 2) // Should get "recent" and "current"
        XCTAssertTrue(results.contains { $0.kind == "recent" })
        XCTAssertTrue(results.contains { $0.kind == "current" })
        XCTAssertFalse(results.contains { $0.kind == "old" })
    }
    
    func testQuerySpansByKind() throws {
        let spans = [
            createTestSpan(kind: "work"),
            createTestSpan(kind: "personal"),
            createTestSpan(kind: "work"),
            createTestSpan(kind: "meeting")
        ]
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let query = SpanQuery(kinds: ["work", "meeting"])
        let results = try spansStorage.querySpans(query)
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.kind == "work" || $0.kind == "meeting" })
    }
    
    func testQuerySpansByTags() throws {
        let spans = [
            createTestSpan(tags: ["urgent", "project-a"]),
            createTestSpan(tags: ["project-a", "review"]),
            createTestSpan(tags: ["project-b", "urgent"]),
            createTestSpan(tags: ["meeting", "project-c"])
        ]
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let query = SpanQuery(tags: ["project-a"])
        let results = try spansStorage.querySpans(query)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.tags.contains("project-a") })
    }
    
    func testQuerySpansWithPagination() throws {
        let spans = createMultipleTestSpans(count: 10)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        // First page
        let firstPageQuery = SpanQuery(limit: 3, offset: 0)
        let firstPage = try spansStorage.querySpans(firstPageQuery)
        XCTAssertEqual(firstPage.count, 3)
        
        // Second page
        let secondPageQuery = SpanQuery(limit: 3, offset: 3)
        let secondPage = try spansStorage.querySpans(secondPageQuery)
        XCTAssertEqual(secondPage.count, 3)
        
        // Verify no overlap
        let firstPageIds = Set(firstPage.map { $0.spanId })
        let secondPageIds = Set(secondPage.map { $0.spanId })
        XCTAssertTrue(firstPageIds.isDisjoint(with: secondPageIds))
    }
    
    func testGetOverlappingSpans() throws {
        let baseTime = Date()
        let spans = [
            createTestSpan(
                kind: "before",
                startTime: baseTime.addingTimeInterval(-3600), // 1 hour ago
                endTime: baseTime.addingTimeInterval(-1800)   // 30 min ago
            ),
            createTestSpan(
                kind: "overlapping",
                startTime: baseTime.addingTimeInterval(-1800), // 30 min ago
                endTime: baseTime.addingTimeInterval(1800)    // 30 min from now
            ),
            createTestSpan(
                kind: "after",
                startTime: baseTime.addingTimeInterval(1800),  // 30 min from now
                endTime: baseTime.addingTimeInterval(3600)    // 1 hour from now
            )
        ]
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        // Query for spans overlapping with "now" to 15 minutes from now
        let overlapping = try spansStorage.getOverlappingSpans(
            startTime: baseTime,
            endTime: baseTime.addingTimeInterval(900) // 15 min from now
        )
        
        XCTAssertEqual(overlapping.count, 1)
        XCTAssertEqual(overlapping.first?.kind, "overlapping")
    }
    
    func testGetSpanCount() throws {
        let spans = createMultipleTestSpans(count: 5)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let totalCount = try spansStorage.getSpanCount()
        XCTAssertEqual(totalCount, 5)
        
        // Test count with filter
        let filteredQuery = SpanQuery(kinds: ["work"])
        let filteredCount = try spansStorage.getSpanCount(filteredQuery)
        XCTAssertLessThanOrEqual(filteredCount, totalCount)
    }
    
    // MARK: - Performance Tests
    
    func testBulkInsertPerformance() throws {
        let spans = createMultipleTestSpans(count: 1000)
        
        measure {
            do {
                for span in spans {
                    try spansStorage.insertSpan(span)
                }
            } catch {
                XCTFail("Bulk insert failed: \(error)")
            }
        }
    }
    
    func testQueryPerformance() throws {
        // Insert test data
        let spans = createMultipleTestSpans(count: 1000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        measure {
            do {
                let _ = try spansStorage.querySpans(SpanQuery(limit: 100))
            } catch {
                XCTFail("Query performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testDatabaseNotInitialized() {
        let uninitializedStorage = SpansStorage(databasePath: databasePath.appendingPathComponent("uninitialized.db"))
        
        XCTAssertThrowsError(try uninitializedStorage.insertSpan(createTestSpan())) { error in
            XCTAssertTrue(error is SpansStorageError)
            if case SpansStorageError.databaseNotInitialized = error {
                // Expected error
            } else {
                XCTFail("Expected databaseNotInitialized error, got: \(error)")
            }
        }
    }
    
    func testInvalidDatabasePath() {
        let invalidPath = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/spans.db")
        let invalidStorage = SpansStorage(databasePath: invalidPath)
        
        XCTAssertThrowsError(try invalidStorage.initialize()) { error in
            // Should throw some kind of error due to invalid path
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Data Integrity Tests
    
    func testTagsJsonSerialization() throws {
        let complexTags = ["tag with spaces", "tag-with-dashes", "tag_with_underscores", "tag123", ""]
        let span = createTestSpan(tags: complexTags)
        
        try spansStorage.insertSpan(span)
        let retrieved = try spansStorage.getSpan(spanId: span.spanId)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.tags, complexTags)
    }
    
    func testEmptyTags() throws {
        let span = createTestSpan(tags: [])
        
        try spansStorage.insertSpan(span)
        let retrieved = try spansStorage.getSpan(spanId: span.spanId)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.tags, [])
    }
    
    func testNilSummaryMarkdown() throws {
        let span = createTestSpan(summaryMarkdown: nil)
        
        try spansStorage.insertSpan(span)
        let retrieved = try spansStorage.getSpan(spanId: span.spanId)
        
        XCTAssertNotNil(retrieved)
        XCTAssertNil(retrieved?.summaryMarkdown)
    }
    
    func testTimePrecision() throws {
        let now = Date()
        let span = createTestSpan(startTime: now, endTime: now.addingTimeInterval(3600))
        
        try spansStorage.insertSpan(span)
        let retrieved = try spansStorage.getSpan(spanId: span.spanId)
        
        XCTAssertNotNil(retrieved)
        
        // Should maintain nanosecond precision (within reasonable bounds)
        if let retrieved = retrieved {
            let startDiff = abs(retrieved.startTime.timeIntervalSince1970 - span.startTime.timeIntervalSince1970)
            let endDiff = abs(retrieved.endTime.timeIntervalSince1970 - span.endTime.timeIntervalSince1970)
            
            XCTAssertLessThan(startDiff, 0.001) // Within 1ms
            XCTAssertLessThan(endDiff, 0.001)   // Within 1ms
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestSpan(
        spanId: String = UUID().uuidString,
        kind: String = "work",
        startTime: Date = Date().addingTimeInterval(-3600),
        endTime: Date = Date(),
        title: String = "Test Span",
        summaryMarkdown: String? = "Test summary",
        tags: [String] = ["test", "example"]
    ) -> Span {
        return Span(
            spanId: spanId,
            kind: kind,
            startTime: startTime,
            endTime: endTime,
            title: title,
            summaryMarkdown: summaryMarkdown,
            tags: tags
        )
    }
    
    private func createMultipleTestSpans(count: Int = 5) -> [Span] {
        let baseTime = Date()
        return (0..<count).map { index in
            createTestSpan(
                spanId: "test-span-\(index)",
                kind: index % 2 == 0 ? "work" : "personal",
                startTime: baseTime.addingTimeInterval(TimeInterval(-3600 * (count - index))),
                endTime: baseTime.addingTimeInterval(TimeInterval(-3600 * (count - index - 1))),
                title: "Test Span \(index)",
                tags: ["test", "span-\(index)"]
            )
        }
    }
}