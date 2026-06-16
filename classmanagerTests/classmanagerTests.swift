//
//  classmanagerTests.swift
//  classmanagerTests
//
//  Created by Patrick McIlhenney on 11/7/25.
//

import Testing
@testable import classmanager

struct classmanagerTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testJotFormSubmissionParserWithRegistrationForm() {
        // Test parsing registration form JSON with product selection
        let jsonString = """
        {
            "responseCode": 200,
            "content": {
                "id": "123456789",
                "form_id": "251265925097060",
                "answers": {
                    "4": {
                        "name": "name",
                        "answer": {
                            "first": "Tommy",
                            "last": "McNewguy"
                        }
                    },
                    "5": {
                        "name": "email",
                        "answer": "tmcnewguy@gc-ems.com"
                    },
                    "6": {
                        "name": "njOems",
                        "answer": "501401"
                    },
                    "7": {
                        "name": "date",
                        "answer": {
                            "datetime": "1984-02-23 00:00:00"
                        },
                        "prettyFormat": "02-23-1984"
                    },
                    "26": {
                        "answer": {
                            "full": "(856) 510-7777"
                        }
                    },
                    "39": {
                        "answer": {
                            "1": "{\\"pid\\":\\"1002\\",\\"name\\":\\"Test Course\\",\\"description\\":\\"Date: January 1, 2026\\\\nTime: 08:00-17:00\\\\nCourse ID: 166119\\"}"
                        },
                        "products": [
                            {
                                "pid": "1002",
                                "name": "Test Course",
                                "description": "Date: January 1, 2026\\nTime: 08:00-17:00\\nCourse ID: 166119"
                            }
                        ]
                    },
                    "41": {
                        "answer": {
                            "addr_line1": "25 E. 9th Ave",
                            "city": "Glendora",
                            "state": "NJ",
                            "postal": "08029"
                        }
                    }
                }
            }
        }
        """

        let parser = JotFormSubmissionParser()
        let data = jsonString.data(using: .utf8)!
        let student = parser.parse(data: data)

        #expect(student != nil)
        #expect(student?.firstName == "Tommy")
        #expect(student?.lastName == "McNewguy")
        #expect(student?.email == "tmcnewguy@gc-ems.com")
        #expect(student?.njOemsId == "501401")
        #expect(student?.courseName == "Test Course")
        #expect(student?.courseDate == "January 1, 2026")
        #expect(student?.courseTime == "08:00-17:00")
        #expect(student?.courseId == "166119")
    }

}
