# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Heat Lab is a hot yoga tracking iOS + watchOS companion app. It tracks heated class sessions with heart rate monitoring, calculates personal baselines by temperature range, and generates AI-powered summaries.

**Key Differentiator:** Purpose-built for heated classes - captures heat context (temperature + class type), compares sessions against personal baselines (not population norms), and positions Apple Watch as the hands-free tracking companion in hot room conditions.

## Architecture

### Dual-Platform Companion App
- **Watch:** Source of truth for workout tracking. Local-first with manual CloudKit sync via `SyncEngine`
- **iOS:** Read-only display layer. Pulls data from CloudKit + HealthKit

### Data Storage Strategy (Critical)
Two separate sync systems handle different data types:

1. **HealthKit** (biometric data - DO NOT store elsewhere):
   - Heart rate samples (every 10 seconds during workout)
   - HKWorkout records with duration/calories
   - Syncs automatically via iCloud Health

2. **SwiftData + CloudKit** (app metadata only):
   - Room temperature, class type, user notes
   - Computed baselines (average HR by temperature bucket)
   - AI-generated summaries
   - Container: `iCloud.com.macpheelabs.heatlab`

**NEVER duplicate health data to CloudKit.** This violates Apple privacy guidelines and risks App Store rejection.

### Sync Flow
```
Watch: HKWorkoutSession → HealthKit (biometrics)
       HeatSession → SwiftData → SyncEngine → CloudKit (metadata)

iOS:   HealthKit → SessionRepository (biometrics)
       CloudKit → SwiftData → SessionRepository (metadata)
       Combined → UI display
```

**Watch-to-iOS Fast Lane:** `WatchConnectivity` provides immediate relay when iPhone is reachable. `SyncEngine` marks sessions as synced when iPhone acknowledges receipt, then CloudKit handles long-term sync.

### Model Container Configuration
- **Watch:** Local-only (`cloudKitDatabase: .none`) - `SyncEngine` handles manual CloudKit sync
- **iOS:** CloudKit-enabled (`cloudKitDatabase: .private`) - automatic pull sync

## Common Commands

### Build & Run
```bash
# List available schemes/targets
xcodebuild -list

# Build iOS app for simulator
xcodebuild -scheme Heatlab -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Build Watch app for simulator
xcodebuild -scheme HeatlabWatch -configuration Debug \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'

# List available simulators
xcrun simctl list devices available

# Boot iPhone simulator
xcrun simctl boot "iPhone 16 Pro"

# Boot Watch simulator (requires paired iPhone simulator)
xcrun simctl boot "Apple Watch Series 10 (46mm)"

# View logs for app
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.macpheelabs.heatlab"'
```

### Testing
```bash
# Run iOS unit tests
xcodebuild test -scheme Heatlab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run Watch unit tests
xcodebuild test -scheme HeatlabWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'

# Run specific test
xcodebuild test -scheme Heatlab -only-testing:HeatlabTests/BaselineEngineTests/testRollingAverage
```

## Code Architecture

### Core Services

**Watch App:**
- `WorkoutManager`: HealthKit workout session lifecycle (`HKWorkoutSession`, `HKLiveWorkoutBuilder`)
  - Tracks workout phases: idle → starting → running → paused → ending → completed
  - Delegates provide live HR/calorie updates every 10 seconds
  - Returns completed `HKWorkout` with all samples attached

- `SyncEngine`: Opportunistic CloudKit sync for local-first data
  - Tries WatchConnectivity first (fast lane when iPhone reachable)
  - Falls back to CloudKit for offline sessions
  - Tracks sync state: pending → uploading → synced/failed
  - Call `syncPending()` on session save, app foreground, background refresh

- `WatchConnectivityRelay`: Sends sessions to iPhone when reachable
  - Bidirectional: receives `UserSettings` from iPhone, sends `HeatSession` to iPhone

**iOS App:**
- `SessionRepository`: Unified data access merging SwiftData metadata + HealthKit biometrics
  - Fetches `HeatSession` from SwiftData (synced from Watch via CloudKit)
  - Fetches corresponding `HKWorkout` and HR samples from HealthKit
  - Combines into `SessionWithStats` for UI display
  - iOS NEVER writes to session records - Watch is the single source of truth

- `BaselineEngine`: Personal baseline calculation by temperature bucket
  - Buckets: 80-89°F (warm), 90-99°F (hot), 100-104°F (very hot), 105°F+ (extreme)
  - Rolling average: `(baseline.avgHR * count + newHR) / (count + 1)`
  - Requires ≥3 sessions per bucket before comparison
  - Deviation thresholds: ±5% = typical, >5% = higher/lower effort

- `TrendCalculator`: Trend analysis over time
  - Intensity trend: average HR by date for a temperature bucket
  - Acclimation signal: compares first 5 vs last 5 sessions at a temperature range
  - Improving = ≥3% drop in average HR (user is adapting to heat)

- `SummaryGenerator`: Apple Intelligence integration
  - Uses `FoundationModels` framework for on-device text generation
  - Prompt includes: class type, temperature, duration, HR stats, baseline comparison
  - Caches summary in `HeatSession.aiSummary`

- `WatchConnectivityReceiver`: Fast-lane sync from Watch
  - Receives `HeatSession` records when Watch is reachable
  - Inserts into SwiftData (marked as `.synced` since Watch already has it)
  - Sends `UserSettings` to Watch when app opens

### SwiftData Models

**HeatSession** (metadata only - NO biometric data):
```swift
var id: UUID
var workoutUUID: UUID?        // Links to HKWorkout in HealthKit
var startDate/endDate: Date
var roomTemperature: Int      // Actual temp (e.g., 95, 105)
var sessionTypeId: UUID?      // References SessionTypeConfig
var userNotes: String?
var aiSummary: String?
var manualDurationOverride: TimeInterval?  // Override HealthKit duration
var perceivedEffort: PerceivedEffort
var syncState: SyncState      // pending/uploading/synced/failed
var deletedAt: Date?          // Soft delete tombstone
```

**UserBaseline** (computed averages):
```swift
var temperatureBucket: TemperatureBucket  // 80-89, 90-99, 100-104, 105+
var averageHR: Double                     // Rolling average for this bucket
var sessionCount: Int                     // Number of sessions in average
var updatedAt: Date
```

**SessionStats** (computed from HealthKit, not stored):
```swift
var averageHR: Double         // Mean of all HR samples
var maxHR/minHR: Double      // Peak/lowest HR during session
var calories: Double         // Active energy from HKWorkout
var duration: TimeInterval   // From HKWorkout or manual override
```

### UI Patterns

**Watch App:**
- `StartView`: Initiate workout, request HealthKit auth
- `ActiveSessionView`: Live HR/calories/timer, pause/resume/end controls
- `SessionConfirmationView`: Digital Crown temperature dial (80-115°F), class type picker
- `TemperatureDialView`: `.digitalCrownRotation()` modifier for tactile temperature selection

**iOS App:**
- `DashboardView`: Overview with recent sessions, quick stats
- `HistoryView`: List of all sessions with `NavigationStack`
- `SessionDetailView`: Stats grid, baseline comparison, heart rate chart, AI summary
- `TrendsView`: Swift Charts visualization of HR over time by temperature bucket
- `AnalysisView`: Detailed insights and trends

## Development Workflow

### Cursor + Xcode Hybrid Approach
- **Write code in Cursor** (Swift, SwiftUI) - faster editing, AI assistance
- **Build via CLI** (`xcodebuild` or XcodeBuildMCP) - no need to open Xcode for iteration
- **Use Xcode IDE for:**
  - Initial project/target setup
  - Capabilities (HealthKit, CloudKit, Background Modes)
  - Asset catalog editing (icons, colors)
  - Device debugging (physical Watch/iPhone pairing)
  - TestFlight archiving and upload

### Testing Strategy
- Unit tests for `BaselineEngine`, `TrendCalculator` (see `HeatlabTests/`)
- Physical Apple Watch testing required for:
  - HealthKit workout session accuracy in hot environment
  - Always On display behavior during class
  - Battery life during 60-minute sessions

## Key Constraints

### Apple Requirements
- Minimum OS: iOS 18.0 / watchOS 11.0 (for Foundation Models, latest SwiftData)
- HealthKit biometric data MUST stay in HealthKit (privacy, App Store policy)
- CloudKit free tier: 10GB assets, 100MB database, 2GB transfer/day (sufficient for metadata-only)

### Product Philosophy
- **No instruction or coaching:** App tracks classes that teachers lead
- **No timers or segments:** Just start/pause/resume/end (teacher controls pacing)
- **No social features:** Personal baseline comparison only, not leaderboards
- **No medical claims:** Trends for personal insight, not diagnosis
- **Studio-native companion:** Designed for students who attend heated classes, not at-home routines

### Session Recording Flow
1. Start workout on Watch (no pre-configuration)
2. HR captured every 10 seconds automatically
3. Stop workout when class ends
4. **Post-class:** Set temperature via Digital Crown dial + optional class type
5. Resume or End session
6. Session saves locally, syncs to iPhone via WatchConnectivity (fast) or CloudKit (eventual)
7. iOS app displays with baseline comparison and AI summary

## Important Patterns

### Local-First Architecture
- Watch saves sessions immediately to local SwiftData (never blocked on network)
- `SyncEngine` retries failed syncs on app foreground/background refresh
- Soft deletes use `deletedAt` tombstone (propagates via CloudKit)
- `syncState` tracks each record's sync status individually

### Baseline Comparison Logic
```swift
// Requires ≥3 sessions in temperature bucket
let deviation = (currentHR - baseline.averageHR) / baseline.averageHR
switch deviation {
  case ..<(-0.05): .lowerEffort    // >5% below
  case (-0.05)...0.05: .typical    // ±5%
  default: .higherEffort           // >5% above
}
```

### Temperature Buckets (Not Exact Temps)
Baselines group by 5°F ranges to ensure enough sessions per bucket:
- 80-89°F → warm
- 90-99°F → hot (most common studio range)
- 100-104°F → very hot
- 105°F+ → extreme

### Manual Duration Override
If user manually sets duration (e.g., class was longer but Watch stopped early), `manualDurationOverride` takes precedence over `HKWorkout.duration` in stats calculations.

## File Organization

```
Shared/           # Code shared between iOS + Watch
  Models/         # SwiftData models (HeatSession, UserBaseline)
  Temperature.swift, SessionTypeConfig.swift, UserSettings.swift
  HeatLabModelContainer.swift  # Platform-specific container configs

Heatlab/          # iOS app
  Services/       # BaselineEngine, TrendCalculator, SummaryGenerator, SessionRepository
  Views/          # SwiftUI views (Dashboard, History, Trends, Analysis, Settings)
    Components/   # Reusable UI (StatCard, TemperatureBadge, charts)

HeatlabWatch/     # watchOS app
  Services/       # WorkoutManager, SyncEngine, WatchConnectivity
  Views/          # StartView, ActiveSessionView, SessionConfirmationView

HeatlabTests/     # iOS unit tests
HeatlabWatchTests/  # Watch unit tests
```

## Common Pitfalls

1. **Do not store HR samples in SwiftData/CloudKit** - Only store the `workoutUUID` link, fetch samples from HealthKit on-demand

2. **Watch is the single writer** - iOS should never modify `HeatSession` or `UserBaseline` records. It's read-only.

3. **CloudKit sync is eventual** - UI must handle sessions without linked workouts yet (show loading state or partial data)

4. **Temperature is stored as exact Int** - Conversion to bucket happens at query time via `temperatureBucket` computed property

5. **Baseline calculation is rolling average** - Don't replace the baseline, update it incrementally to incorporate new sessions

6. **Sync state management** - Mark sessions as `pending` whenever modified, even if previously `synced`

7. **Digital Crown requires `.focusable()`** - Temperature dial won't respond to crown without this modifier

## Apple Intelligence Integration

### Foundation Models API
```swift
let session = LanguageModelSession()
let response = try await session.respond(to: prompt)
return response.content
```

### Prompt Structure
Include computed stats + baseline comparison context:
- Class type, temperature, duration
- Average/max HR, calories
- Comparison text: "typical effort" / "higher than usual" / "lower than usual"
- Instruction: "Be encouraging but not over-the-top, focus on personal baseline comparison"

### Availability
- Requires iOS 18+ (enforced by minimum deployment target)
- On-device processing (no data leaves device)
- Graceful degradation: If Foundation Models unavailable, show stats without AI summary

## Debugging

### Logging Conventions
```swift
print("🏃 start() called")    // Lifecycle events
print("🔐 requestAuthorization...")  // Auth flow
print("📣 delegate: state changed...")  // HealthKit delegate callbacks
print("❌ error: \(error)")    // Errors
```

### Common Issues
- **"No HR data"**: Check HealthKit read permissions, ensure Watch is worn snugly
- **"Session not syncing"**: Check CloudKit container ID matches entitlements, verify iCloud signed in
- **"Baseline not updating"**: Ensure `BaselineEngine.updateBaseline()` called after session save
- **"Digital Crown not working"**: Add `.focusable()` to temperature dial view

### HealthKit Query Debugging
```swift
// Check if workout exists
let predicate = HKQuery.predicateForObject(with: workoutUUID)
let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 1, ...)

// Check HR samples count
let hrQuery = HKSampleQuery(sampleType: HKQuantityType(.heartRate), predicate: ..., limit: HKObjectQueryNoLimit, ...)
```
