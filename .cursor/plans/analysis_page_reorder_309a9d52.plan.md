---
name: Analysis Page Reorder
overview: Reorder the Analysis page to be "insight-first, controls second, charts prominent" per advisor feedback. Key changes include adding an insight hook, moving filters below the hook, improving temperature formatting, and repositioning the comparison footnote.
todos:
  - id: insight-hook
    content: Create InsightHookView component with 1-2 line summary (avg HR, range, session count, optional comparison delta)
    status: pending
  - id: reorder-sections
    content: "Reorder AnalysisView: Period -> Hook -> AI -> Filters -> Stats -> Chart -> Acclimation -> Footnote"
    status: pending
  - id: demote-ai-unavailable
    content: Make 'AI unavailable' message smaller or hide when not useful
    status: pending
  - id: fix-temp-format
    content: Change temperature display from '99°' to '99°F' in ComparisonCard, AnalysisView, DashboardView
    status: pending
  - id: move-footnote
    content: Move comparison hint to bottom and update wording to 'Comparisons unlock after 2 weeks of data'
    status: pending
---

# Analysis Page Reorder

## Current vs Recommended Order

**Current layout:**

1. Period picker + Filter pills
2. AI Insight section
3. Stats card (ComparisonCard)
4. "Comparison data will appear next..." hint
5. Heart Rate Trend chart
6. Acclimation card

**Target layout:**

1. Period picker (keep at top)
2. **NEW: Insight Summary hook** (1-2 line quick summary)
3. AI Insights card (demote "unavailable" message)
4. Filter pills (moved below hook)
5. Stats card
6. Heart Rate Trend chart
7. Acclimation card
8. Comparison footnote (moved to bottom)

---

## Implementation Details

### 1. Add Insight Summary Hook

Create a new component showing a quick "so what" summary above AI insights:

```swift
// Examples:
// "Avg HR 60 bpm (range 57–62) across 11 sessions."
// "Avg HR +3 bpm vs last week." (only if comparison exists)
```

Place this in [AnalysisView.swift](Heatlab/Views/AnalysisView.swift) after the period picker, before AI section.

### 2. Move Filter Pills Below Hook

In `AnalysisView.body`, restructure `filterSection` so:

- Period picker remains at top (lines 112-117)
- `FilterPillRow` moves to render after the insight hook and AI section

### 3. Demote "AI Unavailable" Message

In [AIInsightSection.swift](Heatlab/Views/Components/AIInsightSection.swift) line 99-105:

- Current: Shows "AI insights require a physical device" in DEBUG builds
- Change: Make it even smaller/lighter or hide entirely when not useful

### 4. Fix Temperature Formatting

In [ComparisonCard.swift](Heatlab/Views/Components/ComparisonCard.swift) line 78-82 and similar locations:

- Current: `"\(value)°"` produces "99°"
- Change: `"\(value)°\(settings.temperatureUnit.symbol)"` produces "99°F" or "99°C"

Also update the same pattern in:

- [AnalysisView.swift](Heatlab/Views/AnalysisView.swift) line 335-339
- [DashboardView.swift](Heatlab/Views/DashboardView.swift) line 83-87

### 5. Move Comparison Footnote

Move `noPriorPeriodHint` from between stats and chart to after the chart/acclimation section:

- Current location: line 60-62 in AnalysisView
- New wording: "Comparisons unlock after 2 weeks of data." (per feedback)

---

## Files to Modify

- [AnalysisView.swift](Heatlab/Views/AnalysisView.swift) - reorder sections, add insight hook
- [AIInsightSection.swift](Heatlab/Views/Components/AIInsightSection.swift) - demote unavailable message
- [ComparisonCard.swift](Heatlab/Views/Components/ComparisonCard.swift) - temperature formatting
- Potentially create new `InsightHookView.swift` component