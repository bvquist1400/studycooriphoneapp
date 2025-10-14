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
  - Pending: extend engine tests for additional edge scenarios (PRN, clamps)

## 📋 Upcoming Major Tasks

- **Explainability View & Engine Tests**
  - Detailed “How we calculated this” breakdown
  - Add scenarios for PRN, edge-day overrides, compliance clamps

- **Reporting & Export Enhancements**
  - CSV export per calculation + selection with UIActivityViewController
  - PDF summary export (inputs, outputs, flags)
  - Subject trends using Swift Charts

- **Polish & Compliance**
  - Accessibility sweep (VoiceOver, Dynamic Type, contrast)
  - Localize strings via `.xcstrings`
  - Confirm telemetry/analytics stance (likely none)

## 📌 Nice-to-Haves / Backlog

- Archive/TestFlight validation checklist
- Automated UI smoke tests once StoreKit gating stabilizes
- Additional calculator QA scenarios (PRN, edge-day overrides, multi-drug)
