import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourcePath = `${repo}/docs/flexiquiz/refresher-c-version-b-source.json`;
const workbookPath = `${repo}/docs/flexiquiz/refresher-c-version-b-flexiquiz-import.xlsx`;
const outputPath = `${repo}/outputs/refresher-c-version-b-flexiquiz-import/refresher-c-version-b-flexiquiz-import.xlsx`;

const questionTextOverrides = {
  1: "For an adult trauma patient, a fall from which height is considered a significant mechanism of injury?",
  2: "When evaluating the severity of a fall, which factor should be considered along with the height of the fall?",
  3: "Battle signs and raccoon eyes are late findings associated with which injury?",
  6: "A patient described as prone is lying in which position?",
  7: "Which statement best defines mechanism of injury?",
  8: "A hot, bruised, tender abdomen after trauma becomes especially concerning for internal bleeding when it is also:",
  10: "An EMT's concern for potentially serious hidden injuries based on mechanism and presentation is called:",
  12: "Which description matches the standard anatomical position?",
  14: "Best practice for applying physical restraints is to have at least how many trained personnel present?",
  15: "Mechanical restraints may be indicated when a medical patient is also:",
  16: "When removing a child from a car seat, how should the child's head be maintained?",
  17: "According to CDC trauma triage guidance, a systolic blood pressure below what value should prompt trauma center consideration?",
  18: "An unrestrained front-seat passenger strikes his face on the dashboard during a high-speed crash. Abnormal movement of the maxilla should make the EMT suspect a:",
  24: "A trauma patient being transported to a community hospital becomes increasingly confused, develops irregular respirations, becomes bradycardic, and has rising blood pressure. A trauma center is only a few minutes farther away. What is the best transport decision?",
  25: "An unresponsive 14-year-old was run over by a tractor. Clear drainage from which location would raise concern for a serious skull injury?",
  26: "A 9-year-old bicyclist struck by a car has pale, cool skin, abdominal tenderness, and an angulated forearm injury with distal pulses present. After spinal motion restriction, what should the EMT do?",
  30: "After properly assessing and stabilizing a patient, driving to the hospital with excessive speed will most likely:",
  33: "A 32-year-old who fell 20 feet has snoring respirations, multiple fractures, and profuse arterial bleeding from the radial artery. Which injury is the highest priority?",
  34: "A motorcycle rider thrown from the bike is unresponsive with snoring respirations after a high-risk crash. Which action should the EMT perform first?",
  35: "An unresponsive 10-year-old struck by a car has snoring respirations, cyanosis, and manual cervical spine stabilization already in place. What should the EMT do next?",
  36: "What trauma triage transport category is generally appropriate for an isolated finger amputation?",
  37: "When choosing a destination for a patient in hypovolemic shock or at high risk for shock, which hospital capability is most important?",
  38: "Which phrase best describes proper head position during spinal motion restriction?",
  39: "Which finding is characteristic of arterial bleeding?",
  40: "A 33-year-old with a gunshot wound to the leg has active, steady, dark red bleeding and signs of early shock. Which treatment sequence is most appropriate?",
  41: "A 12-year-old's forearm laceration continues bleeding through a pressure dressing and bandage. What should the EMT do next?",
  45: "In a nerve-agent incident, a patient responds to pain, has an open airway, breathes 8 times per minute, has a weak radial pulse, wheezing, and pinpoint pupils. What should the EMT do first?",
  46: "During START triage, a patient is breathing 24 times per minute. What is the next assessment step?",
  47: "While triaging patients after an explosion at an outdoor concert venue, what safety concern should responders continue to monitor for?",
  48: "START triage relies on simple commands and which three physiologic parameters?",
  49: "At the start of triage after a commuter train derailment, what should the EMT do first?",
  50: "In START triage, patients who can walk to a designated area are initially categorized as:"
};

function cleanText(value) {
  return String(value ?? "")
    .replace(/<[^>]*>/g, " ")
    .replace(/[“”]/g, "\"")
    .replace(/[‘’]/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function cleanQuestionText(question) {
  const override = questionTextOverrides[question.combinedQuestionNumber];
  if (override) return override;

  let text = cleanText(question.originalObjectiveText || question.text);
  text = text.replace(/\bapp?ropirate\b/gi, "appropriate");
  text = text.replace(/\bLaying\b/g, "Lying");
  text = text.replace(/\bStating upright\b/g, "Standing upright");
  text = text.replace(/\s+:/g, ":");
  if (text.endsWith(":")) {
    text = `${text.slice(0, -1)}?`;
  }
  return text;
}

function cleanOptionText(value) {
  return cleanText(value)
    .replace(/\bLaying\b/g, "Lying")
    .replace(/\bStating upright\b/g, "Standing upright")
    .replace(/\bapp?ropirate\b/gi, "appropriate");
}

function cleanFeedback(value) {
  return cleanText(value)
    .replace(/^Correct answer:\s*[^.]+(?:\.\s*)?/i, "")
    .replace(/\bThis is the answer that most directly addresses the EMT-level assessment or treatment decision in the prompt\.\s*/gi, "")
    .replace(/\bThe other options may be plausible distractors, but they do not best match the clinical priority or definition being tested\.\s*/gi, "")
    .replace(/\bOn retest, focus on identifying the key assessment finding and matching it to the safest field action\.\s*/gi, "")
    .replace(/\bThe rationale is tied to recognizing the critical clue and choosing the answer that preserves patient safety\.\s*/gi, "")
    .replace(/\bThis item reinforces the same competency from Version A while requiring the student to reason through a new stem\.\s*/gi, "")
    .replace(/\s*Objective link:\s*.*$/i, "")
    .trim();
}

function rowForQuestion(question) {
  const options = question.options.map((option) => ({
    ...option,
    text: cleanOptionText(option.text)
  }));
  const row = [
    cleanQuestionText(question),
    "Single Choice (Radio Button)",
    "Question points",
    question.points ?? 1,
    1,
    "Yes",
    cleanFeedback(question.feedback),
    "Refresher C, Refresher C Version B, Class Manager App",
    "Yes"
  ];

  for (let index = 0; index < 10; index += 1) {
    const option = options[index];
    row.push(option?.text ?? null);
    row.push(option ? (option.correct ? "Yes" : "No") : null);
    row.push(null);
  }
  return row;
}

const source = JSON.parse(await fs.readFile(sourcePath, "utf8"));
const questions = source.segments.flatMap((segment) => segment.questions);

for (const question of questions) {
  question.text = cleanQuestionText(question);
  question.feedback = cleanFeedback(question.feedback);
  question.options = question.options.map((option) => ({
    ...option,
    text: cleanOptionText(option.text)
  }));
}

source.generatedAt = new Date().toISOString();
source.title = "Refresher C - Class Manager App - Version B";
source.totalQuestions = questions.length;
await fs.writeFile(sourcePath, `${JSON.stringify(source, null, 2)}\n`);

const input = await FileBlob.load(workbookPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const sheet = workbook.worksheets.getItem("Template - v1.1");
const rows = questions.map(rowForQuestion);

sheet.getRangeByIndexes(2, 0, rows.length, 39).values = rows;
sheet.getRange("A3:A52").format.wrapText = true;
sheet.getRange("G3:G52").format.wrapText = true;
sheet.getRange("A:A").format.columnWidth = 80;
sheet.getRange("G:G").format.columnWidth = 70;
sheet.getRange("J:J").format.columnWidth = 42;
sheet.getRange("M:M").format.columnWidth = 42;
sheet.getRange("P:P").format.columnWidth = 42;
sheet.getRange("S:S").format.columnWidth = 42;
sheet.getRange("A3:AM52").format.autofitRows();

await fs.mkdir(`${repo}/outputs/refresher-c-version-b-flexiquiz-import`, { recursive: true });
const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(workbookPath);
await exported.save(outputPath);

const promptScan = questions.filter((question) => /retest|remediation|retesting|version a|second-version|for the retest bank/i.test(question.text));
const feedbackScan = questions.filter((question) => /correct answer|objective link|keyed answer|retest|version a|this is the answer/i.test(question.feedback));
if (promptScan.length || feedbackScan.length) {
  throw new Error(`Quality scan failed: prompts=${promptScan.length}, feedback=${feedbackScan.length}`);
}

console.log(JSON.stringify({
  sourcePath,
  workbookPath,
  outputPath,
  questions: questions.length
}, null, 2));
