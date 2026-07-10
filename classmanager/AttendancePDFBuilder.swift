//
//  Untitled.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/14/25.
//

//  AttendancePDFBuilder.swift
//  classmanager

import Foundation
import PDFKit
import UIKit   // for UIFont / UIImage

struct AttendancePDFBuilder {

    struct Payload {
        let firstName: String
        let lastName: String
        let oemsId: String
        let courseId: String
        let courseType: String
        let inOutLabel: String     // "Check-In" / "Check-Out"
        let timestamp: Date
        let signaturePNGData: Data
    }

    /// Generate a 1-page PDF by drawing on top of the PDF_Template.pdf
    static func makePDF(payload: Payload) -> Data? {
        // 1. Load the base template from bundle
        guard
            let url = Bundle.main.url(forResource: "PDF_Template", withExtension: "pdf"),
            let baseDoc = PDFDocument(url: url),
            let basePage = baseDoc.page(at: 0),
            let cgPage = basePage.pageRef
        else {
            AppDebugLog.log("[AttendancePDFBuilder] Failed to load PDF_Template.pdf")
            return nil
        }

        let bounds = basePage.bounds(for: .mediaBox)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext

            // Draw the base page as background
            cg.drawPDFPage(cgPage)

            // Common text attributes
            let font = UIFont.systemFont(ofSize: 14)
            let boldFont = UIFont.boldSystemFont(ofSize: 14)
            let textColor = UIColor.black

            func draw(_ text: String, at point: CGPoint, bold: Bool = false) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bold ? boldFont : font,
                    .foregroundColor: textColor
                ]
                (text as NSString).draw(at: point, withAttributes: attrs)
            }

            // 2. Compute friendly strings
            let fullName = "\(payload.firstName) \(payload.lastName)"
            let formatter = DateFormatter()
            formatter.locale = .init(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "America/New_York") ?? .current
            formatter.dateFormat = "MM/dd/yyyy HH:mm"
            let tsString = formatter.string(from: payload.timestamp)

            // 3. Draw text into the right spots.
            //    ⚠️ You will very likely need to tweak these x/y values
            //    to match your template exactly. Start here and adjust.
            draw(fullName,                         at: CGPoint(x: 120, y: 120), bold: true)
            draw("NJ OEMS: \(payload.oemsId)",     at: CGPoint(x: 120, y: 145))
            draw("Course ID: \(payload.courseId)", at: CGPoint(x: 120, y: 170))
            draw("Course: \(payload.courseType)",  at: CGPoint(x: 120, y: 195))
            draw("Action: \(payload.inOutLabel)",  at: CGPoint(x: 120, y: 220))
            draw("Date/Time: \(tsString)",         at: CGPoint(x: 120, y: 245))

            // 4. Draw signature image
            if let sigImage = UIImage(data: payload.signaturePNGData) {
                // Again, tweak this rect to match your signature line box
                let sigRect = CGRect(x: 120, y: 300, width: 260, height: 80)
                sigImage.draw(in: sigRect)
            }
        }

        return data
    }
}
