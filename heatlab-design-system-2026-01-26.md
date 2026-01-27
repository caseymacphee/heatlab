# HeatLab Design System

**HEA-6: Re-Style Watch and iOS App**
*Created: 2026-01-26*

---

## Overview

This design system implements "Style Guide C: Yoga Hybrid" — blending Function Health's premium calm with Marine Layer's warmth. The core philosophy: **studio calm, data clarity**.

### Core Rules

1. **One accent color** — everything else neutral or semantic
2. **Whitespace is a feature** — if a screen feels cramped, it's wrong
3. **iOS-native first** — SF Pro + platform patterns do the heavy lifting
4. **Semantic color only** — don't color things unless it means something

---

## 1. Design Tokens

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#F6F1E8` | Primary app background (warm cream) |
| `surface` | `#FFFFFF` | Cards, sheets, elevated content |
| `surface2` | `#EFE6DA` | Secondary surfaces, grouped backgrounds |
| `text` | `#1A1A18` | Primary text (near-black, warm) |
| `muted` | `#6A645B` | Secondary text, labels, captions |
| `accent` | `#C96A4A` | Heated clay — primary brand accent, CTAs |
| `cool` | `#4F8FA3` | Cool rinse — recovery states, cool-down |
| `good` | `#6E907B` | Positive/success states, "in range" |
| `grid` | `#E6DED2` | Dividers, chart gridlines, subtle borders |

### Watch-Specific Colors

The Watch uses a dark theme. These tokens map to Watch context:

| Token | Light (iOS) | Dark (Watch) |
|-------|-------------|--------------|
| `background` | `#F6F1E8` | `#000000` (true black for OLED) |
| `surface` | `#FFFFFF` | `#1C1C1E` (elevated dark) |
| `surface2` | `#EFE6DA` | `#2C2C2E` |
| `text` | `#1A1A18` | `#FFFFFF` |
| `muted` | `#6A645B` | `#98989D` |
| `accent` | `#C96A4A` | `#C96A4A` (same) |
| `cool` | `#4F8FA3` | `#64D2FF` (brighter for dark bg) |
| `good` | `#6E907B` | `#30D158` (system green for visibility) |
| `grid` | `#E6DED2` | `#38383A` |

### Spacing Scale

```
4pt  — micro (icon padding)
8pt  — small (between related elements)
12pt — medium (list item padding)
16pt — standard (card padding tight)
20pt — comfortable (card padding normal)
24pt — section gap
32pt — major section break
```

### Corner Radius

| Element | Radius |
|---------|--------|
| Cards | 14pt |
| Buttons | 12pt (or full pill for primary CTAs) |
| Chips/Tags | 8pt |
| Input fields | 10pt |
| Small badges | 6pt |

### Typography

Use iOS system text styles exclusively. Don't invent sizes.

| Style | iOS Text Style | Weight | Usage |
|-------|---------------|--------|-------|
| Large Title | `.largeTitle` | Bold | Screen headers |
| Title 1 | `.title` | Semibold | Card headers |
| Title 2 | `.title2` | Semibold | Section headers |
| Title 3 | `.title3` | Semibold | Subsection headers |
| Headline | `.headline` | Semibold | Emphasized body |
| Body | `.body` | Regular | Primary content |
| Callout | `.callout` | Regular | Secondary content |
| Subhead | `.subheadline` | Regular | Labels, captions |
| Footnote | `.footnote` | Regular | Tertiary text, timestamps |
| Caption | `.caption` | Regular | Smallest text, badges |

### Chart Styling

| Element | Color |
|---------|-------|
| Default line | `muted` (#6A645B) |
| Highlight/active | `accent` (#C96A4A) |
| Recovery overlay | `cool` (#4F8FA3) |
| Gridlines | `grid` (#E6DED2) |
| Data points | `accent` with 8pt diameter |

---

## 2. Swift Asset Catalog Structure

```
Assets.xcassets/
├── Colors/
│   ├── Background.colorset/
│   │   └── Contents.json (light: #F6F1E8, dark: #000000)
│   ├── Surface.colorset/
│   │   └── Contents.json (light: #FFFFFF, dark: #1C1C1E)
│   ├── Surface2.colorset/
│   │   └── Contents.json (light: #EFE6DA, dark: #2C2C2E)
│   ├── TextPrimary.colorset/
│   │   └── Contents.json (light: #1A1A18, dark: #FFFFFF)
│   ├── TextMuted.colorset/
│   │   └── Contents.json (light: #6A645B, dark: #98989D)
│   ├── Accent.colorset/
│   │   └── Contents.json (any: #C96A4A)
│   ├── Cool.colorset/
│   │   └── Contents.json (light: #4F8FA3, dark: #64D2FF)
│   ├── Good.colorset/
│   │   └── Contents.json (light: #6E907B, dark: #30D158)
│   └── Grid.colorset/
│       └── Contents.json (light: #E6DED2, dark: #38383A)
```

### Sample colorset Contents.json

```json
{
  "colors": [
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.965",
          "green": "0.945",
          "blue": "0.910",
          "alpha": "1.000"
        }
      },
      "idiom": "universal",
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "light"
        }
      ]
    },
    {
      "color": {
        "color-space": "srgb",
        "components": {
          "red": "0.000",
          "green": "0.000",
          "blue": "0.000",
          "alpha": "1.000"
        }
      },
      "idiom": "universal",
      "appearances": [
        {
          "appearance": "luminosity",
          "value": "dark"
        }
      ]
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

### SwiftUI Color Extension

```swift
import SwiftUI

extension Color {
    static let hlBackground = Color("Background")
    static let hlSurface = Color("Surface")
    static let hlSurface2 = Color("Surface2")
    static let hlText = Color("TextPrimary")
    static let hlMuted = Color("TextMuted")
    static let hlAccent = Color("Accent")
    static let hlCool = Color("Cool")
    static let hlGood = Color("Good")
    static let hlGrid = Color("Grid")
}
```

---

## 3. Component Specifications

### 3.1 Button

**Primary Button (CTA)**
- Background: `accent` (#C96A4A)
- Text: `#FFFFFF`, `.headline` weight
- Corner radius: Full pill (height / 2)
- Height: 50pt (iOS), 44pt (Watch)
- Horizontal padding: 24pt
- Shadow: None

**Secondary Button**
- Background: `surface` (#FFFFFF)
- Border: 1pt `grid`
- Text: `text`, `.headline` weight
- Same dimensions as primary

**Tertiary/Text Button**
- Background: None
- Text: `accent`, `.subheadline` weight
- No border

**States:**
- Pressed: 0.7 opacity
- Disabled: 0.4 opacity

---

### 3.2 Card

**Standard Card**
- Background: `surface` (#FFFFFF)
- Corner radius: 14pt
- Padding: 16pt (tight) or 20pt (normal)
- Shadow: None — use background color contrast
- Border: None

**Insight Card (highlighted)**
- Background: `good` at 15% opacity (#6E907B/15)
- Corner radius: 14pt
- Left accent: 3pt bar in `good`
- Padding: 16pt

**Alert Card**
- Background: `accent` at 15% opacity (#C96A4A/15)
- Left accent: 3pt bar in `accent`

---

### 3.3 Stat Tile

Used for displaying metrics (Duration, Temperature, Heart Rate, Calories).

**Layout:**
```
┌─────────────────┐
│ 🕐 Duration     │  ← icon + label in `muted`, .subheadline
│ 0:45            │  ← value in `text`, .title weight
└─────────────────┘
```

- Icon: SF Symbol, 16pt, `muted`
- Label: `.subheadline`, `muted`
- Value: `.title`, `text`
- Spacing: 4pt between label and value
- Grid: 2-up or 4-up layout with 12pt gaps

---

### 3.4 Chip / Tag

**Default State**
- Background: `surface2` (#EFE6DA)
- Text: `text`, `.subheadline`
- Corner radius: 8pt
- Padding: 8pt horizontal, 6pt vertical

**Selected State**
- Background: `accent` (#C96A4A)
- Text: `#FFFFFF`

**Temperature Chip (in lists)**
- Background: `accent` at 20% opacity
- Text: `accent`, `.caption` weight
- Corner radius: 6pt

---

### 3.5 List Row

**Session List Row**
```
┌────────────────────────────────────────────────────┐
│ Heated Vinyasa                              95°F → │
│ Wed 11:28 AM · 45 min · 142 bpm                    │
└────────────────────────────────────────────────────┘
```

- Background: `surface`
- Title: `.headline`, `text`
- Subtitle: `.subheadline`, `muted`
- Accessory (temp chip): Right-aligned
- Chevron: `muted`, 12pt
- Divider: `grid`, 0.5pt, inset 16pt
- Row height: 72pt minimum
- Padding: 16pt horizontal

---

### 3.6 Empty State

**Layout:**
```
        ︵
   (wave icon)

   No sessions yet

   Start tracking your practice
   to see insights here.

   [Start Session]
```

- Icon: Wave motif (from logo), 48pt, `muted`
- Title: `.title3`, `text`
- Body: `.body`, `muted`, centered
- Button: Primary CTA
- Vertical spacing: 16pt between elements

---

### 3.7 Chart Style

**Line Chart**
- Line weight: 2pt
- Line color: `muted` (default), `accent` (highlighted)
- Data points: 8pt circles, filled `accent`
- Grid: `grid` at 0.5pt, dashed
- Axis labels: `.caption`, `muted`
- No background fill under line

**Progress Ring (Watch)**
- Track: `surface2` (iOS) or `#2C2C2E` (Watch)
- Progress: `accent`
- Stroke width: 8pt (Watch), 12pt (iOS)
- Center text: `.title`, `text`

---

### 3.8 Segmented Control

- Background: `surface2` (#EFE6DA)
- Selected segment: `surface` (#FFFFFF)
- Text: `.subheadline`
- Selected text color: `text`
- Unselected text color: `muted`
- Corner radius: 8pt (container), 6pt (segment)
- Height: 32pt

---

### 3.9 Sheet / Modal

- Background: `surface`
- Corner radius: 20pt (top corners only)
- Handle: 36pt × 5pt, `grid`, centered, 8pt from top
- Content padding: 20pt

---

### 3.10 Toggle / Switch

- Track (off): `grid`
- Track (on): `accent`
- Thumb: `#FFFFFF`
- Size: iOS system default

---

## 4. Screen Templates

### 4.1 Home Screen

**Before:** White background, bright orange accents everywhere, cramped layout

**After:**
```
┌─────────────────────────────────────────────┐
│                    Home                      │ ← .largeTitle, centered
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ ↓ 13 Workouts to Import                 │ │ ← Import card: accent/15 bg
│ │   From Apple Health                   → │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ✦ Insight                               │ │ ← Insight card: good/15 bg
│ │   Avg HR 61 bpm across 7 sessions    →  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Past 7 Days                             │ │ ← Stats card: surface bg
│ │                                         │ │
│ │  Sessions    Avg Temp                   │ │
│ │  7           96°F                       │ │
│ │                                         │ │
│ │  Avg HR      Calories                   │ │
│ │  61 bpm      --                         │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Recent Sessions               See All → │ │
│ │─────────────────────────────────────────│ │
│ │ Session                          95°F → │ │
│ │ Today 7:45 AM · 0 min · 63 bpm         │ │
│ │─────────────────────────────────────────│ │
│ │ Power                            95°F → │ │
│ │ Yesterday · 0 min · -- bpm             │ │
│ └─────────────────────────────────────────┘ │
│                                             │
├─────────────────────────────────────────────┤
│  ⌂        📊        ≡        ⚙            │ ← Tab bar
│ Home    Analysis  Sessions  Settings       │
└─────────────────────────────────────────────┘

Background: #F6F1E8 (warm cream)
Cards: #FFFFFF
Tab bar active: accent (#C96A4A)
Tab bar inactive: muted
```

**Key Changes:**
- Background shifts from white to warm cream
- Cards have no shadows, defined by color contrast
- Temperature chips use accent/20 background
- Only the active tab and actionable elements use accent
- Generous 16pt gaps between cards

---

### 4.2 Session Detail Screen

**Before:** Flat layout, orange accent overused, green insight card works but could be refined

**After:**
```
┌─────────────────────────────────────────────┐
│ ←        Session                     Edit   │
├─────────────────────────────────────────────┤
│                                             │
│ Power                                       │ ← .largeTitle
│ Saturday, January 24 · 7:20 PM              │ ← .subheadline, muted
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │  🕐 Duration      🌡 Temperature         │ │
│ │  0:45             95°F                   │ │
│ │                                          │ │
│ │  ♥ Avg HR         🔥 Calories            │ │
│ │  142 bpm          320 kcal               │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ ┃ vs Your Baseline                      │ │ ← green left bar
│ │ ┃ ↓ Easier session, 15% below average   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Perceived Effort                            │ ← .headline
│ Moderate                                    │ ← .body, muted
│                                             │
│ Notes                                       │
│ Great flow today, felt strong in warriors. │ │
│                                             │
│ ─────────────────────────────────────────── │ ← grid divider
│                                             │
│ Heart Rate                                  │
│ ┌─────────────────────────────────────────┐ │
│ │         ·  ·                             │ │ ← minimal line chart
│ │    ·  ·      ·  ·                        │ │
│ │  ·              ·  ·                     │ │
│ │ Start              End                   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

**Key Changes:**
- Stats in a single card, 2×2 grid
- Insight card uses subtle green tint + left accent bar
- Chart is minimal — no heavy backgrounds
- Section headers use `.headline`, not bold colors
- Generous vertical rhythm

---

### 4.3 Analysis/Trends Screen

**Before:** Segmented control in bright orange, chart works but could be cleaner

**After:**
```
┌─────────────────────────────────────────────┐
│                  Analysis                    │
├─────────────────────────────────────────────┤
│                                             │
│ ┌──────┬──────┬──────┬──────┐               │
│ │  7D  │  1M  │  3M  │  1Y  │               │ ← Segmented control
│ └──────┴──────┴──────┴──────┘               │   Selected: surface bg
│                                             │   Container: surface2 bg
│ ┌────────────┐  ┌────────────┐              │
│ │🌡 Temperature│ │✦ Class    ▼│              │ ← Filter chips
│ └────────────┘  └────────────┘              │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Past 7D: 7 sessions                     │ │
│ │ Avg HR 61 bpm (60–63)                   │ │
│ │                                         │ │
│ │ Sessions  Avg Temp  Avg HR   HR Range   │ │
│ │ 7         96°F      61 bpm   60–63      │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Heart Rate                          📈  │ │ ← expand icon in muted
│ │                                         │ │
│ │     70 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │ │
│ │         ●                         ●     │ │
│ │     65 ─ ● ─ ● ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │ │
│ │           ●                             │ │
│ │     60 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │ │
│ │                                         │ │
│ │    1/19  1/20  1/21  1/22  ...  1/25   │ │
│ │                                         │ │
│ │                       🌡 Temp Colors →  │ │ ← tertiary link
│ └─────────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

**Key Changes:**
- Segmented control uses neutral colors, not accent
- Chart data points in accent, line in muted
- Grid lines are subtle (grid color, dashed)
- Tertiary actions use accent text only
- Stats summary is scannable, not dense

---

## 5. Watch Screen Templates

### 5.1 Watch Home (Start Session)

**Before:** Black bg, flame icon, bright orange button

**After:**
```
┌─────────────────────────────┐
│                        8:04 │
│                             │
│            ︵               │ ← Wave icon (white, from logo)
│                             │
│         HeatLab             │ ← .headline, white
│     Track your Practice     │ ← .caption, muted
│                             │
│  ┌───────────────────────┐  │
│  │   ▶  Start Session    │  │ ← Pill button, accent bg
│  └───────────────────────┘  │
│                             │
└─────────────────────────────┘
```

**Key Changes:**
- Wave icon replaces flame (brand mark, not semantic)
- Button remains accent — it's the only CTA
- Tagline in muted for hierarchy

---

### 5.2 Watch Active Session (Temperature)

**Before:** Orange temperature, circular progress

**After:**
```
┌─────────────────────────────┐
│         Temperature    8:04 │ ← .caption, muted
│                             │
│           95°F              │ ← .largeTitle, accent
│                             │
│            ╭───╮            │ ← Progress ring
│           ╱     ╲           │   Track: #2C2C2E
│          │       │          │   Progress: accent
│           ╲     ╱           │
│            ╰───╯            │
│                             │
│  ─────────────────────────  │ ← grid divider
│  Session Type (Optional)    │
│  ┌──────────┐ ┌──────────┐  │
│  │ Vinyasa  │ │  Power   │  │ ← chips, surface bg
│  └──────────┘ └──────────┘  │
└─────────────────────────────┘
```

**Key Changes:**
- Temperature value in accent (it's the key metric)
- Progress ring uses dark surface for track
- Chips use elevated surface color, not gray

---

### 5.3 Watch Session Complete

**Before:** Red "Session Complete", stats scattered

**After:**
```
┌─────────────────────────────┐
│                        8:04 │
│                             │
│      Session Complete       │ ← .headline, good (green)
│                             │
│   0:45      ♥ 142      🔥 0 │ ← Duration, HR, Cal
│  Duration  Avg BPM    Cal   │ ← .caption, muted
│                             │
│  ─────────────────────────  │
│  Heated Session        [●]  │ ← Toggle row
│  ─────────────────────────  │
│  Temperature                │
│  95°F                       │
│                             │
└─────────────────────────────┘
```

**Key Changes:**
- "Session Complete" in `good` (positive state)
- Stats use semantic icons
- Clean dividers separate sections

---

## 6. Icon Usage Guide

### Brand Mark: Wave

The wave/arc from the logo is the **brand mark**. Use it for:
- App icon (with gradient background)
- Watch home screen (white, simplified) — **use `HeatLabWaveOnly.png` from repo**
- Empty states (muted color, 48pt)
- Loading states
- Marketing materials

**Asset:** `HeatLabWaveOnly.png` — white wave on transparent, ready for dark backgrounds

**Do not** use the wave for:
- Data visualization
- Semantic meaning (it doesn't mean anything specific)

### Semantic Icon: Flame

The flame represents **calories/energy burned**. Use it for:
- Calories stat tile
- Energy expenditure in charts
- Achievement badges related to calories

**Do not** use the flame for:
- General "heat" or "temperature" (use thermometer)
- Brand representation (use wave)
- Default/empty states (use wave)

### Other Semantic Icons (SF Symbols)

| Concept | Symbol | Name |
|---------|--------|------|
| Duration | clock | `clock` |
| Temperature | thermometer | `thermometer.medium` |
| Heart Rate | heart.fill | `heart.fill` |
| Calories | flame.fill | `flame.fill` |
| Session/Practice | figure.yoga | `figure.yoga` |
| Recovery/Cool | drop.fill | `drop.fill` |
| Insight | sparkles | `sparkles` |

---

## 7. Microcopy Guidelines

Align with the "studio calm" voice. Short, observational, not preachy.

**Good:**
- "Heat was higher than usual."
- "Recovery improved this week."
- "7 sessions in the past week."
- "Nice consistency."

**Avoid:**
- "Great job! You crushed it! 🔥"
- "You should try to..."
- "Don't forget to..."
- Exclamation points in data contexts

---

## 8. Implementation Checklist

### Tokens
- [ ] Create color assets in Xcode asset catalog
- [ ] Add Color extension for SwiftUI
- [ ] Define spacing constants
- [ ] Create typography styles (if needed beyond system)

### Components (10 core)
- [ ] Button (primary, secondary, tertiary)
- [ ] Card (standard, insight, alert)
- [ ] Stat Tile
- [ ] Chip/Tag
- [ ] List Row
- [ ] Empty State
- [ ] Chart (line, progress ring)
- [ ] Segmented Control styling
- [ ] Sheet/Modal
- [ ] Toggle (just use accent tint)

### Screens
- [ ] Home — apply new background, card styles
- [ ] Session Detail — restructure stats, refine insight card
- [ ] Analysis — update segmented control, chart styling
- [ ] Sessions List — apply list row style, temp chips
- [ ] Settings — minimal changes, apply background color

### Watch
- [ ] Replace flame with wave on home
- [ ] Update button styling
- [ ] Apply dark token set
- [ ] Update progress ring colors

---

## Appendix: Full Token JSON

```json
{
  "colors": {
    "background": {
      "light": "#F6F1E8",
      "dark": "#000000"
    },
    "surface": {
      "light": "#FFFFFF",
      "dark": "#1C1C1E"
    },
    "surface2": {
      "light": "#EFE6DA",
      "dark": "#2C2C2E"
    },
    "text": {
      "light": "#1A1A18",
      "dark": "#FFFFFF"
    },
    "muted": {
      "light": "#6A645B",
      "dark": "#98989D"
    },
    "accent": "#C96A4A",
    "cool": {
      "light": "#4F8FA3",
      "dark": "#64D2FF"
    },
    "good": {
      "light": "#6E907B",
      "dark": "#30D158"
    },
    "grid": {
      "light": "#E6DED2",
      "dark": "#38383A"
    }
  },
  "spacing": {
    "micro": 4,
    "small": 8,
    "medium": 12,
    "standard": 16,
    "comfortable": 20,
    "section": 24,
    "major": 32
  },
  "radius": {
    "card": 14,
    "button": 12,
    "chip": 8,
    "input": 10,
    "badge": 6
  }
}
```
