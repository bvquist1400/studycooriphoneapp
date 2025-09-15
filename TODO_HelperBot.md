# StudyCoor – Helper Bot TODO (Simpler Fixes)

Owner: Helper Bot

Purpose: Quick wins and cleanup tasks that unblock Codex and improve baseline quality.

## Phase 0 — Repo Hygiene ✅ COMPLETE

- [x] Add a project `.gitignore` (Xcode, SwiftPM, macOS) and remove tracked junk:
  - [x] Remove `*.xcuserdatad`, `*.xcuserstate`, and `.DS_Store` from version control.
  - [x] Keep `StudyCoor.xcodeproj/project.pbxproj` and `contents.xcworkspacedata`; exclude `xcuserdata/`.
- [x] Add a minimal `README.md` with: overview, requirements (Xcode, iOS target), and build/run instructions.

Acceptance: No user‑local files (e.g., `xcuserdata/`, `.DS_Store`) are tracked by git; README renders in IDE. The working tree may have intentional staged/uncommitted changes. ✅

**Implementation Notes:**
- Added comprehensive `.gitignore` with iOS/Xcode/macOS exclusions
- Local `xcuserdata/` files may still exist on disk but are ignored and not tracked
- Added `README.md` with project overview, requirements (Xcode 15.0+, iOS 17.0+), and build instructions
- Git repository initialized and ready for version control

Optional:
- [ ] Commit hygiene changes so `git status` is clean for a baseline checkpoint

## Phase 1 — Submission Prep (Content)

- [ ] Replace placeholder links in `Views/SettingsView.swift` with real Support and Privacy Policy URLs (values to be provided by owner).
- [x] Add `PrivacyInfo.xcprivacy` file stub (no collection, no tracking) for Codex to finalize.
  - Path: `StudyCoor/PrivacyInfo.xcprivacy` ✅
  - Added proper plist format (not JSON) with NSPrivacyTracking=false and empty arrays

Acceptance: Privacy manifest present in project directory ✅. Support/Privacy URLs pending owner input.

## Phase 2 — UI Small Polish

- [x] Extract the repeated gradient/background into a reusable view modifier (e.g., `View+Backgrounds.swift` with `func studyCoorBackground()`) and apply to: Calculator, History, Study/Subject Detail, Paywall, Calculation Detail.
  - ✅ Created `Views/View+Backgrounds.swift` with `StudyCoorBackgroundModifier`
  - ✅ Applied `.studyCoorBackground()` to all specified views
  - ✅ Removed all duplicate `pageBackground` implementations
- [x] Input validation (Calculator and Bottle inputs):
  - ✅ Clamp numeric `TextField`s to non‑negative values in `onChange` handlers.
  - ✅ Fields: `dispensed`, `returned`, `missed`, `extra`, `holdDays`, bottle `dispensed`/`returned`.
  - ✅ Preserve empty string while editing; coerce invalid strings to last valid value or `"0"`.
  - ✅ When `partials == false`, snap `dispensed`, `returned`, `missed`, `extra` to whole numbers.
  - ✅ Add `.submitLabel(.done)` where appropriate and ensure tap‑to‑dismiss keyboard.
  - ✅ Created `Views/View+NumericValidation.swift` with `.numericValidation()` and `.integerValidation()` modifiers
  - ✅ Applied validation to all Calculator TextFields, bottle inputs, and PRN target fields
- [ ] Orientation: if product decision is portrait‑only on iPhone, update build settings:
  - Set `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait`.
  - Keep iPad orientations unchanged.
- [x] "How we calculated this" setting: show a simple explanatory footer under the results when ON (full detailed explainer is owned by Codex Phase 2).
  - ✅ Setting already properly wired via `@AppStorage("showHowWeCalculated")`
  - ✅ Explanatory footer appears in CalculatorView when toggle is ON
  - ✅ Verified toggle in SettingsView controls display correctly

Acceptance: Background duplication removed ✅; fields disallow negatives ✅; keyboard dismissal works ✅; optional footer appears when setting is ON ✅.

**Implementation Notes:**
- Background extraction complete: centralized gradient logic in reusable modifier
- All views (CalculatorView, HistoryView, StudyDetailView, SubjectDetailView, CalculationDetailView, SettingsView, StudiesView) now use `.studyCoorBackground()`
- Removed ~100 lines of duplicate gradient code across 7 view files
- Input validation complete: numeric fields clamp to non-negative values and respect `partials` setting
- Applied validation to 12+ TextField locations across CalculatorView, StudyDetailView, and creation sheets
- "How we calculated" feature already implemented and working correctly

## Phase 3 — Tests Light

- [x] Convert `StudyCoorTests/StudyCoorTests.swift` from `Testing` to XCTest (replace with an empty XCTestCase scaffold) or remove if unused.
  - ✅ Already converted to XCTest with placeholder test
- [x] Add a small unit test for partial rounding behavior with `partialDoseEnabled` true/false.
  - ✅ Added `testPartialRoundingBehavior()` in `ComplianceEngineTests.swift`
  - ✅ Test verifies decimal preservation vs rounding behavior
  - ✅ Demonstrates partials=true preserves 10.5, partials=false rounds to 11.0

Acceptance: Test target compiles and runs; new test passes ✅.

**Implementation Notes:**
- Test framework already properly converted to XCTest
- Added comprehensive test covering the core partial rounding logic in ComplianceEngine
- Test validates both `partialDoseEnabled: true` and `partialDoseEnabled: false` scenarios

## Notes for Coordination

- App Icon assets: prepare `AppIcon-1024.png` (1024×1024 PNG, no rounded corners). Codex will wire it with Single‑Size App Icon or full catalog.
- Provide final Support and Privacy URLs to both files and App Store Connect.
