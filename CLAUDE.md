# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HeatLab is a heat training tracking app for iOS and watchOS. Users record sessions on Apple Watch, which syncs to iPhone via dual-path delivery (WatchConnectivity + CloudKit). The iPhone app provides analysis, baselines, and trend tracking.

**Stack**: Swift, SwiftUI, SwiftData, HealthKit, CloudKit, WatchConnectivity, StoreKit 2
**Platforms**: iOS 17+, watchOS 10+
**Build**: Xcode 15+ (no CLI build scripts)

## Build & Test Commands

```bash
# Build iOS app
xcodebuild -scheme Heatlab -destination 'platform=iOS Simulator,name=iPhone 15'

# Build watchOS app
xcodebuild -scheme HeatlabWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

# Run iOS unit tests
xcodebuild test -scheme Heatlab -destination 'platform=iOS Simulator,name=iPhone 15'

# Run a specific test class
xcodebuild test -scheme Heatlab -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HeatlabTests/BaselineEngineTests

# Run a specific test method
xcodebuild test -scheme Heatlab -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HeatlabTests/BaselineEngineTests/testBaselineCalculation
```

Most development is done directly in Xcode (⌘B to build, ⌘U to test).

## Architecture

```
Shared/           # Cross-platform models, services, theme
├── Models/       # WorkoutSession, UserBaseline, SessionStats
├── Services/     # SubscriptionManager (StoreKit 2)
└── Theme/        # HeatLabTheme, HeatLabStyles

Heatlab/          # iOS app
├── Services/     # SessionRepository, BaselineEngine, TrendCalculator, AnalysisCalculator
└── Views/        # Dashboard, Analysis, History, Settings, Paywall

HeatlabWatch/     # watchOS app
├── Services/     # WorkoutManager, SyncEngine, WatchConnectivityRelay
└── Views/        # ActiveSession, SessionConfirmation, Start
```

### Key Patterns

**Data ownership**: Watch creates sessions, iPhone reads them. iOS is read-only for Watch-created data.

**Sync architecture**: Outbox pattern with dual-path delivery:
- Fast lane: `sendMessage` when reachable (immediate ACK)
- Slow lane: `transferUserInfo` (queued, survives app termination)

**Idempotent sync**: All syncs use `workoutUUID` as unique key. Upsert only updates if incoming `updatedAt` > existing.

**Soft deletes**: `deletedAt` timestamp instead of hard delete. Queries filter `session.deletedAt == nil`.

**Environment buckets**: Temperature-based groupings (Non-heated, Warm 80-89°F, Hot 90-99°F, Very Hot 100-104°F, Extreme 105°F+) for baseline comparison.

### Core Services

| Service | Location | Purpose |
|---------|----------|---------|
| `SessionRepository` | iOS | Unified data access, enriches SwiftData with HealthKit stats |
| `BaselineEngine` | iOS | Rolling avg HR per environment bucket, requires 3+ sessions |
| `TrendCalculator` | iOS | Acclimation tracking (first 5 vs last 5 sessions) |
| `AnalysisCalculator` | iOS | Period comparisons (Week/Month/Year) with deltas |
| `WorkoutManager` | watchOS | HealthKit workout session lifecycle |
| `SyncEngine` | watchOS | Outbox pattern for at-least-once delivery |

### SwiftData Models

- **iOS**: `[WorkoutSession, UserBaseline, ImportedWorkout]` + CloudKit sync
- **watchOS**: `[WorkoutSession, UserBaseline, OutboxItem]` local only (no CloudKit)

## Configuration

- CloudKit container: `iCloud.com.macpheelabs.heatlab`
- Bundle ID: `com.macpheelabs.heatlab`
- StoreKit products: `com.heatlab.pro.monthly`, `com.heatlab.pro.annual`
