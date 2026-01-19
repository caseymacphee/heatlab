//
//  WorkoutManager.swift
//  Heatlab Watch Watch App
//
//  Manages HealthKit workout sessions for hot yoga tracking
//

import HealthKit
import Observation
import Foundation

/// Represents the workout lifecycle as a single source of truth
enum WorkoutPhase: Equatable {
    case idle
    case starting
    case running
    case paused
    case ending
    case completed
    
    var isActive: Bool {
        switch self {
        case .running, .paused, .ending:
            return true
        default:
            return false
        }
    }
}

@Observable
final class WorkoutManager: NSObject {
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    // Single source of truth for workout state
    var phase: WorkoutPhase = .idle
    
    // Completed workout stored directly from builder
    var completedWorkout: HKWorkout?
    
    // Live metrics
    var heartRate: Double = 0
    var activeCalories: Double = 0
    var elapsedTime: TimeInterval = 0

    // Heart rate history for real-time chart
    var hrHistory: [HeartRateDataPoint] = []
    
    // Timer for elapsed time updates
    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        print("🔐 requestAuthorization() called")
        let typesToShare: Set<HKSampleType> = [.workoutType()]
        let typesToRead: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        print("🔐 about to call healthStore.requestAuthorization...")
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        print("🔐 requestAuthorization completed")
    }
    
    // MARK: - Workout Control
    
    func start() async throws {
        print("🏃 start() called, current phase: \(phase)")
        guard phase == .idle else {
            print("⚠️ start() aborted - phase is not idle: \(phase)")
            return
        }
        
        phase = .starting
        print("🏃 phase set to .starting")
        
        do {
            let config = HKWorkoutConfiguration()
            config.activityType = .yoga
            config.locationType = .indoor
            print("🏃 config created")
            
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            print("🏃 session created: \(session != nil)")
            
            builder = session?.associatedWorkoutBuilder()
            print("🏃 builder created: \(builder != nil)")
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            print("🏃 dataSource set")
            
            session?.delegate = self
            builder?.delegate = self
            print("🏃 delegates set")
            
            let date = Date()
            startDate = date
            session?.startActivity(with: date)
            print("🏃 startActivity called")
            
            print("🏃 about to call beginCollection...")
            try await builder?.beginCollection(at: date)
            
            // Delegate should set phase to .running, but add fallback
            // in case it doesn't fire (e.g., simulator)
            if phase == .starting {
                print("🏃 delegate didn't fire, forcing phase to .running")
                phase = .running
            }
            print("🏃 starting timer, phase: \(phase)")
            startTimer()
        } catch {
            print("❌ start() error: \(error)")
            // Reset to idle on failure
            phase = .idle
            session = nil
            builder = nil
            throw error
        }
    }
    
    func pause() {
        guard phase == .running else { return }
        
        session?.pause()
        // Delegate will set phase to .paused
        stopTimer()
        accumulatedTime = elapsedTime
    }
    
    func resume() {
        guard phase == .paused else { return }
        
        session?.resume()
        // Delegate will set phase to .running
        startDate = Date()
        startTimer()
    }
    
    func end() async throws {
        guard phase == .running || phase == .paused else { return }
        
        phase = .ending
        stopTimer()
        
        session?.end()
        
        if let builder = builder {
            try await builder.endCollection(at: Date())
            completedWorkout = try await builder.finishWorkout()
        }
        phase = .completed
    }
    
    func reset() {
        stopTimer()
        session = nil
        builder = nil
        completedWorkout = nil
        heartRate = 0
        activeCalories = 0
        elapsedTime = 0
        accumulatedTime = 0
        startDate = nil
        hrHistory = []
        phase = .idle
    }
    
    // MARK: - Timer
    
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
        print("📣 delegate: state changed from \(fromState.rawValue) to \(toState.rawValue)")
        DispatchQueue.main.async {
            print("📣 delegate (main): current phase: \(self.phase), toState: \(toState.rawValue)")
            switch toState {
            case .running:
                // Only transition to running if we're starting or paused
                if self.phase == .starting || self.phase == .paused {
                    print("📣 delegate: setting phase to .running")
                    self.phase = .running
                }
            case .paused:
                if self.phase == .running {
                    print("📣 delegate: setting phase to .paused")
                    self.phase = .paused
                }
            case .ended:
                print("📣 delegate: session ended")
                // Ending is handled by end() after builder finishes
                // Only reset if we weren't already ending (unexpected termination)
                if self.phase != .ending && self.phase != .completed {
                    self.phase = .idle
                }
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ Workout session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            // Reset to idle on failure unless we're completing
            if self.phase != .completed {
                self.phase = .idle
            }
        }
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
                    let newHR = statistics?.mostRecentQuantity()?.doubleValue(for: hrUnit) ?? 0
                    self.heartRate = newHR

                    // Append to history for real-time chart
                    if newHR > 0 {
                        let dataPoint = HeartRateDataPoint(heartRate: newHR, timeOffset: self.elapsedTime)
                        self.hrHistory.append(dataPoint)
                    }
                    
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
