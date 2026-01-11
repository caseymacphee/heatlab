//
//  WorkoutManager.swift
//  Heatlab Watch Watch App
//
//  Manages HealthKit workout sessions for hot yoga tracking
//

import HealthKit
import Observation
import Foundation

@Observable
final class WorkoutManager: NSObject {
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    // Live metrics
    var heartRate: Double = 0
    var activeCalories: Double = 0
    var elapsedTime: TimeInterval = 0
    
    // State
    var isActive: Bool = false
    var isPaused: Bool = false
    var showingSummary: Bool = false
    
    // Timer for elapsed time updates
    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0
    
    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    func startWorkout() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .yoga
        config.locationType = .indoor
        
        session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        builder = session?.associatedWorkoutBuilder()
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        
        session?.delegate = self
        builder?.delegate = self
        
        let date = Date()
        startDate = date
        session?.startActivity(with: date)
        try await builder?.beginCollection(at: date)
        
        isActive = true
        isPaused = false
        startTimer()
    }
    
    func pause() {
        session?.pause()
        isPaused = true
        stopTimer()
        accumulatedTime = elapsedTime
    }
    
    func resume() {
        session?.resume()
        isPaused = false
        startDate = Date()
        startTimer()
    }
    
    func endWorkout() async throws -> HKWorkout? {
        stopTimer()
        session?.end()
        try await builder?.endCollection(at: Date())
        let workout = try await builder?.finishWorkout()
        
        isActive = false
        isPaused = false
        showingSummary = true
        
        return workout
    }
    
    func resetWorkout() {
        session = nil
        builder = nil
        heartRate = 0
        activeCalories = 0
        elapsedTime = 0
        accumulatedTime = 0
        isActive = false
        isPaused = false
        showingSummary = false
        startDate = nil
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(startDate)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isActive = true
                self.isPaused = false
            case .paused:
                self.isPaused = true
            case .ended:
                self.isActive = false
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType(.heartRate):
                    let hrUnit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: hrUnit) ?? 0
                    
                case HKQuantityType(.activeEnergyBurned):
                    let calUnit = HKUnit.kilocalorie()
                    self.activeCalories = statistics?.sumQuantity()?.doubleValue(for: calUnit) ?? 0
                    
                default:
                    break
                }
            }
        }
    }
}

