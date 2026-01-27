# PRD: HeatLab Design System Implementation

## Context
- Linear issue: [HEA-6 Re-Style Watch and iOS App](https://linear.app/heatlab/issue/HEA-6/re-style-watch-and-ios-app)
- Design spec: `outbox/heatlab-design-system-2026-01-26.md`

## Problem Statement
The current HeatLab app uses a generic fitness app aesthetic with bright orange accents that feel jarring and a flame icon that creates semantic confusion (brand vs calories). We need to implement "Style Guide C: Yoga Hybrid" — a warmer, calmer design system that feels premium and studio-like while maintaining iOS-native patterns.

## Requirements

### Must Have

**1. Design Tokens (Colors)**
Create an Asset Catalog with these colors supporting light/dark variants:

| Token | Light | Dark |
|-------|-------|------|
| Background | #F6F1E8 | #000000 |
| Surface | #FFFFFF | #1C1C1E |
| Surface2 | #EFE6DA | #2C2C2E |
| TextPrimary | #1A1A18 | #FFFFFF |
| TextMuted | #6A645B | #98989D |
| Accent | #C96A4A | #C96A4A |
| Cool | #4F8FA3 | #64D2FF |
| Good | #6E907B | #30D158 |
| Grid | #E6DED2 | #38383A |

Add SwiftUI Color extension:
```swift
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

**2. iOS App Changes**
- Change app background from white to `hlBackground` (#F6F1E8)
- Replace all current orange accent usage with `hlAccent` (#C96A4A)
- Update cards to use `hlSurface` with no shadows, 14pt corner radius
- Update segmented controls to use `hlSurface2` background with `hlSurface` selected state (NOT accent colored)
- Update tab bar: active = `hlAccent`, inactive = `hlMuted`
- Temperature chips in lists: `hlAccent` at 20% opacity background, `hlAccent` text

**3. Watch App Changes**
- Replace flame icon on home screen with `HeatLabWaveOnly.png` (white wave)
- Update progress ring track color to #2C2C2E
- Update chips to use elevated surface color (#1C1C1E) instead of gray
- Keep button accent color (#C96A4A)

**4. Icon Usage**
- Wave icon (`HeatLabWaveOnly.png`): Watch home, empty states only
- Flame icon (`flame.fill`): Calories metric ONLY — do not use for brand/empty states

### Nice to Have
- Insight cards with 3pt left accent bar in `hlGood`
- Alert/import cards with 3pt left accent bar in `hlAccent`
- Microcopy tone audit (remove exclamation points, make observational)

## Acceptance Criteria
- [ ] Asset catalog contains all 9 color tokens with light/dark variants
- [ ] Color extension compiles and is used throughout app
- [ ] iOS app background is warm cream (#F6F1E8), not white
- [ ] No bright orange (#FF6B35 or similar) remains in codebase
- [ ] Watch home screen shows wave icon, not flame
- [ ] Flame icon only appears next to calories/energy data
- [ ] Segmented controls use neutral colors, not accent
- [ ] Cards have 14pt corner radius, no shadows

## Technical Notes

**Spacing constants to add:**
```swift
enum HLSpacing {
    static let micro: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let standard: CGFloat = 16
    static let comfortable: CGFloat = 20
    static let section: CGFloat = 24
    static let major: CGFloat = 32
}

enum HLRadius {
    static let card: CGFloat = 14
    static let button: CGFloat = 12
    static let chip: CGFloat = 8
    static let input: CGFloat = 10
    static let badge: CGFloat = 6
}
```

**Files likely to touch:**
- Asset catalog (new colorsets)
- Color extension file
- Any view using hardcoded colors or `.orange`/`.accentColor`
- Tab bar configuration
- Card components
- Watch home view
- Segmented control styling

---

## Prompt for Coding Agent

```
Implement the HeatLab design system refresh per HEA-6.

DESIGN SPEC: Read outbox/heatlab-design-system-2026-01-26.md for full details.

PRIORITY ORDER:
1. Create color Asset Catalog with 9 tokens (Background, Surface, Surface2, TextPrimary, TextMuted, Accent, Cool, Good, Grid) — each needs light AND dark variants per the spec
2. Add Color extension with hl-prefixed static properties
3. Add spacing and radius constants (HLSpacing, HLRadius enums)
4. Find and replace all hardcoded orange colors with hlAccent
5. Update iOS backgrounds from white to hlBackground
6. Update Watch home: replace flame with HeatLabWaveOnly.png
7. Update segmented controls to use neutral colors (hlSurface2 bg, hlSurface selected)
8. Update cards: 14pt radius, no shadows, hlSurface background

KEY COLOR CHANGE: The main accent shifts from bright orange (~#FF6B35) to heated clay (#C96A4A). This is warmer and more muted.

ICON RULE: Flame = calories only. Wave = brand/empty states.

Don't change functionality, only visual styling. Use iOS system typography — don't create custom font sizes.
```
