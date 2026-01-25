# PRD: Heatlab Monetization & App Store Launch

## Context
- Linear issue: HEA-5 "Productize the app"
- Target: App Store launch with freemium model

## Problem Statement
Heatlab is feature-complete for personal use but needs monetization infrastructure and App Store compliance before public launch. The app must implement a free tier (7-day history) vs Pro tier ($4.99/mo or $39.99/yr) with StoreKit 2, meet all HealthKit and App Store guidelines, and pass review on first submission.

---

## Tier Structure

| Feature | Free | Pro |
|---------|------|-----|
| Workout tracking | ✓ | ✓ |
| Real-time heart rate | ✓ | ✓ |
| Session history | 7 days | Unlimited |
| Baseline comparison | ✓ | ✓ |
| Trend analysis | Last 7 days | Full history |
| Period comparisons (WoW/MoM/YoY) | — | ✓ |
| AI insights | — | ✓ |
| CloudKit sync | ✓ | ✓ |

---

## Requirements

### Must Have (P0)

**StoreKit 2 Implementation**
- [ ] Subscription product configuration in App Store Connect
  - `com.heatlab.pro.monthly` — $4.99/month
  - `com.heatlab.pro.annual` — $39.99/year
- [ ] StoreKit configuration file (`.storekit`) for local testing
- [ ] `SubscriptionManager` service with:
  - Product loading via `Product.products(for:)`
  - Purchase flow with `product.purchase()`
  - Entitlement checking via `Transaction.currentEntitlements`
  - Transaction listener via `Transaction.updates`
  - Restore purchases via `AppStore.sync()`
- [ ] Subscription status sync between iOS and watchOS (App Groups or entitlement check on both)

**Paywall UI**
- [ ] Paywall screen showing both plans with clear pricing
- [ ] Display: price, billing frequency, trial terms (if any), auto-renewal disclosure
- [ ] Cancellation instructions visible near purchase buttons
- [ ] Restore Purchases button (on paywall AND in Settings)
- [ ] Terms of Use and Privacy Policy links

**Free Tier Enforcement**
- [ ] `SessionRepository` filters to 7-day window for free users
- [ ] `TrendCalculator` limits to 7-day data for free users
- [ ] `AnalysisCalculator` period comparisons gated behind Pro
- [ ] AI insights gated behind Pro
- [ ] Soft upgrade prompts when user hits free tier limits

**Privacy & Compliance**
- [ ] `PrivacyInfo.xcprivacy` manifest with required reason APIs
- [ ] HealthKit usage descriptions in Info.plist (clear, plain language)
- [ ] Privacy policy URL (web-hosted, linked in app and App Store)
- [ ] App Privacy nutrition labels completed in App Store Connect

**App Store Metadata**
- [ ] App icon (1024x1024)
- [ ] Screenshots for iPhone (6.7", 6.5", 5.5") and Apple Watch
- [ ] App description, subtitle, keywords
- [ ] Support URL
- [ ] Age rating questionnaire
- [ ] Review notes with instructions to test Pro features

### Nice to Have (P1)
- [ ] Introductory offer (7-day free trial for Pro)
- [ ] Promotional pricing for launch
- [ ] In-app rating prompt after 5th workout
- [ ] Preview video for App Store listing

---

## Acceptance Criteria

**Subscription Flow**
- [ ] User can view both subscription options with correct pricing
- [ ] User can complete purchase via Apple Pay / App Store
- [ ] Pro features unlock immediately after successful purchase
- [ ] Subscription status persists across app launches
- [ ] Restore purchases works on fresh install with prior subscription
- [ ] Subscription status syncs to watchOS within 30 seconds

**Free Tier Limits**
- [ ] Free user sees only sessions from last 7 days in history
- [ ] Free user cannot access period comparisons (WoW/MoM/YoY)
- [ ] Free user cannot access AI insights
- [ ] Upgrade prompt appears when free user tries to access gated feature

**App Store Compliance**
- [ ] App builds with iOS 26 SDK and watchOS 26 SDK
- [ ] No crashes on physical devices (iPhone + Apple Watch)
- [ ] All HealthKit permissions have clear purpose strings
- [ ] Privacy manifest includes all required reason APIs
- [ ] Restore Purchases button visible and functional

---

## Technical Notes

### Existing Architecture (from SUMMARY.md)
- **Data layer**: SwiftData with CloudKit sync (iOS), local SwiftData (watchOS)
- **Services**: `SessionRepository`, `BaselineEngine`, `TrendCalculator`, `AnalysisCalculator`
- **Sync**: Outbox pattern Watch→iPhone, CloudKit for multi-device iOS

### New Components Needed
1. **SubscriptionManager** (Shared/) — StoreKit 2 service
2. **PaywallView** (Heatlab/Views/) — SwiftUI subscription UI
3. **ProGate** view modifier — conditionally shows upgrade prompt or content
4. **SubscriptionStatus** model — tracks current entitlement state

### Data Flow for Entitlements
```
App launch → SubscriptionManager.checkEntitlements()
  → Transaction.currentEntitlements (async sequence)
  → Update @Published isPro state
  → Views react to isPro via environment
```

### watchOS Subscription Sync
- watchOS can check `Transaction.currentEntitlements` directly
- Same App Store account = same entitlements
- Consider caching status in App Groups for faster launch

### Key Constraints
- No health data in iCloud (HealthKit or local only)
- Subscription must provide "ongoing value" per guideline 3.1.2
- All prices must match exactly between App Store Connect and in-app display

---

## Prompt for Coding Agent

```
Implement StoreKit 2 subscription support for Heatlab iOS + watchOS app.

## Context
- Existing SwiftData + CloudKit architecture (see SUMMARY.md)
- Two subscription tiers: Monthly ($4.99) and Annual ($39.99)
- Product IDs: com.heatlab.pro.monthly, com.heatlab.pro.annual

## Tasks

1. Create SubscriptionManager in Shared/Services/:
   - Load products via Product.products(for:)
   - Handle purchases with product.purchase()
   - Check entitlements via Transaction.currentEntitlements
   - Listen for updates via Transaction.updates
   - Restore purchases via AppStore.sync()
   - Expose @Published isPro: Bool

2. Create PaywallView in Heatlab/Views/:
   - Display both subscription options with pricing
   - Include required disclosures (price, duration, auto-renewal, cancellation)
   - Restore Purchases button
   - Links to Terms and Privacy Policy
   - Use StoreKit 2 views (SubscriptionStoreView) if appropriate

3. Add ProGate view modifier:
   - If user is Pro, show child content
   - If not Pro, show upgrade prompt with PaywallView sheet

4. Update SessionRepository:
   - Add isPro parameter to fetch methods
   - Filter to 7-day window when isPro == false

5. Update AnalysisCalculator:
   - Gate period comparisons (WoW/MoM/YoY) behind Pro

6. Add Settings > Subscription section:
   - Show current status
   - Restore Purchases button
   - Manage Subscription link (opens App Store)

7. watchOS subscription check:
   - Add SubscriptionManager to HeatlabWatch
   - Check entitlements on app launch
   - UI should reflect Pro status

## Requirements
- Use async/await throughout
- No server-side receipt validation needed (StoreKit 2 handles locally)
- Test with StoreKit configuration file before App Store Connect
```

---

## Pre-Submission Checklist

### Build
- [ ] Xcode 26 / iOS 26 SDK / watchOS 26 SDK
- [ ] Tested on physical iPhone and Apple Watch
- [ ] No crashes or placeholder content

### App Store Connect
- [ ] Subscription products created and approved
- [ ] Metadata complete (icon, screenshots, description)
- [ ] Privacy labels filled out
- [ ] Review notes with Pro test instructions

### Compliance
- [ ] Privacy manifest included
- [ ] Privacy policy URL live
- [ ] HealthKit purpose strings clear
- [ ] Restore Purchases visible

### Key Deadlines
| Date | Requirement |
|------|-------------|
| Jan 31, 2026 | Age rating questionnaire |
| April 2026 | iOS 26 SDK required |

---

*Generated: 2026-01-24*
