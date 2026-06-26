# Refresher A Combined Exam Workflow

## Source Files

- `refresher-a-combined-source.json`: canonical source extracted from RMS `flexiquiz_exam_results.response_questions_json`.
- `refresher-a-combined-generic.csv`: neutral CSV for review or remapping into the FlexiQuiz CSV template.

The current source contains 50 questions:

- Page 1 / Refresher A - 1: 12 questions
- Page 2 / Refresher A - 2: 13 questions
- Page 3 / Refresher A - 3: 13 questions
- Page 4 / Refresher A - 4: 12 questions

## FlexiQuiz API Finding

Live API probe against the four Refresher A mini quiz IDs showed:

- `GET /v1/quizzes/{quiz_id}` returns only quiz metadata.
- `GET /v1/quizzes/{quiz_id}/questions` returns 404.
- `GET /v1/quizzes/{quiz_id}/pages` returns 404.
- `GET /v1/quizzes/{quiz_id}/items` returns 404.

So question source should come from RMS webhook/response payloads unless FlexiQuiz provides a separate import/create endpoint or CSV import template.

## Segment Hook Concept

The FlexiQuiz theme screen has a custom JavaScript box and a `Run JavaScript on page navigation` option. For the app workflow, the safest first test is to make the JavaScript notify the iOS app, not block navigation.

Preferred in-app bridge:

```js
(function () {
  var payload = {
    type: "classmanager.flexiquiz.pageNavigation",
    href: String(window.location.href || ""),
    title: String(document.title || ""),
    textHint: String((document.body && document.body.innerText) || "").slice(0, 500),
    at: new Date().toISOString()
  };

  try {
    if (window.webkit &&
        window.webkit.messageHandlers &&
        window.webkit.messageHandlers.classmanagerFlexiQuiz) {
      window.webkit.messageHandlers.classmanagerFlexiQuiz.postMessage(payload);
    }
  } catch (_) {}
})();
```

This lets the Swift `WKWebView` detect page changes and decide whether to close the quiz surface and show the segment review. It avoids CORS, avoids exposing a static webhook token inside FlexiQuiz, and keeps the app in control.

If the in-app bridge is not available, a network beacon can be tested later, but it will need a safe way to identify the student/session without hard-coding a reusable secret in the quiz.
