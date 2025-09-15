# StudyCoor – Codex TODO (Complex Tasks)

Owner: Codex (you)

Purpose: Handle App Store–blocking work, deeper architecture/features, and project configuration changes. Organized in phases to ship TestFlight quickly, then iterate.

## Phase 0 — Build & Project Hygiene

- [ ] Set iOS deployment target to 17.0+ for all targets (SwiftData requirement) in `StudyCoor.xcodeproj`.
- [ ] Set proper bundle identifiers (reversed‑DNS) for app and test targets; assign Development Team and verify signing.
- [ ] Migrate App Icon to Apple’s “Single‑Size App Icon” (1024×1024) or provide full catalog with filenames; ensure it validates for submission.
- [ ] Audit Info settings: category, orientations (decide on iPhone portrait‑only or keep landscape), marketing/build versioning.

Acceptance: Project builds for device; Archive succeeds; icons validate in Xcode’s App Icon check; signing shows no warnings.

## Phase 1 — App Store Blockers

- [ ] Replace `@AppStorage("proUnlocked")` with StoreKit 2 subscriptions (monthly/yearly).
  - [ ] Fetch products via `Product.products(for:)`.
  - [ ] Purchase flow, transaction verification, entitlement caching.
  - [ ] Replace paywall button actions with real purchases; keep graceful error UI and retry.
  - [ ] Implement “Restore Purchases” using `Transaction.currentEntitlements` and `AppStore.sync()`.
  - [ ] Gate Studies/Subjects features on entitlement (and reflect state across app start).
- [ ] Add `PrivacyInfo.xcprivacy` manifest declaring data practices (likely no data collection; no tracking).
- [ ] Replace Settings support/privacy links with final URLs and confirm they load in production builds.

Acceptance: TestFlight build passes App Store Connect privacy checks; paywall purchases/restore work on a device sandbox account; entitlement gating robust to offline.

## Phase 2 — Calculation Explainability & Tests

- [ ] Implement an explainability view for results ("How we calculated this").
  - [ ] Show period days (inclusive), effective days (minus holds), base expected per day, edge‑day overrides, bottle totals, missed/extra math, rounding behavior.
  - [ ] Toggle visibility via `@AppStorage("showHowWeCalculated")`.
- [ ] Add engine tests:
  - [ ] Partial dose rounding ON vs OFF.
  - [ ] PRN with/without target, varying durations.
  - [ ] Edge‑day overrides on long spans and zero/one/two‑day edges.
  - [ ] Compliance clamping at 0% and 150%.
- [ ] Unify to XCTest across the unit test target (remove/replace `Testing`-based placeholder file).

Acceptance: New tests pass locally; explainability view matches engine outputs for representative cases.

## Phase 3 — Reporting & Export

- [ ] CSV export for a single calculation and for History selection; present `UIActivityViewController`.
- [ ] PDF summary export (SwiftUI → PDF) with branding, inputs/outputs, bottles, flags.
- [ ] Subject trends in `SubjectDetailView` using Swift Charts: rolling average, best/worst markers.

Acceptance: Shares open with valid CSV/PDF; charts render and are performant on device.

## Phase 4 — Polishing & Compliance

- [ ] Accessibility pass (VoiceOver labels on icons, Dynamic Type, contrast).
- [ ] String catalog localization (`.xcstrings`) with English base; prepare for future locales.
- [ ] Telemetry decision (likely none); ensure no SDKs implying tracking.

Dependencies/Inputs Needed:

- Bundle ID prefix (e.g., `com.yourcompany.studycoor`).
- Final support and privacy policy URLs.
- App icon (1024×1024 PNG, corner radius none) if using Single‑Size icon.

