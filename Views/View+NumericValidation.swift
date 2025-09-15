import SwiftUI

extension View {
    /// Validates numeric input to ensure non-negative values
    /// - Parameters:
    ///   - text: Binding to the text field
    ///   - allowPartials: Whether to allow decimal values
    ///   - lastValidValue: Optional binding to store last valid value for fallback
    func numericValidation(
        text: Binding<String>,
        allowPartials: Bool = true,
        lastValidValue: Binding<String>? = nil
    ) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            // Allow empty string while editing
            if newValue.isEmpty {
                return
            }
            
            // Try to parse the value
            if let doubleValue = Double(newValue) {
                // Clamp to non-negative
                let clampedValue = max(0, doubleValue)
                
                // If partials are disabled, round to whole number
                let finalValue = allowPartials ? clampedValue : round(clampedValue)
                
                // Format back to string
                let formattedValue: String
                if allowPartials {
                    // Remove unnecessary trailing zeros for decimals
                    formattedValue = finalValue.truncatingRemainder(dividingBy: 1) == 0 
                        ? String(format: "%.0f", finalValue)
                        : String(finalValue)
                } else {
                    formattedValue = String(format: "%.0f", finalValue)
                }
                
                // Update if value changed
                if formattedValue != newValue {
                    text.wrappedValue = formattedValue
                }
                
                // Store as last valid value
                lastValidValue?.wrappedValue = formattedValue
            } else {
                // Invalid input - revert to last valid value or "0"
                text.wrappedValue = lastValidValue?.wrappedValue ?? "0"
            }
        }
        .submitLabel(.done)
    }
    
    /// Validates integer input (like hold days) to ensure non-negative whole numbers
    func integerValidation(text: Binding<String>) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            // Allow empty string while editing
            if newValue.isEmpty {
                return
            }
            
            // Try to parse as integer
            if let intValue = Int(newValue) {
                let clampedValue = max(0, intValue)
                let formattedValue = String(clampedValue)
                
                if formattedValue != newValue {
                    text.wrappedValue = formattedValue
                }
            } else {
                // Invalid input - revert to "0"
                text.wrappedValue = "0"
            }
        }
        .submitLabel(.done)
    }
}