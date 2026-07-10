//
//  FlexiQuizView.swift
//  classmanager
//
//  FlexiQuiz embedded with auto-filled registration
//  Version 2.0: Dynamic field detection for future-proof auto-fill
//

import SwiftUI
import WebKit

// MARK: - Quiz Selection View
struct InternalQuizSelectionView: View {
    let attendee: RosterAttendee
    let quizURLs: [QuizInfo]
    @Binding var selectedQuiz: QuizInfo?
    @Binding var completedQuizzes: Set<String>
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Course Quizzes")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Quiz buttons
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(quizURLs) { quiz in
                        QuizButton(
                            quiz: quiz,
                            isCompleted: completedQuizzes.contains(quiz.id),
                            action: {
                                selectedQuiz = quiz
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Quiz Button
struct QuizButton: View {
    let quiz: QuizInfo
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Quiz number badge
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color.blue)
                        .frame(width: 50, height: 50)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(quiz.number)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Quiz info
                VStack(alignment: .leading, spacing: 4) {
                    Text(quiz.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if isCompleted {
                        Text("Completed ✓")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Text("Tap to start")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlexiQuiz WebView
struct FlexiQuizWebView: View {
    let quiz: QuizInfo
    let attendee: RosterAttendee
    // onComplete now receives an optional result string and optional reviewId token
    let onComplete: (String?, String?) -> Void
    let onBack: () -> Void
    // Optional reviewId token that instructs the webview to open the review UI when loaded
    var autoOpenReviewId: String? = nil
    
    @State private var isLoading = true
    @State private var hasAutoFilled = false
    @State private var hasReportedResult = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back to Quizzes")
                    }
                    .font(.system(size: 16, weight: .medium))
                }
                
                Spacer()
                
                Text(quiz.title)
                    .font(.headline)
                
                Spacer()
                
                // (Removed manual 'Complete' button - completion is tracked automatically)
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // WebView
            ZStack {
                FlexiQuizWebViewRepresentable(
                    url: quiz.url,
                    attendee: attendee,
                    isLoading: $isLoading,
                    hasAutoFilled: $hasAutoFilled,
                    hasReportedResult: $hasReportedResult,
                    autoOpenReviewId: autoOpenReviewId,
                    onDetectedComplete: { result, reviewId in
                        // propagate parsed result and optional review id to parent
                        onComplete(result, reviewId)
                    }
                )
                
                if isLoading {
                    // Full-area loading indicator to block intermediate registration page visibility
                    ZStack {
                        Color(.systemBackground).opacity(0.9)
                            .edgesIgnoringSafeArea(.all)
                        VStack(spacing: 12) {
                            LoadingSpinnerView()
                            Text("Loading quiz...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - WebView Representable
struct FlexiQuizWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let attendee: RosterAttendee
    @Binding var isLoading: Bool
    @Binding var hasAutoFilled: Bool
    @Binding var hasReportedResult: Bool
    var autoOpenReviewId: String?
    var onDetectedComplete: ((String?, String?) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: FlexiQuizWebViewRepresentable
        private var hasAutoOpenedReview = false
        
        init(_ parent: FlexiQuizWebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            AppDebugLog.log("[FlexiQuiz] ✓ Page loaded: \(webView.url?.absoluteString ?? "unknown")")
            
            // Check if this is the registration page (not already auto-filled)
            // Small delay to ensure DOM is fully rendered; always attempt result detection
            // Reset reported-result state when navigating away from a results page so
            // re-taken quizzes (which navigate back and forth) can be detected again.
            if let urlStr = webView.url?.absoluteString {
                let lower = urlStr.lowercased()
                // Results pages typically contain '/sc/rt' in the path; if current
                // URL is NOT a results page, clear the hasReportedResult flag to allow
                // future detections when a results page loads again.
                if !lower.contains("/sc/rt") {
                    DispatchQueue.main.async {
                        self.parent.hasReportedResult = false
                    }
                }
            }

            if !parent.hasAutoFilled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.detectAndAutoFill(webView)
                }
            }
            // Always check results (guarded by hasReportedResult) in case registration was skipped
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.detectResults(webView)
            }
        }
        
        private func detectAndAutoFill(_ webView: WKWebView) {
            // First, check if registration fields exist
            let detectionJS = """
            (function() {
                try {
                    // Look for the "Begin Quiz" or registration button
                    var regButton = document.getElementById('registerParticipantButton');
                    if (!regButton) return JSON.stringify({isRegistration: false});
                    
                    // Found registration page - return true
                    return JSON.stringify({isRegistration: true});
                } catch(e) {
                    return JSON.stringify({isRegistration: false});
                }
            })();
            """
            
            webView.evaluateJavaScript(detectionJS) { result, error in
                if let jsonStr = result as? String,
                   let data = jsonStr.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let isReg = obj["isRegistration"] as? Bool, isReg {
                    
                    AppDebugLog.log("[FlexiQuiz] 🔍 Registration page detected - auto-filling...")
                    self.autoFillRegistration(webView)
                } else {
                    // Not a registration page, clear loading
                    AppDebugLog.log("[FlexiQuiz] ℹ️ Not a registration page")
                    DispatchQueue.main.async {
                        self.parent.isLoading = false
                    }
                }
            }
        }
        
        private func detectResults(_ webView: WKWebView) {
            // Skip if already reported
            guard !parent.hasReportedResult else { return }
            
            // FIXED LOGIC: Only parse Pass/Fail/score AFTER confirming the unique marker is present
            let detectResultsJS = #"""
                (function() {
                    try {
                        // Step 1: Check for the REQUIRED unique marker
                        var marker = "6e0a9b0f6f6d5a0d2d3d2c88c97e7b1a";
                        var html = (document.documentElement && document.documentElement.outerHTML) ? document.documentElement.outerHTML : '';
                        var url = (window.location && window.location.href) ? window.location.href : '';
                        var markerFound = (html.indexOf(marker) !== -1) || (url.indexOf(marker) !== -1);

                        // Step 2: Extract review ID (always attempt, even if marker not found)
                        var reviewId = '';
                        var reviewBtn = document.getElementById('reviewAnswersButton');
                        if (reviewBtn && reviewBtn.getAttribute) {
                            var oc = reviewBtn.getAttribute('onclick') || '';
                            var needle = "reviewAnswers('";
                            var idx = oc.indexOf(needle);
                            if (idx !== -1) {
                                var start = oc.indexOf("'", idx) + 1;
                                var end = oc.indexOf("'", start);
                                if (start > 0 && end > start) { reviewId = oc.substring(start, end); }
                            }
                        }

                        // Step 3: ONLY if marker is found, attempt to extract result text
                        if (!markerFound) {
                            // NO marker → not a results page, do not parse anything
                            return JSON.stringify({found: false, result: '', reviewId: '', marker: false});
                        }

                        // Marker IS present → this is a confirmed results page
                        // Now we can safely look for Pass/Fail/score text

                        function tryExtract() {
                            // Look in .row divs for result text
                            var rows = document.querySelectorAll('.row');
                            for (var i = 0; i < rows.length; i++) {
                                var row = rows[i];
                                var cols = row.querySelectorAll('div');
                                if (cols.length >= 2) {
                                    var left = (cols[0].innerText || '').trim().toLowerCase();
                                    var right = (cols[1].innerText || '').trim();
                                    if (left.indexOf('result') !== -1 && right.length > 0) {
                                        return {found:true, result: right};
                                    }
                                }
                            }

                            // Fallback: broader search for Pass/Fail/score in the HTML
                            // (but ONLY because we already confirmed marker is present)
                            var m = html.match(/(?:result|results|your score|score)[\s:\-\n]*([A-Za-z0-9 %]+)/i);
                            if (m && m[1]) {
                                return {found:true, result: m[1].trim()};
                            }

                            return {found:false, result:''};
                        }

                        var extracted = tryExtract();
                        if (extracted.found) {
                            return JSON.stringify({found: true, result: extracted.result, reviewId: reviewId, marker: true});
                        }

                        // Marker present but no explicit result text found → still treat as completion
                        return JSON.stringify({found: true, result: 'Completed', reviewId: reviewId, marker: true});

                    } catch(e) { 
                        return JSON.stringify({found: false, result: '', reviewId: '', marker: false}); 
                    }
                })();
                """#

            // Evaluate detection JS
            webView.evaluateJavaScript(detectResultsJS) { res, evalError in
                // Always capture a debug snapshot if evaluation errored or didn't return expected structure
                if let jsonStr = res as? String,
                   let data = jsonStr.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let found = obj["found"] as? Bool, found {

                    let resultText = (obj["result"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let reviewId = (obj["reviewId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

                    DispatchQueue.main.async {
                        if !self.parent.hasReportedResult {
                            AppDebugLog.log("[FlexiQuiz] Results page detected – parsed result: \(resultText ?? "") reviewId=\(reviewId ?? "")")
                            self.parent.hasReportedResult = true
                            self.parent.isLoading = false
                            self.parent.onDetectedComplete?(resultText, reviewId)

                            // Auto-open review if requested and not already opened
                            if let desired = self.parent.autoOpenReviewId, !self.hasAutoOpenedReview {
                                if !desired.isEmpty {
                                    let safeId = desired.replacingOccurrences(of: "'", with: "\\'")
                                    let openReviewJS = "(function(){try{ if(typeof reviewAnswers==='function'){ reviewAnswers('" + safeId + "'); } else { var el=document.getElementById('reviewAnswersButton'); if(el){ el.click(); } } }catch(e){} })();"
                                    webView.evaluateJavaScript(openReviewJS) { _, _ in
                                        self.hasAutoOpenedReview = true
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Detection didn't find a result – gather debug info and clear loader
                    DispatchQueue.main.async {
                        self.parent.isLoading = false
                    }

                    // Log evaluation error and capture body text for debugging
                    AppDebugLog.log("[FlexiQuiz] detectResultsJS returned no result or failed: \(String(describing: evalError))")
                    if let urlStr = webView.url?.absoluteString {
                        AppDebugLog.log("[FlexiQuiz] Current URL: \(urlStr)")
                    }
                    webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { body, _ in
                        AppDebugLog.log("[FlexiQuiz] Page body snapshot (truncated 200 chars): \(String(describing: body).prefix(200))")
                    }
                }
            }

            // Safety fallback: if nothing reports a result within 5 seconds, clear the loader to avoid indefinite spinner
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !self.parent.hasReportedResult {
                    AppDebugLog.log("[FlexiQuiz] Fallback timeout – clearing loader (no result reported)")
                    self.parent.isLoading = false
                    // capture page snapshot for later debugging
                    webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { body, _ in
                        AppDebugLog.log("[FlexiQuiz] Fallback page body snapshot (truncated 200 chars): \(String(describing: body).prefix(200))")
                    }
                }
            }
        }
        
        private func autoFillRegistration(_ webView: WKWebView) {
            let firstName = parent.attendee.firstName
            let lastName = parent.attendee.lastName
            let email = parent.attendee.email
            let oemsId = parent.attendee.oemsId
            // Escape single quotes and backslashes/newlines to safely interpolate into JS string literals
            func jsEscape(_ s: String) -> String {
                var out = s.replacingOccurrences(of: "\\", with: "\\\\")
                out = out.replacingOccurrences(of: "'", with: "\\'")
                out = out.replacingOccurrences(of: "\n", with: "\\n")
                out = out.replacingOccurrences(of: "\r", with: "\\r")
                return out
            }
            let safeFirst = jsEscape(firstName)
            let safeLast = jsEscape(lastName)
            let safeEmail = jsEscape(email)
            let safeOems = jsEscape(oemsId)
            
            // Enhanced JavaScript with multiple detection strategies (data-itemName, label text, ID/name/placeholder heuristics)
            let js = """
            (function() {
                try {
                    function normalize(s) { return (s||'').toString().trim().toLowerCase(); }

                    function matchAny(subject, terms) {
                        if (!subject) return false;
                        subject = normalize(subject);
                        for (var i=0;i<terms.length;i++) {
                            if (subject.indexOf(terms[i]) !== -1) return true;
                        }
                        return false;
                    }

                    function findByDataItem(terms) {
                        var inputs = document.querySelectorAll('input[data-itemname], input[data-itemName]');
                        for (var i=0;i<inputs.length;i++) {
                            var v = inputs[i].getAttribute('data-itemname') || inputs[i].getAttribute('data-itemName') || '';
                            if (matchAny(v, terms)) return inputs[i];
                        }
                        return null;
                    }

                    function findByLabel(terms) {
                        var labels = document.querySelectorAll('label');
                        for (var i=0;i<labels.length;i++) {
                            var txt = labels[i].innerText || labels[i].textContent || '';
                            if (matchAny(txt, terms)) {
                                // try to find an input in the same form-group
                                var parent = labels[i].closest('.form-group') || labels[i].parentElement;
                                if (parent) {
                                    var input = parent.querySelector('input, textarea, select');
                                    if (input) return input;
                                }
                                // fallback: look for input by 'for' attribute
                                var fid = labels[i].getAttribute('for');
                                if (fid) {
                                    var el = document.getElementById(fid);
                                    if (el) return el;
                                }
                            }
                        }
                        return null;
                    }

                    function findByHeuristics(terms) {
                        var inputs = document.querySelectorAll('input, textarea');
                        for (var i=0;i<inputs.length;i++) {
                            var el = inputs[i];
                            var attrs = [el.id, el.name, el.placeholder, el.getAttribute('aria-label')].join(' ');
                            if (matchAny(attrs, terms)) return el;
                        }
                        return null;
                    }

                    var firstNameTerms = ['first name','firstname','first'];
                    var lastNameTerms = ['last name','lastname','last'];
                    var emailTerms = ['email','email address','e-mail'];
                    var oemsTerms = ['oems','nj oems id','nj oems','oems id','nj oems id*','nj oems'];

                    var firstNameField = findByDataItem(firstNameTerms) || findByLabel(firstNameTerms) || findByHeuristics(firstNameTerms);
                    var lastNameField = findByDataItem(lastNameTerms) || findByLabel(lastNameTerms) || findByHeuristics(lastNameTerms);
                    var emailField = findByDataItem(emailTerms) || findByLabel(emailTerms) || findByHeuristics(emailTerms);
                    var oemsField = findByDataItem(oemsTerms) || findByLabel(oemsTerms) || findByHeuristics(oemsTerms);

                    // Known-id fallback (legacy)
                    var knownIds = {
                        firstName: '62efdd5c-b397-4c79-86f2-849d9572a9e5',
                        lastName: '835aa3f1-e567-4d8e-a7e4-69a7feb5078f',
                        email: '12a627f7-72ac-4274-a068-055868eb9968',
                        oems: 'f8701da2-4473-48b4-8e11-231eb9ae0481'
                    };
                    if (!firstNameField) firstNameField = document.getElementById(knownIds.firstName);
                    if (!lastNameField) lastNameField = document.getElementById(knownIds.lastName);
                    if (!emailField) emailField = document.getElementById(knownIds.email);
                    if (!oemsField) oemsField = document.getElementById(knownIds.oems);

                    var fieldsFound = 0;
                    if (firstNameField) { firstNameField.value = '\(safeFirst)'; firstNameField.dispatchEvent(new Event('input',{bubbles:true})); firstNameField.dispatchEvent(new Event('change',{bubbles:true})); fieldsFound++; }
                    if (lastNameField) { lastNameField.value = '\(safeLast)'; lastNameField.dispatchEvent(new Event('input',{bubbles:true})); lastNameField.dispatchEvent(new Event('change',{bubbles:true})); fieldsFound++; }
                    if (emailField) { emailField.value = '\(safeEmail)'; emailField.dispatchEvent(new Event('input',{bubbles:true})); emailField.dispatchEvent(new Event('change',{bubbles:true})); fieldsFound++; }
                    if (oemsField) { oemsField.value = '\(safeOems)'; oemsField.dispatchEvent(new Event('input',{bubbles:true})); oemsField.dispatchEvent(new Event('change',{bubbles:true})); fieldsFound++; }

                    // Try to click the register button if present
                    setTimeout(function(){
                        var btn = document.getElementById('registerParticipantButton') || document.querySelector('button.btn-primary');
                        if (btn) { try{ btn.click(); }catch(e){} }
                    }, 300);

                    return JSON.stringify({success:true, fieldsFound: fieldsFound});
                } catch(e) { return JSON.stringify({success:false, error: e && e.message}); }
            })();
            """
            
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    AppDebugLog.log("[FlexiQuiz] ❌ Auto-fill error: \(error.localizedDescription)")
                } else if let jsonStr = result as? String {
                    AppDebugLog.log("[FlexiQuiz] ✅ Auto-fill result: \(jsonStr)")
                    
                    // Parse the result to see how many fields were found
                    if let data = jsonStr.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let fieldsFound = obj["fieldsFound"] as? Int {
                            if fieldsFound < 4 {
                                AppDebugLog.log("[FlexiQuiz] ⚠️ Warning: Only \(fieldsFound)/4 fields were auto-filled")
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.parent.hasAutoFilled = true
                    self.parent.isLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            AppDebugLog.log("[FlexiQuiz] ❌ Navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

// FlexiQuizView uses the central `QuizInfo` model defined in `QuizModels.swift`.
