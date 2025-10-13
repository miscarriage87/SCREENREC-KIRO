import XCTest
import Foundation
@testable import Shared

final class SpansPerformanceTests: XCTestCase {
    var tempDirectory: URL!
    var databasePath: URL!
    var spansStorage: SpansStorage!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test database
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpansPerformanceTests")
            .appendingPathComponent(UUID().uuidString)
        
        databasePath = tempDirectory.appendingPathComponent("performance_spans.db")
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
    
    // MARK: - Insert Performance Tests
    
    func testSingleInsertPerformance() throws {
        let span = createTestSpan()
        
        measure {
            do {
                try spansStorage.insertSpan(span)
            } catch {
                XCTFail("Insert performance test failed: \(error)")
            }
        }
    }
    
    func testBulkInsertPerformance() throws {
        let spans = createMultipleTestSpans(count: 1000)
        
        measure {
            do {
                for span in spans {
                    try spansStorage.insertSpan(span)
                }
            } catch {
                XCTFail("Bulk insert performance test failed: \(error)")
            }
        }
    }
    
    func testBatchInsertPerformance() throws {
        let spans = createMultipleTestSpans(count: 1000)
        
        measure {
            do {
                // Simulate batch insert using transactions
                for batch in spans.chunked(into: 100) {
                    for span in batch {
                        try spansStorage.insertSpan(span)
                    }
                }
            } catch {
                XCTFail("Batch insert performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Query Performance Tests
    
    func testSimpleQueryPerformance() throws {
        // Insert test data
        let spans = createMultipleTestSpans(count: 10000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        measure {
            do {
                let _ = try spansStorage.querySpans(SpanQuery(limit: 100))
            } catch {
                XCTFail("Simple query performance test failed: \(error)")
            }
        }
    }
    
    func testTimeRangeQueryPerformance() throws {
        // Insert test data with varied timestamps
        let baseTime = Date()
        var spans: [Span] = []
        for index in 0..<10000 {
            let startOffset = TimeInterval(-index * 60) // 1 minute intervals
            let endOffset = TimeInterval(-index * 60 + 1800) // 30 minute spans
            let span = createTestSpan(
                startTime: baseTime.addingTimeInterval(startOffset),
                endTime: baseTime.addingTimeInterval(endOffset)
            )
            spans.append(span)
        }
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let queryStartTime = baseTime.addingTimeInterval(-3600) // 1 hour ago
        let queryEndTime = baseTime
        
        measure {
            do {
                let query = SpanQuery(startTime: queryStartTime, endTime: queryEndTime)
                let _ = try spansStorage.querySpans(query)
            } catch {
                XCTFail("Time range query performance test failed: \(error)")
            }
        }
    }
    
    func testKindFilterQueryPerformance() throws {
        // Insert test data with different kinds
        let kinds = ["work", "personal", "meeting", "break", "research"]
        let spans = (0..<10000).map { index in
            createTestSpan(kind: kinds[index % kinds.count])
        }
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        measure {
            do {
                let query = SpanQuery(kinds: ["work", "meeting"])
                let _ = try spansStorage.querySpans(query)
            } catch {
                XCTFail("Kind filter query performance test failed: \(error)")
            }
        }
    }
    
    func testTagFilterQueryPerformance() throws {
        // Insert test data with various tags
        let tagSets = [
            ["urgent", "project-a"],
            ["project-b", "review"],
            ["meeting", "standup"],
            ["research", "analysis"],
            ["documentation", "writing"]
        ]
        
        let spans = (0..<10000).map { index in
            createTestSpan(tags: tagSets[index % tagSets.count])
        }
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        measure {
            do {
                let query = SpanQuery(tags: ["project-a"])
                let _ = try spansStorage.querySpans(query)
            } catch {
                XCTFail("Tag filter query performance test failed: \(error)")
            }
        }
    }
    
    func testComplexQueryPerformance() throws {
        // Insert diverse test data
        let spans = createDiverseTestSpans(count: 10000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let baseTime = Date()
        let query = SpanQuery(
            startTime: baseTime.addingTimeInterval(-7200), // 2 hours ago
            endTime: baseTime,
            kinds: ["work", "meeting"],
            tags: ["urgent"],
            limit: 50
        )
        
        measure {
            do {
                let _ = try spansStorage.querySpans(query)
            } catch {
                XCTFail("Complex query performance test failed: \(error)")
            }
        }
    }
    
    func testOverlappingSpansQueryPerformance() throws {
        // Insert overlapping spans
        let baseTime = Date()
        let spans = (0..<5000).map { index in
            let startOffset = TimeInterval(-index * 30) // 30 second intervals
            let duration = TimeInterval(1800) // 30 minute duration
            return createTestSpan(
                startTime: baseTime.addingTimeInterval(startOffset),
                endTime: baseTime.addingTimeInterval(startOffset + duration)
            )
        }
        
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        measure {
            do {
                let _ = try spansStorage.getOverlappingSpans(
                    startTime: baseTime.addingTimeInterval(-3600),
                    endTime: baseTime
                )
            } catch {
                XCTFail("Overlapping spans query performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Update Performance Tests
    
    func testUpdatePerformance() throws {
        // Insert test data
        let spans = createMultipleTestSpans(count: 1000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        // Update all spans
        let updatedSpans = spans.map { span in
            Span(
                spanId: span.spanId,
                kind: "updated-\(span.kind)",
                startTime: span.startTime,
                endTime: span.endTime,
                title: "Updated \(span.title)",
                summaryMarkdown: span.summaryMarkdown,
                tags: span.tags + ["updated"],
                createdAt: span.createdAt
            )
        }
        
        measure {
            do {
                for span in updatedSpans {
                    try spansStorage.updateSpan(span)
                }
            } catch {
                XCTFail("Update performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Delete Performance Tests
    
    func testDeletePerformance() throws {
        // Insert test data
        let spans = createMultipleTestSpans(count: 1000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        measure {
            do {
                for span in spans {
                    try spansStorage.deleteSpan(spanId: span.spanId)
                }
            } catch {
                XCTFail("Delete performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Count Performance Tests
    
    func testCountPerformance() throws {
        // Insert test data
        let spans = createMultipleTestSpans(count: 10000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        measure {
            do {
                let _ = try spansStorage.getSpanCount()
            } catch {
                XCTFail("Count performance test failed: \(error)")
            }
        }
    }
    
    func testFilteredCountPerformance() throws {
        // Insert diverse test data
        let spans = createDiverseTestSpans(count: 10000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let query = SpanQuery(kinds: ["work", "meeting"])
        
        measure {
            do {
                let _ = try spansStorage.getSpanCount(query)
            } catch {
                XCTFail("Filtered count performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageDuringLargeQuery() throws {
        // Insert large dataset
        let spans = createMultipleTestSpans(count: 50000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        // Measure memory usage during large query
        measure {
            do {
                let _ = try spansStorage.querySpans(SpanQuery(limit: 10000))
            } catch {
                XCTFail("Memory usage test failed: \(error)")
            }
        }
    }
    
    // MARK: - Concurrent Access Performance Tests
    
    func testConcurrentReadPerformance() throws {
        // Insert test data
        let spans = createMultipleTestSpans(count: 5000)
        for span in spans {
            try spansStorage.insertSpan(span)
        }
        
        let expectation = XCTestExpectation(description: "Concurrent reads")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .background)
        
        measure {
            for i in 0..<10 {
                queue.async {
                    do {
                        let query = SpanQuery(limit: 100, offset: i * 100)
                        let _ = try self.spansStorage.querySpans(query)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent read \(i) failed: \(error)")
                    }
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Database Size Tests
    
    func testDatabaseSizeGrowth() throws {
        let initialSize = try getDatabaseSize()
        
        // Insert spans in batches and measure size growth
        let batchSize = 1000
        let batches = 10
        
        for batch in 0..<batches {
            let spans = createMultipleTestSpans(count: batchSize)
            for span in spans {
                try spansStorage.insertSpan(span)
            }
            
            let currentSize = try getDatabaseSize()
            let growthRatio = Double(currentSize) / Double(initialSize)
            
            print("Batch \(batch + 1): Database size = \(currentSize) bytes, Growth ratio = \(growthRatio)")
            
            // Ensure reasonable growth (not exponential)
            XCTAssertLessThan(growthRatio, Double(batch + 2) * 2.0, "Database growth seems excessive")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestSpan(
        kind: String = "work",
        startTime: Date = Date().addingTimeInterval(-3600),
        endTime: Date = Date(),
        title: String = "Test Span",
        tags: [String] = ["test"]
    ) -> Span {
        return Span(
            kind: kind,
            startTime: startTime,
            endTime: endTime,
            title: title,
            summaryMarkdown: "Test summary for performance testing",
            tags: tags
        )
    }
    
    private func createMultipleTestSpans(count: Int) -> [Span] {
        let baseTime = Date()
        var spans: [Span] = []
        for index in 0..<count {
            let startOffset = TimeInterval(-index * 60)
            let endOffset = TimeInterval(-index * 60 + 1800)
            let span = createTestSpan(
                startTime: baseTime.addingTimeInterval(startOffset),
                endTime: baseTime.addingTimeInterval(endOffset),
                title: "Performance Test Span \(index)"
            )
            spans.append(span)
        }
        return spans
    }
    
    private func createDiverseTestSpans(count: Int) -> [Span] {
        let kinds = ["work", "personal", "meeting", "break", "research", "documentation"]
        let tagSets = [
            ["urgent", "project-a"],
            ["project-b", "review"],
            ["meeting", "standup"],
            ["research", "analysis"],
            ["documentation", "writing"],
            ["bug-fix", "critical"]
        ]
        
        let baseTime = Date()
        return (0..<count).map { index in
            let kind = kinds[index % kinds.count]
            let tags = tagSets[index % tagSets.count]
            let startOffset = TimeInterval(-index * 30) // 30 second intervals
            let duration = TimeInterval.random(in: 300...7200) // 5 minutes to 2 hours
            
            return Span(
                kind: kind,
                startTime: baseTime.addingTimeInterval(startOffset),
                endTime: baseTime.addingTimeInterval(startOffset + duration),
                title: "Diverse Test Span \(index)",
                summaryMarkdown: "Summary for span \(index) of kind \(kind)",
                tags: tags
            )
        }
    }
    
    private func getDatabaseSize() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: databasePath.path)
        return attributes[.size] as? Int64 ?? 0
    }
}

// Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}