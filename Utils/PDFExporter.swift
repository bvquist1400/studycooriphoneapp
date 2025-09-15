import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PDFExporter {
    static func calculationSummaryPDF(_ calculation: Calculation) -> Data? {
        #if canImport(UIKit)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter 72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold)
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]
            let x: CGFloat = 40
            var y: CGFloat = 40

            func draw(_ text: String, attrs: [NSAttributedString.Key: Any]) {
                let attr = NSAttributedString(string: text, attributes: attrs)
                let size = attr.size()
                attr.draw(at: CGPoint(x: x, y: y))
                y += size.height + 8
            }

            draw("StudyCoor – Calculation Summary", attrs: titleAttrs)
            draw("Subject: \(calculation.subjectId ?? "N/A")", attrs: bodyAttrs)
            draw("Period: \(calculation.startDate.formatted(date: .abbreviated, time: .omitted)) – \(calculation.endDate.formatted(date: .abbreviated, time: .omitted))", attrs: bodyAttrs)
            draw("Frequency: \(calculation.frequency.rawValue)", attrs: bodyAttrs)
            if calculation.frequency != .prn {
                let f = calculation.firstDayExpectedOverride.map(String.init) ?? "-"
                let l = calculation.lastDayExpectedOverride.map(String.init) ?? "-"
                draw("Edge days: first \(f)  last \(l)", attrs: bodyAttrs)
            } else if let t = calculation.prnTargetPerDay {
                draw("PRN target/day: \(String(format: "%.2f", t))", attrs: bodyAttrs)
            }
            draw("Dispensed: \(String(format: "%.2f", calculation.dispensed))  Returned: \(String(format: "%.2f", calculation.returned))", attrs: bodyAttrs)
            draw("Missed: \(String(format: "%.2f", calculation.missedDoses))  Extra: \(String(format: "%.2f", calculation.extraDoses))  Hold days: \(calculation.holdDays)", attrs: bodyAttrs)
            draw("Expected: \(String(format: "%.2f", calculation.expectedDoses))", attrs: bodyAttrs)
            draw("Actual: \(String(format: "%.2f", calculation.actualDoses))", attrs: bodyAttrs)
            draw("Compliance: \(String(format: "%.1f%%", calculation.compliancePct))", attrs: bodyAttrs)
            if !calculation.flags.isEmpty {
                draw("Flags: \(calculation.flags.joined(separator: ", "))", attrs: bodyAttrs)
            }
            draw("Created: \(calculation.createdAt.formatted())", attrs: bodyAttrs)
        }
        return data
        #else
        return nil
        #endif
    }
}

