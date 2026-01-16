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
        let schema = Schema([HeatSession.self, UserBaseline.self])
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
    
    // MARK: - Baseline Update Tests
    
    func testUpdateBaselineCreatesNew() {
        let session = HeatSession(startDate: Date(), roomTemperature: 102)
        modelContext.insert(session)
        
        baselineEngine.updateBaseline(for: session, averageHR: 145)
        
        let baseline = baselineEngine.baseline(for: .veryHot)
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.averageHR, 145)
        XCTAssertEqual(baseline?.sessionCount, 1)
    }
    
    func testUpdateBaselineCalculatesRollingAverage() {
        // First session
        let session1 = HeatSession(startDate: Date(), roomTemperature: 102)
        modelContext.insert(session1)
        baselineEngine.updateBaseline(for: session1, averageHR: 140)
        
        // Second session
        let session2 = HeatSession(startDate: Date(), roomTemperature: 103)
        modelContext.insert(session2)
        baselineEngine.updateBaseline(for: session2, averageHR: 150)
        
        let baseline = baselineEngine.baseline(for: .veryHot)
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.averageHR, 145) // (140 + 150) / 2
        XCTAssertEqual(baseline?.sessionCount, 2)
    }
    
    func testUpdateBaselineIgnoresZeroHR() {
        let session = HeatSession(startDate: Date(), roomTemperature: 102)
        modelContext.insert(session)
        
        baselineEngine.updateBaseline(for: session, averageHR: 0)
        
        let baseline = baselineEngine.baseline(for: .veryHot)
        XCTAssertNil(baseline)
    }
    
    // MARK: - Baseline Comparison Tests
    
    func testCompareToBaselineInsufficientData() {
        let session = HeatSession(startDate: Date(), roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: session,
            workout: nil,
            stats: SessionStats(averageHR: 145, maxHR: 160, minHR: 100, calories: 300, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .insufficientData = comparison {
            // Expected
        } else {
            XCTFail("Expected insufficient data")
        }
    }
    
    func testCompareToBaselineTypical() throws {
        // Build baseline with 3+ sessions
        for i in 0..<3 {
            let session = HeatSession(startDate: Date().addingTimeInterval(TimeInterval(i * 86400)), roomTemperature: 102)
            modelContext.insert(session)
            baselineEngine.updateBaseline(for: session, averageHR: 145)
        }
        
        // Test session within 5% of baseline
        let testSession = HeatSession(startDate: Date(), roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: testSession,
            workout: nil,
            stats: SessionStats(averageHR: 147, maxHR: 160, minHR: 100, calories: 300, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .typical = comparison {
            // Expected
        } else {
            XCTFail("Expected typical comparison, got \(comparison)")
        }
    }
    
    func testCompareToBaselineHigherEffort() throws {
        // Build baseline
        for i in 0..<3 {
            let session = HeatSession(startDate: Date().addingTimeInterval(TimeInterval(i * 86400)), roomTemperature: 102)
            modelContext.insert(session)
            baselineEngine.updateBaseline(for: session, averageHR: 140)
        }
        
        // Test session 10% above baseline
        let testSession = HeatSession(startDate: Date(), roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: testSession,
            workout: nil,
            stats: SessionStats(averageHR: 154, maxHR: 170, minHR: 100, calories: 350, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .higherEffort(let percent) = comparison {
            XCTAssertEqual(percent, 10, accuracy: 1)
        } else {
            XCTFail("Expected higher effort comparison")
        }
    }
    
    func testCompareToBaselineLowerEffort() throws {
        // Build baseline
        for i in 0..<3 {
            let session = HeatSession(startDate: Date().addingTimeInterval(TimeInterval(i * 86400)), roomTemperature: 102)
            modelContext.insert(session)
            baselineEngine.updateBaseline(for: session, averageHR: 150)
        }
        
        // Test session 10% below baseline
        let testSession = HeatSession(startDate: Date(), roomTemperature: 102)
        let sessionWithStats = SessionWithStats(
            session: testSession,
            workout: nil,
            stats: SessionStats(averageHR: 135, maxHR: 150, minHR: 90, calories: 250, duration: 3600)
        )
        
        let comparison = baselineEngine.compareToBaseline(session: sessionWithStats)
        
        if case .lowerEffort(let percent) = comparison {
            XCTAssertEqual(percent, 10, accuracy: 1)
        } else {
            XCTFail("Expected lower effort comparison")
        }
    }
}

