//
//  BaselineEngineTests.swift
//  heatlabTests
//
//  Unit tests for BaselineEngine calculations
//

import XCTest
import SwiftData
@testable import heatlab

final class BaselineEngineTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var baselineEngine: BaselineEngine!
    
    override func setUpWithError() throws {
        let schema = Schema([WorkoutSession.self, UserBaseline.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
        baselineEngine = BaselineEngine(modelContext: modelContext)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        baselineEngine = nil
    }
    
    // MARK: - Temperature Bucket Tests
    
    func testTemperatureBucketWarm() {
        XCTAssertEqual(TemperatureBucket.from(temperature: 80), .warm)
        XCTAssertEqual(TemperatureBucket.from(temperature: 85), .warm)
        XCTAssertEqual(TemperatureBucket.from(temperature: 89), .warm)
    }
    
    func testTemperatureBucketHot() {
        XCTAssertEqual(TemperatureBucket.from(temperature: 90), .hot)
        XCTAssertEqual(TemperatureBucket.from(temperature: 95), .hot)
        XCTAssertEqual(TemperatureBucket.from(temperature: 99), .hot)
    }
    
    func testTemperatureBucketVeryHot() {
        XCTAssertEqual(TemperatureBucket.from(temperature: 100), .veryHot)
        XCTAssertEqual(TemperatureBucket.from(temperature: 102), .veryHot)
        XCTAssertEqual(TemperatureBucket.from(temperature: 104), .veryHot)
    }
    
    func testTemperatureBucketExtreme() {
        XCTAssertEqual(TemperatureBucket.from(temperature: 105), .extreme)
        XCTAssertEqual(TemperatureBucket.from(temperature: 110), .extreme)
        XCTAssertEqual(TemperatureBucket.from(temperature: 115), .extreme)
    }
    
    func testTemperatureBucketUnheated() {
        // Test that a session without temperature gets the unheated bucket
        let session = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: nil)
        XCTAssertEqual(session.temperatureBucket, .unheated)
    }
    
    // MARK: - Baseline Update Tests
    
    // MARK: - Test Helpers
    
    /// Creates a test heated session with a unique workoutUUID
    private func makeTestSession(startDate: Date = Date(), roomTemperature: Int) -> WorkoutSession {
        WorkoutSession(workoutUUID: UUID(), startDate: startDate, roomTemperature: roomTemperature)
    }
    
    func testUpdateBaselineCreatesNew() {
        let session = makeTestSession(roomTemperature: 102)
        modelContext.insert(session)
        
        baselineEngine.updateBaseline(for: session, averageHR: 145)
        
        let baseline = baselineEngine.baseline(for: .veryHot)
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.averageHR, 145)
        XCTAssertEqual(baseline?.sessionCount, 1)
    }
    
    func testUpdateBaselineCalculatesRollingAverage() {
        // First session
        let session1 = makeTestSession(roomTemperature: 102)
        modelContext.insert(session1)
        baselineEngine.updateBaseline(for: session1, averageHR: 140)
        
        // Second session
        let session2 = makeTestSession(roomTemperature: 103)
        modelContext.insert(session2)
        baselineEngine.updateBaseline(for: session2, averageHR: 150)
        
        let baseline = baselineEngine.baseline(for: .veryHot)
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.averageHR, 145) // (140 + 150) / 2
        XCTAssertEqual(baseline?.sessionCount, 2)
    }
    
    func testUpdateBaselineIgnoresZeroHR() {
        let session = makeTestSession(roomTemperature: 102)
        modelContext.insert(session)
        
        baselineEngine.updateBaseline(for: session, averageHR: 0)
        
        let baseline = baselineEngine.baseline(for: .veryHot)
        XCTAssertNil(baseline)
    }
    
    // MARK: - Baseline Comparison Tests
    
    func testCompareToBaselineInsufficientData() {
        let session = makeTestSession(roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: session,
            workout: nil,
            stats: SessionStats(averageHR: 145, maxHR: 160, minHR: 100, calories: 300, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .insufficientData(_, let bucket) = comparison {
            XCTAssertEqual(bucket, .veryHot)
        } else {
            XCTFail("Expected insufficient data")
        }
    }
    
    func testCompareToBaselineTypical() throws {
        // Build baseline with 3+ sessions
        for i in 0..<3 {
            let session = makeTestSession(startDate: Date().addingTimeInterval(TimeInterval(i * 86400)), roomTemperature: 102)
            modelContext.insert(session)
            baselineEngine.updateBaseline(for: session, averageHR: 145)
        }
        
        // Test session within 5% of baseline
        let testSession = makeTestSession(roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: testSession,
            workout: nil,
            stats: SessionStats(averageHR: 147, maxHR: 160, minHR: 100, calories: 300, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .typical(let bucket) = comparison {
            XCTAssertEqual(bucket, .veryHot)
        } else {
            XCTFail("Expected typical comparison, got \(comparison)")
        }
    }
    
    func testCompareToBaselineHigherEffort() throws {
        // Build baseline
        for i in 0..<3 {
            let session = makeTestSession(startDate: Date().addingTimeInterval(TimeInterval(i * 86400)), roomTemperature: 102)
            modelContext.insert(session)
            baselineEngine.updateBaseline(for: session, averageHR: 140)
        }
        
        // Test session 10% above baseline
        let testSession = makeTestSession(roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: testSession,
            workout: nil,
            stats: SessionStats(averageHR: 154, maxHR: 170, minHR: 100, calories: 350, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .higherEffort(let percent, let bucket) = comparison {
            XCTAssertEqual(percent, 10, accuracy: 1)
            XCTAssertEqual(bucket, .veryHot)
        } else {
            XCTFail("Expected higher effort comparison")
        }
    }
    
    func testCompareToBaselineLowerEffort() throws {
        // Build baseline
        for i in 0..<3 {
            let session = makeTestSession(startDate: Date().addingTimeInterval(TimeInterval(i * 86400)), roomTemperature: 102)
            modelContext.insert(session)
            baselineEngine.updateBaseline(for: session, averageHR: 150)
        }
        
        // Test session 10% below baseline
        let testSession = makeTestSession(roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: testSession,
            workout: nil,
            stats: SessionStats(averageHR: 135, maxHR: 150, minHR: 90, calories: 250, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .lowerEffort(let percent, let bucket) = comparison {
            XCTAssertEqual(percent, 10, accuracy: 1)
            XCTAssertEqual(bucket, .veryHot)
        } else {
            XCTFail("Expected lower effort comparison")
        }
    }
    
    func testCompareToBaselineUnheatedSession() throws {
        // Build baseline with 3+ unheated sessions (roomTemperature = nil)
        for i in 0..<3 {
            let session = WorkoutSession(workoutUUID: UUID(), startDate: Date().addingTimeInterval(TimeInterval(i * 86400)), roomTemperature: nil)
            modelContext.insert(session)
            baselineEngine.updateBaseline(for: session, averageHR: 120)
        }
        
        // Test unheated session
        let testSession = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: nil)
        let sessionWithStats = SessionWithStats(
            session: testSession,
            workout: nil,
            stats: SessionStats(averageHR: 122, maxHR: 140, minHR: 90, calories: 200, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .typical(let bucket) = comparison {
            XCTAssertEqual(bucket, .unheated)
        } else {
            XCTFail("Expected typical comparison for unheated session, got \(comparison)")
        }
    }
}

