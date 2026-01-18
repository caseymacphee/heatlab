---
name: Session Editing and Deletion
overview: Add edit and delete functionality to sessions, including new perceived effort field and manual duration override. Make duration, temperature, session type, and notes editable in SessionDetailView with delete support using existing soft delete infrastructure.
todos:
  - id: update-heatsession-model
    content: Add PerceivedEffort enum and manualDurationOverride property to HeatSession model
    status: completed
  - id: update-session-repository
    content: Update SessionRepository.computeStats() to use manualDurationOverride when present, and fix fetchSession(id:) to filter deleted sessions
    status: completed
    dependencies:
      - update-heatsession-model
  - id: create-edit-ui
    content: Add edit mode toggle and editable form fields in SessionDetailView
    status: completed
    dependencies:
      - update-heatsession-model
  - id: add-delete-functionality
    content: Add delete button with confirmation alert in SessionDetailView
    status: completed
    dependencies:
      - create-edit-ui
  - id: display-perceived-effort
    content: Display perceived effort value in SessionDetailView when not none
    status: completed
    dependencies:
      - update-heatsession-model
---

# Session Editing and Deletion Implementation

## Overview

Enable editing and deletion of HeatSession records with the following editable fields: duration (manual override), temperature, session type, notes, and a new perceived effort enum. Delete functionality uses existing soft delete infrastructure.

## Implementation Tasks

### 1. Update HeatSession Model

**File:** `Shared/Models/HeatSession.swift`

- Add `PerceivedEffort` enum with cases: `none`, `veryEasy`, `easy`, `moderate`, `hard`, `veryHard`
- Add `perceivedEffortRaw: String` property (default: `"none"`) for SwiftData compatibility
- Add computed `perceivedEffort: PerceivedEffort` property with getter/setter
- Add `manualDurationOverride: TimeInterval?` property (optional, for overriding HealthKit workout duration)
- Ensure `markUpdated()` is called when editing any field

### 2. Update SessionRepository for Manual Duration and Soft Delete Filtering

**File:** `Heatlab/Services/SessionRepository.swift`

- Update `computeStats()` to check for `session.manualDurationOverride` first
- If override exists, use it; otherwise fall back to workout duration or `endDate - startDate` calculation
- Update `fetchSessionsWithStats()` to pass session to `computeStats()` for duration override check
- **Fix `fetchSession(id:)`** to filter out soft-deleted sessions: add `deletedAt == nil` to predicate (currently missing this check)

### 3. Create Edit Mode UI in SessionDetailView

**File:** `Heatlab/Views/SessionDetailView.swift`

- Add `@State private var isEditing = false` to toggle edit mode
- Add navigation bar button to toggle edit mode (Edit/Save)
- Create editable form sections when in edit mode:
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - **Duration:** Time picker or stepper (minutes/seconds) → updates `manualDurationOverride`
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - **Temperature:** Stepper or text field → updates `roomTemperature`
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - **Session Type:** Picker using `settings.manageableSessionTypes` → updates `sessionTypeId`
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - **Notes:** TextEditor for multiline text → updates `userNotes`
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                - **Perceived Effort:** Picker with all `PerceivedEffort` cases → updates `perceivedEffort`
- Add delete button (destructive style) that shows confirmation alert
- On save: call `session.markUpdated()`, save `modelContext`, exit edit mode
- On delete: call `session.softDelete()`, save `modelContext`, navigate back
- Display perceived effort in view mode (when not editing)

### 4. Handle Deletion Navigation

**File:** `Heatlab/Views/SessionDetailView.swift` or `Heatlab/Views/HistoryView.swift`

- After soft delete, dismiss SessionDetailView (use `@Environment(\.dismiss)` or update parent to refresh)
- Update HistoryView to refresh list after navigation pop (existing refreshable should handle this)

### 5. Update SessionStats Display

**File:** `Heatlab/Views/SessionDetailView.swift`

- Duration display should already use `session.stats.duration` which will now include manual override
- Add perceived effort display in view mode (if not `none`)

## Data Flow

```
SessionDetailView (Edit Mode)
  ↓
Update HeatSession properties:
  - manualDurationOverride
  - roomTemperature  
  - sessionTypeId
  - userNotes
  - perceivedEffort
  ↓
Call session.markUpdated() → updates syncState to .pending
  ↓
Save modelContext → triggers SwiftData persistence
  ↓
Soft delete (if requested) → sets deletedAt, marks for sync
```

## Notes

- `userNotes` already exists in model - only needs UI
- Soft delete infrastructure exists (`softDelete()`, `deletedAt`) - only needs UI trigger
- `markUpdated()` already handles sync state management
- Manual duration override takes precedence over HealthKit workout duration
- Perceived effort defaults to `none` for existing sessions

## Soft Delete Verification

**Current state:**

- ✅ `SessionRepository.fetchSessionsWithStats()` filters `deletedAt == nil` (line 36)
- ⚠️ `SessionRepository.fetchSession(id:)` does NOT filter deleted sessions - needs fix
- ✅ `TrendCalculator` and `AnalysisCalculator` receive pre-filtered sessions from repository
- ✅ Watch/Sync infrastructure properly handles `deletedAt` field in CloudKit sync

**Action required:**

- Fix `fetchSession(id:)` to exclude soft-deleted sessions to prevent accessing deleted sessions via direct navigation