import SwiftUI

enum NumericFormatter {
    static func parseLocalized(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let groupingSeparator = locale.groupingSeparator ?? ","
        let decimalSeparator = locale.decimalSeparator ?? "."

        var sanitized = trimmed.replacingOccurrences(of: groupingSeparator, with: "")
        if decimalSeparator != "." {
            sanitized = sanitized.replacingOccurrences(of: decimalSeparator, with: ".")
        }

        let allowed = CharacterSet(charactersIn: "0123456789.-")
        sanitized = String(sanitized.unicodeScalars.filter { allowed.contains($0) })

        guard !sanitized.isEmpty else { return nil }
        return Double(sanitized)
    }

    static func formatted(_ value: Double, allowPartials: Bool, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = allowPartials ? 6 : 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

extension View {
    /// Validates numeric input to ensure non-negative values, respecting the user locale.
    func numericValidation(
        text: Binding<String>,
        allowPartials: Bool = true,
        lastValidValue: Binding<String>? = nil
    ) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            if newValue.isEmpty {
                lastValidValue?.wrappedValue = ""
                return
            }

            let locale = Locale.current
            let decimalSeparator = locale.decimalSeparator ?? "."

            if allowPartials, let last = newValue.last, String(last) == decimalSeparator {
                // Allow users to type the decimal separator and continue editing.
                if newValue == decimalSeparator {
                    text.wrappedValue = "0" + decimalSeparator
                    lastValidValue?.wrappedValue = text.wrappedValue
                } else {
                    let prefix = String(newValue.dropLast())
                    if NumericFormatter.parseLocalized(prefix, locale: locale) != nil {
                        lastValidValue?.wrappedValue = newValue
                    } else {
                        text.wrappedValue = lastValidValue?.wrappedValue ?? "0"
                    }
                }
                return
            }

            guard let parsed = NumericFormatter.parseLocalized(newValue, locale: locale) else {
                text.wrappedValue = lastValidValue?.wrappedValue ?? "0"
                return
            }

            let clamped = max(0, parsed)
            let finalValue = allowPartials ? clamped : round(clamped)

            if finalValue != parsed {
                let formatted = NumericFormatter.formatted(finalValue, allowPartials: allowPartials, locale: locale)
                text.wrappedValue = formatted
                lastValidValue?.wrappedValue = formatted
            } else {
                lastValidValue?.wrappedValue = newValue
            }
        }
        .submitLabel(.done)
    }

    /// Validates integer input (like hold days) to ensure non-negative whole numbers.
    func integerValidation(text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            if newValue.isEmpty {
                return
            }

            let locale = Locale.current
            let sanitized = NumericFormatter.parseLocalized(newValue, locale: locale)

            guard let value = sanitized else {
                text.wrappedValue = "0"
                return
            }

            let clamped = max(0, round(value))
            let formatted = NumericFormatter.formatted(clamped, allowPartials: false, locale: locale)
            if formatted != newValue {
                text.wrappedValue = formatted
            }
        }
        .submitLabel(.done)
    }
}
