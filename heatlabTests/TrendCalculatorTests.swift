//
//  TrendCalculatorTests.swift
//  heatlabTests
//
//  Unit tests for TrendCalculator
//

import XCTest
@testable import heatlab

final class TrendCalculatorTests: XCTestCase {
    var calculator: TrendCalculator!
    
    override func setUpWithError() throws {
        calculator = TrendCalculator()
    }
    
    override func tearDownWithError() throws {
        calculator = nil
    }
    
    // MARK: - Helper Methods
    
    private func createSession(daysAgo: Int, temperature: Int, averageHR: Double) -> SessionWithStats {
        let session = HeatSession(
            startDate: Date().addingTimeInterval(TimeInterval(-daysAgo * 86400)),
            roomTemperature: temperature
        )
        return SessionWithStats(
            session: session,
            workout: nil,
            stats: SessionStats(
                averageHR: averageHR,
                maxHR: averageHR + 20,
                minHR: averageHR - 40,
                calories: 300,
                duration: 3600
            )
        )
    }
    
    // MARK: - Intensity Trend Tests
    
    func testCalculateIntensityTrendFiltersbyBucket() {
        let sessions = [
            createSession(daysAgo: 3, temperature: 102, averageHR: 145),  // veryHot
            createSession(daysAgo: 2, temperature: 95, averageHR: 135),   // hot
            createSession(daysAgo: 1, temperature: 103, averageHR: 148),  // veryHot
        ]
        
        let trend = calculator.calculateIntensityTrend(sessions: sessions, bucket: .veryHot)
        
        XCTAssertEqual(trend.count, 2)
    }
    
    func testCalculateIntensityTrendSortsByDate() {
        let sessions = [
            createSession(daysAgo: 1, temperature: 102, averageHR: 150),
            createSession(daysAgo: 3, temperature: 103, averageHR: 145),
            createSession(daysAgo: 2, temperature: 101, averageHR: 148),
        ]
        
        let trend = calculator.calculateIntensityTrend(sessions: sessions, bucket: .veryHot)
        
        XCTAssertEqual(trend.count, 3)
        XCTAssertEqual(trend[0].value, 145)  // Oldest first
        XCTAssertEqual(trend[1].value, 148)
        XCTAssertEqual(trend[2].value, 150)  // Most recent last
    }
    
    func testCalculateIntensityTrendExcludesZeroHR() {
        let sessions = [
            createSession(daysAgo: 2, temperature: 102, averageHR: 145),
            createSession(daysAgo: 1, temperature: 103, averageHR: 0),  // Invalid
        ]
        
        let trend = calculator.calculateIntensityTrend(sessions: sessions, bucket: .veryHot)
        
        XCTAssertEqual(trend.count, 1)
    }
    
    func testCalculateIntensityTrendReturnsEmptyForNoMatches() {
        let sessions = [
            createSession(daysAgo: 1, temperature: 95, averageHR: 135),  // hot bucket
        ]
        
        let trend = calculator.calculateIntensityTrend(sessions: sessions, bucket: .veryHot)
        
        XCTAssertTrue(trend.isEmpty)
    }
    
    // MARK: - Acclimation Tests
    
    func testCalculateAcclimationRequiresMinimumSessions() {
        let sessions = [
            createSession(daysAgo: 4, temperature: 102, averageHR: 150),
            createSession(daysAgo: 3, temperature: 103, averageHR: 148),
            createSession(daysAgo: 2, temperature: 101, averageHR: 145),
            createSession(daysAgo: 1, temperature: 102, averageHR: 143),
        ]
        
        let acclimation = calculator.calculateAcclimation(sessions: sessions, bucket: .veryHot)
        
        XCTAssertNil(acclimation)  // Need 5+ sessions
    }
    
    func testCalculateAcclimationDetectsImprovement() {
        // Create sessions showing decreasing HR over time (improvement)
        let sessions = [
            createSession(daysAgo: 10, temperature: 102, averageHR: 160),
            createSession(daysAgo: 9, temperature: 103, averageHR: 158),
            createSession(daysAgo: 8, temperature: 101, averageHR: 155),
            createSession(daysAgo: 7, temperature: 102, averageHR: 153),
            createSession(daysAgo: 6, temperature: 103, averageHR: 150),
            createSession(daysAgo: 5, temperature: 102, averageHR: 145),
            createSession(daysAgo: 4, temperature: 101, averageHR: 143),
            createSession(daysAgo: 3, temperature: 103, averageHR: 140),
            createSession(daysAgo: 2, temperature: 102, averageHR: 138),
            createSession(daysAgo: 1, temperature: 101, averageHR: 135),
        ]
        
        let acclimation = calculator.calculateAcclimation(sessions: sessions, bucket: .veryHot)
        
        XCTAssertNotNil(acclimation)
        XCTAssertEqual(acclimation?.direction, .improving)
        XCTAssertLessThan(acclimation?.percentChange ?? 0, 0)
    }
    
    func testCalculateAcclimationDetectsStable() {
        // Create sessions showing stable HR
        let sessions = [
            createSession(daysAgo: 10, temperature: 102, averageHR: 145),
            createSession(daysAgo: 9, temperature: 103, averageHR: 146),
            createSession(daysAgo: 8, temperature: 101, averageHR: 144),
            createSession(daysAgo: 7, temperature: 102, averageHR: 145),
            createSession(daysAgo: 6, temperature: 103, averageHR: 146),
            createSession(daysAgo: 5, temperature: 102, averageHR: 145),
            createSession(daysAgo: 4, temperature: 101, averageHR: 144),
            createSession(daysAgo: 3, temperature: 103, averageHR: 146),
            createSession(daysAgo: 2, temperature: 102, averageHR: 145),
            createSession(daysAgo: 1, temperature: 101, averageHR: 145),
        ]
        
        let acclimation = calculator.calculateAcclimation(sessions: sessions, bucket: .veryHot)
        
        XCTAssertNotNil(acclimation)
        XCTAssertEqual(acclimation?.direction, .stable)
    }
    
    // MARK: - Overall Stats Tests
    
    func testCalculateOverallStatsEmpty() {
        let stats = calculator.calculateOverallStats(sessions: [])
        
        XCTAssertEqual(stats.totalSessions, 0)
        XCTAssertEqual(stats.totalDuration, 0)
        XCTAssertEqual(stats.totalCalories, 0)
        XCTAssertEqual(stats.averageHR, 0)
    }
    
    func testCalculateOverallStatsAggregate() {
        let sessions = [
            createSession(daysAgo: 2, temperature: 102, averageHR: 140),
            createSession(daysAgo: 1, temperature: 95, averageHR: 150),
        ]
        
        let stats = calculator.calculateOverallStats(sessions: sessions)
        
        XCTAssertEqual(stats.totalSessions, 2)
        XCTAssertEqual(stats.totalDuration, 7200)  // 2 hours
        XCTAssertEqual(stats.totalCalories, 600)   // 300 * 2
        XCTAssertEqual(stats.averageHR, 145)       // (140 + 150) / 2
    }
    
    func testCalculateOverallStatsExcludesInvalidSessions() {
        let validSession = createSession(daysAgo: 1, temperature: 102, averageHR: 145)
        let invalidSession = createSession(daysAgo: 2, temperature: 95, averageHR: 0)
        
        let stats = calculator.calculateOverallStats(sessions: [validSession, invalidSession])
        
        XCTAssertEqual(stats.totalSessions, 1)
    }
}

