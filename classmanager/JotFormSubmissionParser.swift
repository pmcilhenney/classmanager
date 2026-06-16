//
//  JotFormSubmissionParser.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/29/25.
//
import Foundation

struct JotFormSubmissionParser {

    func parse(data: Data) -> Student? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let content = json["content"] as? [String: Any],
            let answers = content["answers"] as? [String: Any]
        else { return nil }

        let submissionId = content["id"] as? String
        let formId = content["form_id"] as? String

        func answer(_ qid: String) -> [String: Any]? {
            answers[qid] as? [String: Any]
        }

        // MARK: - Identity
        var first = ""
        var last = ""

        if
            let f = answer("4"),
            let a = f["answer"] as? [String: Any]
        {
            first = a["first"] as? String ?? ""
            last = a["last"] as? String ?? ""
        }

        let email = answer("5")?["answer"] as? String ?? ""
        let phone = (answer("26")?["answer"] as? [String: Any])?["full"] as? String ?? ""

        // NJ OEMS ID
        let njOemsId = answer("6")?["answer"] as? String

        // DOB
        let dobPretty = answer("7")?["prettyFormat"] as? String
        let dobISO = (answer("7")?["answer"] as? [String: Any])?["datetime"] as? String

        // Address
        var address1 = ""
        var address2 = ""
        var city = ""
        var state = ""
        var postal = ""

        if
            let addr = answer("41"),
            let a = addr["answer"] as? [String: Any]
        {
            address1 = a["addr_line1"] as? String ?? ""
            address2 = a["addr_line2"] as? String ?? ""
            city = a["city"] as? String ?? ""
            state = a["state"] as? String ?? ""
            postal = a["postal"] as? String ?? ""
        }

        // MARK: - Course Info (QID 39) - ENHANCED 2.0
        var courseName: String?
        var courseDate: String?
        var courseTime: String?
        var courseId: String?
        var courseCEU: String?
        var courseCategories: [String]?
        var courseDescription: String?
        var courseImageURL: String?
        
        // Course Location (QID 46)
        let courseLocation = answer("46")?["answer"] as? String
        print("[JotFormSubmissionParser] Course Location (QID 46): \(courseLocation ?? "nil")")

        if let courseField = answer("39") {
            print("[JotFormSubmissionParser] Processing QID 39 course field")
            
            // The answer dictionary contains the selected product info
            if let answerDict = courseField["answer"] as? [String: Any] {
                print("[JotFormSubmissionParser] Found answer dict with keys: \(answerDict.keys.joined(separator: ", "))")
                
                // Check if there's a direct product selection in answer["1"] as JSON string
                if let productJson = answerDict["1"] as? String,
                   let jsonData = productJson.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    
                    print("[JotFormSubmissionParser] Parsed product JSON from answer['1']")
                    
                    // Extract course name
                    if let name = parsed["name"] as? String {
                        courseName = name
                        print("[JotFormSubmissionParser] Course Name: \(name)")
                    }
                    
                    // Extract course image URL (NEW)
                    if let images = parsed["images"] as? String {
                        // images is often a JSON string like '["https://..."]'
                        if let data = images.data(using: .utf8),
                           let arr = try? JSONSerialization.jsonObject(with: data) as? [String],
                           let firstImage = arr.first {
                            courseImageURL = firstImage
                            print("[JotFormSubmissionParser] Course Image URL: \(firstImage)")
                        }
                    } else if let images = parsed["images"] as? [String], let firstImage = images.first {
                        courseImageURL = firstImage
                        print("[JotFormSubmissionParser] Course Image URL: \(firstImage)")
                    }
                    
                    // Extract description for parsing
                    if let desc = parsed["description"] as? String {
                        courseDescription = desc
                        print("[JotFormSubmissionParser] Course Description: \(desc)")
                        
                        // Parse structured fields from description
                        let parsedFields = parseStructuredCourseDescription(desc)
                        courseDate = parsedFields.date
                        courseTime = parsedFields.time
                        courseId = parsedFields.id
                        courseCEU = parsedFields.ceu
                        
                        print("[JotFormSubmissionParser] Parsed - Date: \(courseDate ?? "nil"), Time: \(courseTime ?? "nil"), ID: \(courseId ?? "nil"), CEU: \(courseCEU ?? "nil")")
                    }
                    
                    // Extract connected categories (determines Elective vs Refresher)
                    if let cid = parsed["cid"] as? String {
                        courseCategories = [cid]
                        print("[JotFormSubmissionParser] Course Category (cid): \(cid)")
                    } else if let connectedCats = parsed["connectedCategories"] as? String {
                        // connectedCategories arrives as JSON string like '["2002"]'
                        if let data = connectedCats.data(using: .utf8),
                           let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                            courseCategories = arr.compactMap { String(describing: $0) }
                            print("[JotFormSubmissionParser] Connected Categories: \(courseCategories?.joined(separator: ", ") ?? "none")")
                        } else {
                            // Fallback: parse naive comma-separated values inside brackets
                            let trimmed = connectedCats.replacingOccurrences(of: "[", with: "")
                                                       .replacingOccurrences(of: "]", with: "")
                            let parts = trimmed.split(separator: ",")
                                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"'")) }
                            if !parts.isEmpty {
                                courseCategories = parts.map { String($0) }
                                print("[JotFormSubmissionParser] Parsed Categories (fallback): \(courseCategories?.joined(separator: ", ") ?? "none")")
                            }
                        }
                    }
                } else {
                    print("[JotFormSubmissionParser] No product JSON found in answer['1']")
                }
                
                // FALLBACK: Check paymentArray for course info
                if courseName == nil, let paymentArray = answerDict["paymentArray"] as? String {
                    print("[JotFormSubmissionParser] Attempting fallback parse from paymentArray")
                    if let data = paymentArray.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let products = parsed["product"] as? [String] {
                        if let firstProduct = products.first {
                            // Extract course name from string like "EMT Refresher A (Amount: 0.00 USD)"
                            if let parenRange = firstProduct.range(of: " (Amount:") {
                                courseName = String(firstProduct[..<parenRange.lowerBound])
                                print("[JotFormSubmissionParser] Extracted course name from paymentArray: \(courseName ?? "nil")")
                            } else {
                                courseName = firstProduct
                            }
                        }
                    }
                }
            }
            
            // ADDITIONAL FALLBACK: Check products array in the field
            if courseName == nil || courseCategories == nil {
                if let products = courseField["products"] as? [[String: Any]], !products.isEmpty {
                    print("[JotFormSubmissionParser] Checking products array (\(products.count) products)")
                    
                    // Try to find selected product by looking for selected=1 or matching answer
                    var selectedProduct: [String: Any]?
                    
                    for prod in products {
                        if let selected = prod["selected"] as? String, selected == "1" {
                            selectedProduct = prod
                            print("[JotFormSubmissionParser] Found selected product via selected='1'")
                            break
                        }
                    }
                    
                    // If no selected product, use first product as fallback
                    if selectedProduct == nil, let first = products.first {
                        selectedProduct = first
                        print("[JotFormSubmissionParser] Using first product as fallback")
                    }
                    
                    if let product = selectedProduct {
                        if courseName == nil, let name = product["name"] as? String {
                            courseName = name
                            print("[JotFormSubmissionParser] Course Name from products: \(name)")
                        }
                        
                        if courseImageURL == nil {
                            if let images = product["images"] as? String {
                                if let data = images.data(using: .utf8),
                                   let arr = try? JSONSerialization.jsonObject(with: data) as? [String],
                                   let firstImage = arr.first {
                                    courseImageURL = firstImage
                                    print("[JotFormSubmissionParser] Image URL from products: \(firstImage)")
                                }
                            } else if let images = product["images"] as? [String], let firstImage = images.first {
                                courseImageURL = firstImage
                                print("[JotFormSubmissionParser] Image URL from products: \(firstImage)")
                            }
                        }
                        
                        if courseDescription == nil, let desc = product["description"] as? String {
                            courseDescription = desc
                            let parsedFields = parseStructuredCourseDescription(desc)
                            courseDate = parsedFields.date
                            courseTime = parsedFields.time
                            courseId = parsedFields.id
                            courseCEU = parsedFields.ceu
                            print("[JotFormSubmissionParser] Parsed from products - Date: \(courseDate ?? "nil"), ID: \(courseId ?? "nil")")
                        }
                        
                        if courseCategories == nil {
                            if let cid = product["cid"] as? String {
                                courseCategories = [cid]
                                print("[JotFormSubmissionParser] Category from products: \(cid)")
                            } else if let connectedCats = product["connectedCategories"] as? String {
                                if let data = connectedCats.data(using: .utf8),
                                   let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                                    courseCategories = arr.compactMap { String(describing: $0) }
                                    print("[JotFormSubmissionParser] Categories from products: \(courseCategories?.joined(separator: ", ") ?? "none")")
                                }
                            }
                        }
                    }
                }
            }
            
            print("[JotFormSubmissionParser] FINAL - Name: \(courseName ?? "nil"), Categories: \(courseCategories?.joined(separator: ",") ?? "nil"), Date: \(courseDate ?? "nil"), ID: \(courseId ?? "nil")")
        } else {
            print("[JotFormSubmissionParser] WARNING: No QID 39 found in answers")
        }

        // MARK: - Build Student
        let student = Student(
            firstName: first,
            lastName: last,
            email: email,
            phone: phone,
            dobPretty: dobPretty,
            dobISO: dobISO,
            njOemsId: njOemsId,
            addressLine1: address1,
            addressLine2: address2,
            city: city,
            state: state,
            postal: postal,
            courseName: courseName,
            courseDate: courseDate,
            courseTime: courseTime,
            courseId: courseId,
            ceuValue: courseCEU,
            connectedCategories: courseCategories,
            courseDescription: courseDescription,
            courseImageURL: courseImageURL,
            courseLocation: courseLocation,
            submissionId: submissionId,
            formId: formId
        )

        return student
    }

    // MARK: - 2.0 Structured Description Parser
    /// Parses product description in format:
    /// Date: January 1, 2026
    /// Time: 08:00-17:00
    /// Course ID: 166119
    /// CEUs: 8.0
    private func parseStructuredCourseDescription(_ description: String) -> (date: String?, time: String?, id: String?, ceu: String?) {

        var date: String?
        var time: String?
        var id: String?
        var ceu: String?

        // Try single-line format first (most common for products)
        // Format: "Date: February 24, 2026 Time: 1900-2100 Course ID: 167074 CEUs: 2.0"
        
        // Extract Date
        if let dateRange = description.range(of: #"Date:\s*([^T]+?)(?=\s+Time:|$)"#, options: .regularExpression) {
            let dateStr = String(description[dateRange])
                .replacingOccurrences(of: "Date:", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let formatted = formatDateString(dateStr) {
                date = formatted
            } else {
                date = dateStr
            }
        }
        
        // Extract Time
        if let timeRange = description.range(of: #"Time:\s*([^C]+?)(?=\s+Course|$)"#, options: .regularExpression) {
            time = String(description[timeRange])
                .replacingOccurrences(of: "Time:", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        
        // Extract Course ID
        if let idRange = description.range(of: #"Course ID:\s*(\d+)"#, options: .regularExpression) {
            let match = String(description[idRange])
            id = match.replacingOccurrences(of: "Course ID:", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        
        // Extract CEU/CEUs
        if let ceuRange = description.range(of: #"CEUs?:\s*([\d.]+)"#, options: .regularExpression) {
            let match = String(description[ceuRange])
            if let colonIndex = match.firstIndex(of: ":") {
                let val = match[match.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { ceu = val }
            }
        }
        
        // If regex didn't work, try multi-line format (fallback)
        if date == nil || time == nil || id == nil || ceu == nil {
            let lines = description.components(separatedBy: .newlines)
            
            for raw in lines {
                let line = raw.trimmingCharacters(in: .whitespaces)
                
                if date == nil && line.starts(with: "Date:") {
                    let dateStr = line.replacingOccurrences(of: "Date:", with: "").trimmingCharacters(in: .whitespaces)
                    if let formatted = formatDateString(dateStr) {
                        date = formatted
                    } else {
                        date = dateStr
                    }
                }
                else if time == nil && line.starts(with: "Time:") {
                    time = line.replacingOccurrences(of: "Time:", with: "").trimmingCharacters(in: .whitespaces)
                }
                else if id == nil && line.starts(with: "Course ID:") {
                    id = line.replacingOccurrences(of: "Course ID:", with: "").trimmingCharacters(in: .whitespaces)
                }
                else if ceu == nil && line.range(of: #"^CEU|CEUs?:"#, options: .regularExpression) != nil {
                    if let colon = line.firstIndex(of: ":") {
                        let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                        if !val.isEmpty { ceu = val }
                    }
                }
            }
        }

        return (date, time, id, ceu)
    }
    
    /// Convert date strings like "January 15, 2026" to "01/15/2026"
    private func formatDateString(_ dateStr: String) -> String? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        
        // Try various input formats
        let inputFormats = ["MMMM d, yyyy", "MMM d, yyyy", "MMMM d yyyy", "MMM d yyyy", "yyyy-MM-dd"]
        
        for format in inputFormats {
            df.dateFormat = format
            if let date = df.date(from: dateStr.trimmingCharacters(in: .whitespaces)) {
                // Output as MM/dd/yyyy
                df.dateFormat = "MM/dd/yyyy"
                return df.string(from: date)
            }
        }
        
        return nil
    }
}
