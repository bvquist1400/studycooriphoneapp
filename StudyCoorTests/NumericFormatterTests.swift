import XCTest
@testable import StudyCoor

final class NumericFormatterTests: XCTestCase {
    func testParseLocalizedCommaDecimal() {
        let locale = Locale(identifier: "fr_FR")
        let value = NumericFormatter.parseLocalized("1,5", locale: locale)
        XCTAssertNotNil(value)
        XCTAssertEqual(value ?? 0, 1.5, accuracy: 0.0001)
    }

    func testParseLocalizedGroupingSeparators() {
        let locale = Locale(identifier: "de_DE")
        let value = NumericFormatter.parseLocalized("1.234,75", locale: locale)
        XCTAssertNotNil(value)
        XCTAssertEqual(value ?? 0, 1234.75, accuracy: 0.0001)
    }

    func testFormattedMatchesLocale() {
        let locale = Locale(identifier: "de_DE")
        let formatted = NumericFormatter.formatted(1234.75, allowPartials: true, locale: locale)
        XCTAssertEqual(formatted, "1.234,75")
    }
}
