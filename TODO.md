# StudyCoor Roadmap

Single source of truth for what’s done and what’s next. Keep this file up to date; we deleted the legacy `TODO_HelperBot.md` and `TODO_Codex.md`.

## ✅ Baseline Complete

- Repo hygiene (gitignore, README, Xcode junk removed)
- App icon moved to single-size catalog; bundle IDs, deployment targets, signing, orientations, and marketing version aligned
- Privacy manifest added and wired; settings links point at production URLs
- UI polish: reusable gradients, numeric validation, portrait-only iPhone, compliance explainer toggle, centered navigation styling
- Tests: XCTest target converted; partial dose rounding covered
- History exports now produce real `.txt`/`.csv` files; share sheet includes plain text; subject chips show average compliance
- StoreKit 2 entitlement flow with retry-aware gating and unit coverage

## 🚧 Next Immediate Work

- **Explainability polish follow-ups**
  - Add friendly flag copy to History list cells (chips) and summary exports ✅
  - Center compliance/quick breakdown presentation in calculator card ✅
  - Surface friendly flag descriptions across detail, PDF, CSV ✅
  - Extend engine tests for additional edge scenarios (PRN, clamps) ✅

## 📋 Upcoming Major Tasks

- **Explainability View & Engine Tests**
  - Detailed “How we calculated this” breakdown ✅
  - Add scenarios for PRN, edge-day overrides, compliance clamps ✅

- **Reporting & Export Enhancements**
  - CSV export per calculation + selection with UIActivityViewController ✅
  - PDF summary export (inputs, outputs, flags) ✅
  - Subject trends using Swift Charts ✅

- **Polish & Compliance**
  - Accessibility sweep (VoiceOver, Dynamic Type, contrast)
    - History rows and subject trend summaries accessible via VoiceOver ✅
  - Localize strings via `.xcstrings` (Subject detail & history views scaffolded) 🚧
  - Confirm telemetry/analytics stance (likely none)
  - Ensure subjects scoped per study (unique UUID linkage applied) ✅

## 🚀 App Store Launch Prep (HIGH PRIORITY)

**Goal: Submit to App Store within 1-2 weeks**

### ✅ Documentation Complete
- Production readiness review (PRODUCTION_READINESS_REVIEW.md) ✅
- Privacy policy (PRIVACY_POLICY.md) ✅
- Terms of service (TERMS_OF_SERVICE.md) ✅
- App Store metadata and description (APP_STORE_METADATA.md) ✅
- Accessibility audit and checklist (ACCESSIBILITY_AUDIT.md) ✅

### 🔲 Pre-Submission Critical Path

#### Phase 1: Accessibility Compliance (2-3 days)
- [ ] Add VoiceOver labels to CalculatorView (all inputs, buttons, results)
- [ ] Test Dynamic Type support at largest sizes
- [ ] Verify color contrast ratios (WCAG AA) for compliance indicators
- [ ] Fix any layout issues with accessibility settings enabled
- [ ] Run full VoiceOver test script (see ACCESSIBILITY_AUDIT.md)

#### Phase 2: Hosting & URLs (1 day)
- [ ] Host privacy policy on public URL (GitHub Pages or custom domain)
- [ ] Host terms of service on public URL
- [ ] Update SettingsView with live privacy/ToS URLs
- [ ] Add support email or website URL

#### Phase 3: App Store Connect Setup (1 day)
- [ ] Create App Store Connect listing
- [ ] Configure pro.monthly subscription product
- [ ] Configure pro.yearly subscription product
- [ ] Set pricing tiers
- [ ] Upload app icon (1024x1024)
- [ ] Add app description and keywords from APP_STORE_METADATA.md

#### Phase 4: Screenshots & Assets (1-2 days)
- [ ] Generate 6.7" iPhone screenshots (6 required)
- [ ] Generate 6.5" iPhone screenshots (6 required)
- [ ] Generate 5.5" iPhone screenshots (6 required)
- [ ] Optional: iPad screenshots
- [ ] Optional: App preview video (15-30 seconds)

#### Phase 5: TestFlight Beta (2-3 days)
- [ ] Archive app for distribution
- [ ] Upload to App Store Connect
- [ ] Submit for TestFlight External Testing
- [ ] Invite 5-10 external testers
- [ ] Collect feedback
- [ ] Fix critical issues

#### Phase 6: Final QA & Submission (1 day)
- [ ] Test on physical device (iOS 26.2)
- [ ] Verify all export functions (CSV, PDF)
- [ ] Test subscription flow in production StoreKit
- [ ] Complete App Review Notes
- [ ] Submit for App Store Review

## 📌 Nice-to-Haves / Backlog

- Archive/TestFlight validation checklist
- Automated UI smoke tests once StoreKit gating stabilizes
- Additional calculator QA scenarios (PRN, edge-day overrides, multi-drug)
