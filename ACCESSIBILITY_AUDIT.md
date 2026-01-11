# Accessibility Audit for StudyCoor

**Date:** January 11, 2026
**Version:** 1.1 (Build 1)
**iOS Target:** 17.0+
**Compliance Goal:** WCAG 2.1 Level AA

---

## Executive Summary

This document outlines accessibility requirements and recommendations for StudyCoor to ensure the app is usable by individuals with disabilities, including those using VoiceOver, Dynamic Type, and other assistive technologies.

**Current Status:** Partial implementation
- ✅ Some VoiceOver labels on History and Subject views
- ⚠️ CalculatorView (1,389 lines) needs comprehensive labeling
- ❌ Dynamic Type support not verified
- ❌ Color contrast not audited

---

## 1. VoiceOver Support

### 1.1 Current State

**Completed:**
- History row accessibility (TODO.md confirms)
- Subject trend summaries accessible

**Needs Implementation:**

#### CalculatorView.swift (Priority: High)
- [ ] Study selection chips (Chip component)
- [ ] Subject selection chips
- [ ] Date pickers (Start/End Date)
- [ ] Dosing frequency picker (QD/BID/TID/QID/PRN)
- [ ] Text field inputs:
  - [ ] Dispensed
  - [ ] Returned
  - [ ] Missed
  - [ ] Extra
  - [ ] Hold Days
  - [ ] PRN Target Per Day
- [ ] Toggle switches:
  - [ ] Partial Doses Enabled
  - [ ] Show How We Calculated
- [ ] Bottle input rows (multi-bottle mode)
- [ ] Edge-day override steppers (First Day, Last Day)
- [ ] Calculate button
- [ ] Results display (compliance percentage)
- [ ] Export buttons (CSV, PDF)

#### ExplainabilityView.swift (Priority: Medium)
- [ ] Breakdown cards (Expected/Actual sections)
- [ ] Flag chips (UNDERUSE, OVERUSE, HOLD_DAYS)
- [ ] Step-by-step calculation explanations

#### StudiesView.swift (Priority: Medium)
- [ ] Study list rows
- [ ] New study button
- [ ] Study edit/delete actions

#### SettingsView.swift (Priority: Low)
- [ ] Privacy policy link
- [ ] Terms of service link
- [ ] Support/feedback link
- [ ] Version information

### 1.2 Recommended Accessibility Labels

```swift
// Example implementation for CalculatorView sections

// Study selection
Chip(title: s.name, selected: selectedStudy?.id == s.id) {
    withAnimation { selectStudy(s) }
}
.accessibilityLabel("Study: \(s.name)")
.accessibilityHint(selectedStudy?.id == s.id ? "Selected" : "Double tap to select")

// Dosing frequency picker
Picker("Dosing Frequency", selection: $frequency) {
    ForEach(DosingFrequency.allCases) { freq in
        Text(freq.displayName).tag(freq)
    }
}
.accessibilityLabel("Dosing Frequency")
.accessibilityValue(frequency.displayName)
.accessibilityHint("Select how often medication is taken")

// Compliance result
Text("\(result.compliancePct, specifier: "%.1f")%")
    .accessibilityLabel("Compliance")
    .accessibilityValue("\(result.compliancePct, specifier: "%.1f") percent")
    .accessibilityHint(
        result.compliancePct < 90 ? "Below target - Usage underperformance" :
        result.compliancePct > 110 ? "Above target - Possible overadherence" :
        "Within target range"
    )

// Calculate button
Button("Calculate Compliance") {
    calculate()
}
.accessibilityLabel("Calculate Compliance")
.accessibilityHint("Computes medication compliance based on entered values")

// Text field inputs
TextField("Dispensed", text: $dispensed)
    .accessibilityLabel("Dispensed pills")
    .accessibilityHint("Enter the number of pills given to the subject")
    .keyboardType(.decimalPad)

TextField("Returned", text: $returned)
    .accessibilityLabel("Returned pills")
    .accessibilityHint("Enter the number of pills returned by the subject")
    .keyboardType(.decimalPad)

// Multi-bottle section
Section("Bottles") {
    ForEach(bottles) { bottle in
        BottleRow(bottle: bottle)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Bottle \(bottles.firstIndex(where: { $0.id == bottle.id }) ?? 0 + 1)")
    }
}
.accessibilityLabel("Bottle tracking")
.accessibilityHint("Manage individual bottle dispensing and returns")
```

### 1.3 Accessibility Grouping

For complex UI elements (like calculation result cards), use `.accessibilityElement(children: .combine)` to group related information:

```swift
VStack {
    Text("Compliance")
    Text("\(result.compliancePct, specifier: "%.1f")%")
        .font(.largeTitle)
    Text("Expected: \(result.expectedDoses, specifier: "%.1f")")
    Text("Actual: \(result.actualDoses, specifier: "%.1f")")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Compliance Result")
.accessibilityValue("""
    \(result.compliancePct, specifier: "%.1f") percent. \
    Expected \(result.expectedDoses, specifier: "%.1f") doses. \
    Actual \(result.actualDoses, specifier: "%.1f") doses.
""")
```

---

## 2. Dynamic Type Support

### 2.1 Requirements

All text must scale properly when users enable larger text sizes in iOS Settings > Accessibility > Display & Text Size > Larger Text.

**Test Scenarios:**
1. Enable largest Dynamic Type size (AX5 - Accessibility Extra Extra Extra Large)
2. Navigate through all app screens
3. Verify text doesn't truncate or overflow
4. Ensure buttons remain tappable
5. Check that layouts adapt gracefully

### 2.2 Current State

**Unknown** - No evidence of Dynamic Type testing in current codebase.

### 2.3 Recommended Fixes

#### Use Text Styles Instead of Fixed Sizes

**Before:**
```swift
Text("Compliance")
    .font(.system(size: 24, weight: .bold))
```

**After:**
```swift
Text("Compliance")
    .font(.title)
    .dynamicTypeSize(...DynamicTypeSize.accessibility3) // Optional: cap at readable max
```

#### Adaptive Layouts

Use `.minimumScaleFactor()` for constrained spaces:

```swift
Text("StudyCoor")
    .font(.largeTitle)
    .minimumScaleFactor(0.5)
    .lineLimit(1)
```

Use `ViewThatFits` for complex layouts that need to adapt:

```swift
ViewThatFits {
    HStack { /* Horizontal layout */ }
    VStack { /* Vertical fallback */ }
}
```

#### Test Cases

- [ ] Calculator view with largest Dynamic Type
- [ ] History list with long subject names
- [ ] Explainability cards with large text
- [ ] Button labels remain visible and tappable
- [ ] Form inputs don't overlap
- [ ] Navigation bar titles scale properly

---

## 3. Color Contrast

### 3.1 WCAG Requirements

**WCAG 2.1 Level AA:**
- Normal text (< 18pt): Contrast ratio ≥ 4.5:1
- Large text (≥ 18pt): Contrast ratio ≥ 3:1
- UI components and graphics: Contrast ratio ≥ 3:1

### 3.2 Current Implementation

StudyCoor uses gradient backgrounds extensively (see `View+Backgrounds.swift`). These need contrast verification.

**Key Colors to Audit:**

From `CalculatorView.swift:366-370`:
```swift
private func colorForCompliance(_ pct: Double) -> Color {
    if pct > 110 { return .orange }
    if pct < 90  { return .red }
    return .green
}
```

**Compliance Color Indicators:**
- 🟢 Green (≥90%, ≤110%) - GOOD
- 🔴 Red (<90%) - UNDERUSE
- 🟠 Orange (>110%) - OVERUSE

### 3.3 Audit Checklist

- [ ] Test green compliance on dark gradient background
- [ ] Test red compliance on dark gradient background
- [ ] Test orange compliance on dark gradient background
- [ ] Verify flag chips (UNDERUSE, OVERUSE, HOLD_DAYS) have sufficient contrast
- [ ] Check study/subject chip text contrast
- [ ] Verify button text contrast in all states (normal, disabled, pressed)
- [ ] Check form field placeholder text contrast
- [ ] Verify navigation bar text contrast
- [ ] Test with iOS "Increase Contrast" accessibility setting

### 3.4 Recommended Tools

**Online:**
- WebAIM Contrast Checker: https://webaim.org/resources/contrastchecker/
- Accessible Colors: https://accessible-colors.com/

**macOS:**
- Sim Daltonism: Simulate color blindness
- Xcode Accessibility Inspector

**iOS:**
- Settings > Accessibility > Display & Text Size > Increase Contrast
- Settings > Accessibility > Display & Text Size > Differentiate Without Color

### 3.5 Color Blindness Considerations

Ensure compliance indicators work for users with color blindness:

**Current Approach:**
- Color + percentage number = GOOD ✅

**Enhancement:**
Add icon/symbol in addition to color:
```swift
HStack {
    Image(systemName:
        pct > 110 ? "exclamationmark.triangle" :
        pct < 90 ? "exclamationmark.circle" :
        "checkmark.circle"
    )
    Text("\(pct, specifier: "%.1f")%")
}
.foregroundColor(colorForCompliance(pct))
```

This ensures users who can't distinguish red/orange/green still understand the status.

---

## 4. Keyboard Navigation (iPad)

For iPad users with external keyboards, ensure full keyboard navigation support.

### 4.1 Tab Navigation

- [ ] All interactive elements reachable via Tab key
- [ ] Tab order is logical (top-to-bottom, left-to-right)
- [ ] Focus indicator visible and clear

### 4.2 Keyboard Shortcuts

Consider adding:
- ⌘N - New calculation
- ⌘S - Save/Export
- ⌘⌫ - Clear inputs
- ⌘R - Calculate (Run)
- ⌘, - Settings

Implementation:
```swift
.keyboardShortcut("n", modifiers: .command)
.keyboardShortcut("r", modifiers: .command)
```

---

## 5. Screen Reader Testing Script

### 5.1 VoiceOver Testing Procedure

**Enable VoiceOver:**
- Settings > Accessibility > VoiceOver > On
- Or triple-click side button (if configured)

**Test Script:**

1. **Launch App**
   - Listen for app name announcement
   - Verify tab bar labels are clear

2. **Calculator Tab**
   - Swipe through all form fields
   - Verify each field announces its purpose
   - Enter sample data using VoiceOver keyboard
   - Verify Calculate button announces clearly
   - Listen to result announcement

3. **History Tab**
   - Swipe through calculation list
   - Verify each row announces date, subject, compliance
   - Test swipe actions (delete, export)
   - Verify actions announce before executing

4. **Studies Tab** (Pro)
   - Navigate to paywall if not unlocked
   - Verify subscription options announce prices
   - If unlocked, test study list navigation

5. **Settings Tab**
   - Verify all links announce as links
   - Test toggle switches
   - Verify version info is readable

**Pass Criteria:**
- All interactive elements have labels
- All labels are descriptive and contextual
- No elements are skipped or unreachable
- Actions announce their purpose before execution
- Results are announced after calculation
- No confusing or redundant announcements

---

## 6. Testing with Assistive Technologies

### 6.1 VoiceOver (iOS)

**Test Devices:**
- iPhone 15 (iOS 26.2)
- iPad Pro (latest iOS)

**Test Scenarios:**
- [ ] New user onboarding
- [ ] Enter calculation data
- [ ] Perform calculation
- [ ] Review history
- [ ] Export to CSV/PDF
- [ ] Create new study (Pro)
- [ ] Add subject (Pro)

### 6.2 Voice Control

Test with Voice Control enabled (Settings > Accessibility > Voice Control):
- [ ] "Tap Calculate"
- [ ] "Show numbers" (verify field labels appear)
- [ ] "Tap number 3" (tap specific field)
- [ ] Navigate without touch

### 6.3 Switch Control

Test for users with motor disabilities:
- [ ] All interactive elements selectable
- [ ] Scanning order is logical
- [ ] Actions complete successfully

---

## 7. Accessibility Settings Compatibility

### 7.1 Display Accommodations

Test with:
- [ ] Reduce Motion (smooth animations only)
- [ ] Reduce Transparency (solid backgrounds)
- [ ] Increase Contrast (enhanced colors)
- [ ] Differentiate Without Color (icons + color)
- [ ] Smart Invert Colors (dark mode alternative)

### 7.2 Hearing Accommodations

- [ ] No audio-only feedback (visual indicators for all states)
- [ ] No reliance on sound for important information

### 7.3 Physical and Motor Accommodations

- [ ] Touch Accommodations: Hold Duration tested
- [ ] AssistiveTouch compatible
- [ ] Button targets meet minimum size (44x44pt)

---

## 8. Implementation Priority

### Phase 1: Critical (Before App Store Submission)

1. **VoiceOver labels for CalculatorView** (2-3 days)
   - All text fields
   - All buttons
   - Results display
   - Form sections

2. **Color contrast audit and fixes** (1 day)
   - Verify compliance colors
   - Adjust if needed
   - Test with Increase Contrast enabled

3. **Dynamic Type testing** (1 day)
   - Test all views at largest size
   - Fix layout overflows
   - Add `.minimumScaleFactor()` where needed

### Phase 2: Important (Post-Launch, v1.2)

4. **VoiceOver labels for remaining views** (1-2 days)
   - ExplainabilityView
   - StudiesView
   - SettingsView

5. **Keyboard navigation (iPad)** (1 day)
   - Tab order
   - Focus indicators
   - Keyboard shortcuts

### Phase 3: Nice-to-Have (Future Versions)

6. **Enhanced accessibility hints** (1 day)
   - Contextual hints for complex actions
   - Better grouped announcements

7. **Accessibility-specific testing** (ongoing)
   - Voice Control testing
   - Switch Control testing
   - User testing with assistive technology users

---

## 9. Accessibility Statement (for App Store)

**Suggested text for App Store description:**

> **Accessibility Commitment**
>
> StudyCoor is designed to be accessible to all users, including those with disabilities. We support VoiceOver, Dynamic Type, and other iOS accessibility features. If you encounter any accessibility barriers, please contact us at [email].

---

## 10. Resources

### Apple Documentation
- [Human Interface Guidelines - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [SwiftUI Accessibility](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [Accessibility Modifiers](https://developer.apple.com/documentation/swiftui/view/accessibility-modifiers)

### Testing Tools
- Xcode Accessibility Inspector
- Sim Daltonism (color blindness simulator)
- WebAIM Contrast Checker

### Standards
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Section 508 Requirements](https://www.section508.gov/)

---

## 11. Next Steps

### Immediate Actions (This Week)

1. **Add VoiceOver labels to CalculatorView**
   - Start with high-priority elements (inputs, buttons, results)
   - Test with VoiceOver enabled after each section
   - Document any issues found

2. **Verify color contrast**
   - Use WebAIM checker on key UI elements
   - Test with "Increase Contrast" setting
   - Fix any failing contrasts

3. **Test Dynamic Type**
   - Enable largest text size
   - Navigate through app
   - Fix layout issues

### Before App Store Submission

- [ ] Complete Phase 1 accessibility tasks
- [ ] Run full VoiceOver test script
- [ ] Test Dynamic Type at extreme sizes
- [ ] Verify color contrast meets WCAG AA
- [ ] Add accessibility statement to App Store description
- [ ] Document known limitations (if any)

---

**Document Version:** 1.0
**Last Updated:** January 11, 2026
**Next Review:** After Phase 1 implementation
