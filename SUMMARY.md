# Heat Lab - System Summary

Hot yoga tracking app for iOS and watchOS that helps users track their sessions, monitor heart rate adaptation, and understand their acclimation to different temperature environments.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              APPLE WATCH                                     │
│  ┌─────────────────┐    ┌────────────────┐    ┌─────────────────────────┐   │
│  │ WorkoutManager  │───▶│ WorkoutSession │───▶│ SyncEngine + OutboxItem │   │
│  │   (HealthKit)   │    │   (SwiftData)  │    │  (WatchConnectivity)    │   │
│  └─────────────────┘    └────────────────┘    └───────────┬─────────────┘   │
└──────────────────────────────────────────────────────────│─────────────────┘
                                                           │
                    ┌──────────────────────────────────────┘
                    │  Dual-path sync:
                    │  • Fast lane (sendMessage) - immediate when reachable
                    │  • Slow lane (transferUserInfo) - queued, reliable
                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 iPhone                                       │
│  ┌──────────────────────────┐    ┌──────────────────────────────────────┐   │
│  │ WatchConnectivityReceiver│───▶│           SwiftData + CloudKit       │   │
│  │    (upsert by UUID)      │    │  WorkoutSession | UserBaseline        │   │
│  └──────────────────────────┘    └──────────────────────────────────────┘   │
│                                              │                               │
│  ┌───────────────────┐     ┌────────────────┴────────────────┐              │
│  │ HealthKitImporter │────▶│        SessionRepository        │◀─┐           │
│  │  (claim workouts) │     │  (sessions + HealthKit stats)   │  │           │
│  └───────────────────┘     └─────────────────────────────────┘  │           │
│                                                                  │           │
│  ┌───────────────────────────────────────────────────────────────┘           │
│  │  Analysis Layer                                                           │
│  │  ┌────────────────┐  ┌──────────────────┐  ┌─────────────────────────┐   │
│  │  │ BaselineEngine │  │ TrendCalculator  │  │   AnalysisCalculator    │   │
│  │  │ (HR baselines) │  │ (acclimation)    │  │ (WoW/MoM/YoY compare)   │   │
│  │  └────────────────┘  └──────────────────┘  └─────────────────────────┘   │
│  └───────────────────────────────────────────────────────────────────────────│
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Ownership Model

| Platform | Owns | Reads |
|----------|------|-------|
| **Watch** | WorkoutSession creation (via HealthKit workout) | - |
| **iPhone** | UserBaseline, ImportedWorkout (claimed from Health) | WorkoutSession (via CloudKit + WatchConnectivity) |

**Key principle**: iOS is read-only for Watch-created sessions. The Watch is the source of truth for session data, iPhone receives it via dual-path sync and CloudKit pull.

## Core Domain Models

### WorkoutSession (`Shared/Models/WorkoutSession.swift`)
The central entity representing a yoga session:
- Links to HealthKit workout via `workoutUUID`
- Tracks heated state (`isHeated`) and room temperature
- Supports perceived effort ratings and user notes
- Soft-delete support via `deletedAt` tombstone
- Sync state tracking for local-first architecture

### UserBaseline (`Shared/Models/UserBaseline.swift`)
Stores rolling average heart rate per environment bucket:
- Updated incrementally as sessions are added
- Minimum 3 sessions required for baseline comparison
- Order-independent calculation (safe for historical imports)

### Environment Buckets (`SessionEnvironmentBucket`)
Temperature-based groupings for baseline comparison:
- **Non-heated**: `isHeated == false`
- **Warm**: 80-89°F
- **Hot**: 90-99°F  
- **Very Hot**: 100-104°F
- **Extreme**: 105°F+

### SessionStats (`Shared/Models/SessionStats.swift`)
Computed statistics from HealthKit data:
- Average/max/min heart rate
- Active calories burned
- Duration (supports manual override)

## Key Services

### Watch Services

#### WorkoutManager (`HeatlabWatch/Services/WorkoutManager.swift`)
Manages HealthKit workout sessions on watchOS:
- Single source of truth via `WorkoutPhase` enum (idle → starting → running → paused → ending → completed)
- Real-time heart rate tracking with history buffer for live charts
- Delegates to `HKWorkoutSession` and `HKLiveWorkoutBuilder`

#### SyncEngine (`HeatlabWatch/Services/SyncEngine.swift`)
Coordinates session sync from Watch to iPhone:
- Uses outbox pattern for at-least-once delivery
- Enqueues sessions immediately, drains when connectivity available
- iPhone upsert-by-workoutUUID makes duplicate delivery safe

#### WatchConnectivityRelay (`HeatlabWatch/Services/WatchConnectivityRelay.swift`)
Dual-path delivery implementation:
- **Fast lane**: `sendMessage` when iPhone reachable (immediate ACK)
- **Slow lane**: `transferUserInfo` (queued, survives app termination)
- Receives settings sync from iPhone via application context

### iPhone Services

#### SessionRepository (`Heatlab/Services/SessionRepository.swift`)
Unified data access layer:
- Fetches `WorkoutSession` from SwiftData
- Enriches with HealthKit workout data (heart rate samples, calories)
- Returns `SessionWithStats` for UI consumption

#### HealthKitImporter (`Heatlab/Services/HealthKitImporter.swift`)
Imports yoga workouts from Apple Health:
- Fetches yoga workouts from past 7 days
- Filters out already-claimed and dismissed workouts
- Supports dismiss/restore workflow for unwanted workouts

#### BaselineEngine (`Heatlab/Services/BaselineEngine.swift`)
Calculates and compares personal baselines:
- Rolling average per environment bucket
- Comparison returns: typical (±5%), higher effort, lower effort
- Requires minimum 3 sessions per bucket for meaningful comparison

#### TrendCalculator (`Heatlab/Services/TrendCalculator.swift`)
Tracks adaptation over time:
- Intensity trends per environment bucket
- Acclimation signals: compares first 5 vs last 5 sessions
- >3% HR reduction = "improving", else "stable"

#### AnalysisCalculator (`Heatlab/Services/AnalysisCalculator.swift`)
Multi-dimensional analysis with period comparisons:
- Supports Week, Month, Year periods
- Calculates deltas: session count, avg HR, duration, calories, temperature
- Filters by environment bucket, session type, heated state

## Sync Architecture

### Watch → iPhone Sync (Outbox Pattern)

```
1. Session saved on Watch
2. Enqueue to OutboxItem (SwiftData)
3. Dual-path delivery:
   a. transferUserInfo (always) - survives app termination
   b. sendMessage (if reachable) - fast ACK path
4. iPhone receives → upserts by workoutUUID
5. iPhone sends ACK → Watch deletes OutboxItem
```

### iPhone → Watch Sync (Settings)
- Uses `WCSession.updateApplicationContext()`
- Persists until Watch receives, even if app not running
- Contains user preferences (session types, temperature defaults)

### CloudKit Sync (iOS)
- Automatic via SwiftData `ModelConfiguration` with CloudKit database
- Private database: `iCloud.com.macpheelabs.heatlab`
- Handles multi-device iOS sync transparently

## Data Flow: Recording a Session

```
1. [Watch] User starts workout via WorkoutManager
2. [Watch] HealthKit creates HKWorkout, streams HR/calories
3. [Watch] User ends session → WorkoutSession created with workoutUUID
4. [Watch] User enters metadata (temperature, effort, notes)
5. [Watch] SyncEngine.enqueueSession() → OutboxItem created
6. [Watch] WatchConnectivityRelay.drainOutbox()
   - transferUserInfo (queued)
   - sendMessage (if reachable)
7. [iPhone] WatchConnectivityReceiver handles payload
8. [iPhone] Upsert WorkoutSession by workoutUUID
9. [iPhone] Send ACK → Watch deletes OutboxItem
10. [iPhone] CloudKit syncs to other iOS devices
```

## Data Flow: Claiming a Workout (iOS)

```
1. [iPhone] HealthKitImporter fetches yoga workouts from Health
2. [iPhone] Filter: exclude claimed (workoutUUID exists) and dismissed
3. [iPhone] User selects workout, enters metadata
4. [iPhone] claimWorkout() creates WorkoutSession
5. [iPhone] BaselineEngine.updateBaseline() if HR data available
```

## Project Structure

```
heatlab/
├── Heatlab/                    # iOS app
│   ├── HeatlabApp.swift        # Entry point (CloudKit container)
│   ├── Models/
│   │   └── ImportedWorkout.swift  # iOS-only: tracks dismissed workouts
│   ├── Services/
│   │   ├── AnalysisCalculator.swift
│   │   ├── BaselineEngine.swift
│   │   ├── HealthKitImporter.swift
│   │   ├── SessionRepository.swift
│   │   ├── TrendCalculator.swift
│   │   └── WatchConnectivityReceiver.swift
│   └── Views/                  # SwiftUI views
├── HeatlabWatch/               # watchOS app
│   ├── HeatlabWatchApp.swift   # Entry point (local-only container)
│   ├── Models/
│   │   └── OutboxItem.swift    # Sync outbox for reliable delivery
│   ├── Services/
│   │   ├── SyncEngine.swift
│   │   ├── WatchConnectivityRelay.swift
│   │   └── WorkoutManager.swift
│   └── Views/
└── Shared/                     # Cross-platform code
    ├── Models/
    │   ├── SessionStats.swift
    │   ├── UserBaseline.swift
    │   └── WorkoutSession.swift
    ├── HeatLabModelContainer.swift  # CloudKit config
    ├── SessionTypeConfig.swift
    ├── Temperature.swift
    ├── Theme/
    └── UserSettings.swift
```

## Key Implementation Details

### Idempotent Sync
- All syncs use `workoutUUID` as the unique key
- Upsert logic: only update if incoming `updatedAt` > existing `updatedAt`
- Duplicate deliveries are safe (outbox may send via both paths)

### Soft Deletes
- `deletedAt` timestamp used instead of hard delete
- Queries filter: `session.deletedAt == nil`
- Enables sync without conflicts

### Order-Independent Baseline Calculation
- Rolling average formula: `(oldAvg * oldCount + newValue) / (oldCount + 1)`
- Historical imports produce correct baselines regardless of insertion order
- Recalculate option available for bulk imports

### Temperature-Based Environment Buckets
- Non-heated sessions get dedicated baseline
- Heated sessions grouped by temperature range
- Baselines are per-bucket, not global
