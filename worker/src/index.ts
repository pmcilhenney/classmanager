export interface Env {
  DB: D1Database;
  ARTIFACTS: R2Bucket;
  ASSETS: Fetcher;
  AI?: Ai;
  ENVIRONMENT: string;
  JOTFORM_BASE_URL: string;
  JOTFORM_API_KEY?: string;
  FLEXIQUIZ_API_BASE: string;
  FLEXIQUIZ_AUTH_URL: string;
  FLEXIQUIZ_API_KEY?: string;
  FLEXIQUIZ_SSO_SHARED_SECRET?: string;
  SM_BASE_URL: string;
  SM_AUTH: string;
  SM_SEND_EMAIL: string;
  SM_USERNAME?: string;
  SM_PASSWORD?: string;
  FROM_ADDRESS?: string;
  REPLY_TO_ADDRESS?: string;
  ACADEMY_RMS_BASE_URL?: string;
  ACADEMY_RMS_ATTENDANCE_SECRET?: string;
  APNS_KEY?: string;
  APNS_PRIVATE_KEY?: string;
  APNS_KEY_ID?: string;
  APNS_TEAM_ID?: string;
  APNS_BUNDLE_ID?: string;
}

type JsonRecord = Record<string, unknown>;

type NormalizedAttendee = {
  submissionId: string;
  firstName: string;
  lastName: string;
  email: string;
  oemsId: string;
  courseType: string;
  courseDate?: string;
  courseId?: string;
  ceuValue?: string;
  productCategories?: string[];
  dob?: string;
  courseImageURL?: string;
  courseLocation?: string;
};

type SessionOption = {
  courseType: string;
  datePretty: string;
  dateRaw: string;
  courseId?: string;
  ceuValue?: string;
  productCategories?: string[];
  courseImageURL?: string;
  courseLocation?: string;
};

type InstructorCourse = {
  id: string;
  classSessionId: string;
  courseId?: string;
  title: string;
  date: string;
  displayDate?: string;
  location?: string;
  expectedCount: number;
  isToday: boolean;
  alwaysInclude?: boolean;
};

type InstructorProfile = {
  personId: string;
  fullName: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  oemsId?: string;
};

type QuizReviewQuestion = {
  id?: string;
  number: number;
  prompt: string;
  choices?: string[];
  studentAnswer?: string;
  correctAnswer?: string;
  isCorrect?: boolean;
  feedback?: string;
  points?: string;
};

type QuizReviewPayload = {
  ok: true;
  quizId: string;
  responseId?: string;
  resultText?: string;
  scoreText?: string;
  passed?: boolean;
  completedAt?: string;
  reportUrl?: string;
  questions: QuizReviewQuestion[];
  warnings: string[];
};

const REFRESHER_A_COMBINED_QUIZ_ID = "89db2c06-5052-4ff5-867b-95ef67fcfcd2";
const REFRESHER_B_COMBINED_QUIZ_ID = "bcab075c-a56a-459c-b313-f7b3966d7bb4";
const REFRESHER_C_COMBINED_QUIZ_ID = "7f21b940-8344-4614-a935-49f2ea4218c7";
const REFRESHER_A_VERSION_B_QUIZ_ID = "a08bbc93-3c52-4ea9-9bbb-e9c2de39266b";
const REFRESHER_B_VERSION_B_QUIZ_ID = "76483815-190a-4c67-89ff-2e69c74b0c2a";
const REFRESHER_C_VERSION_B_QUIZ_ID = "36088669-4530-48b8-ae82-1f549009d380";
const REFRESHER_VERSION_A_PASSING_SCORE = 74;
const REFRESHER_VERSION_B_PASSING_SCORE = 80;
const REGISTRATION_FORM_ID = "251265925097060";
const INSTRUCTOR_PAST_COURSE_DAYS = 45;
const INSTRUCTOR_UPCOMING_COURSE_DAYS = 120;
const INSTRUCTOR_MAX_COURSES = 60;
const INSTRUCTOR_INCLUDED_SUBMISSION_IDS = new Set([
  "6406705846326091703"
]);
const KNOWN_QUESTION_RATIONALES_BY_QUIZ: Record<string, Record<string, string>> = {
  [REFRESHER_A_COMBINED_QUIZ_ID]: {
    "what is the sound of the soft tissue of the upper airway creating impedance or partial obstruction to the flow of air": "Correct answer: Snoring. Snoring is caused by relaxed soft tissue partially obstructing the upper airway, so repositioning and airway support should stay front of mind.",
    "which of the following structures is not found in the upper airway": "Correct answer: Bronchus. The bronchi are part of the lower airway; upper-airway structures are above the larynx and trachea.",
    "you are ventilating an 85 year old male without difficulty a nurse tells you that the patient has dentures to ensure a good mask seal you should": "Correct answer: Leave the dentures in place. Dentures can help maintain facial structure and improve a mask seal when they are secure and ventilation is effective.",
    "your patient is breathing 4 shallow breaths per minute due to overdosing on his pain medication but he has a palpable radial pulse he vomited prior to your arrival and is choking you should": "Correct answer: Roll him onto his side to clear the airway. Positioning the patient on the side helps drain vomitus and protects the airway before assisted ventilations continue.",
    "which of the following is a disadvantage of oropharyngeal airways opas": "Correct answer: They cannot be used in a patient with a gag reflex. An OPA is only appropriate when the gag reflex is absent; otherwise it can trigger vomiting or airway complications.",
    "the high pitched sound caused by an upper airway obstruction is known as": "Correct answer: Stridor. Stridor is a high-pitched upper-airway sound and should be treated as a warning sign for significant airway narrowing.",
    "which of the following structures is found in the lower airway": "Correct answer: Bronchi. The bronchi are part of the lower airway; upper-airway structures are above the larynx and trachea.",
    "you have performed a head tilt chin lift maneuver on a 17 month old boy and are attempting to ventilate him with a bag valve mask you are experiencing a lot of resistance with each breath and the chest is barely rising prior to attempting ventilations again you should": "Correct answer: Ease the head forward a little to re-position the airway. Pediatric airway positioning is sensitive; overextension can obstruct the airway, so a small repositioning change may restore chest rise.",
    "which of the following gases increases during respiratory failure": "Correct answer: Carbon dioxide. Ventilatory failure causes carbon dioxide retention, which is why ventilation status matters along with oxygenation.",
    "on which of the following types of calls should you bring your portable suction unit to the patient s side upon arrival on the scene": "Correct answer: All of the above. Positioning the patient on the side helps drain vomitus and protects the airway before assisted ventilations continue.",
    "which of the following is the correct method of suctioning": "Correct answer: Insert the catheter or tip to the desired depth prior to applying suction. Suction should be ready for patients at risk for secretions, blood, or vomit, and suction is applied while withdrawing the catheter.",
    "when inserting an oropharyngeal airway how many degrees do you need to rotate the airway so the tip is pointing down into the patient s pharynx": "Correct answer: 180. An OPA is only appropriate when the gag reflex is absent; otherwise it can trigger vomiting or airway complications.",
    "your patient is a 55 year old man with a history of chronic bronchitis you have been called to his home today because of an increase in his level of respiratory distress the patient is on 2 liters per minute of oxygen by nasal cannula at home your assessment reveals difficulty speaking due to shortness of breath leaning forward to breathe a productive cough and a respiratory rate of 32 per minute which of the following is true concerning the best course of action for this patient": "Correct answer: You should increase the patient's oxygen flow rate to deliver adequate amounts of oxygen to his tissues. The bronchi are part of the lower airway; upper-airway structures are above the larynx and trachea.",
    "what is the danger that an altered mental status can pose to a patient s breathing": "Correct answer: Loss of muscle tone and airway collapse. Altered mental status can relax airway muscles and allow the tongue or soft tissue to obstruct the airway.",
    "what device is used to perform mouth to mask ventilation": "Correct answer: Pocket face mask. A pocket face mask provides a barrier and better seal for mouth-to-mask ventilations.",
    "a 16 year old patient presents with labored breathing and increased respiratory rate increased heart rate and leaning forward with his hands on his knees his skin is a normal color and his pulse oximetry is 96 this patient is suffering from respiratory": "Correct answer: Distress. After confirming unresponsiveness, quickly assess breathing and pulse to decide whether ventilations, CPR, or both are needed.",
    "when does respiratory distress change to respiratory failure": "Correct answer: When continuation of a respiratory challenge results in the systems being unable to keep up with the demand, and the skin color and mental status change. Ventilatory failure causes carbon dioxide retention, which is why ventilation status matters along with oxygenation.",
    "you have arrived at the scene of a call for a man down as you enter the residence you note that your patient is a male in his mid 60s who is awake but does not seem to acknowledge your presence he is perspiring profusely has cyanosis of his ears and lips and has rapid shallow respirations which of the following should you do first": "Correct answer: Assist ventilations with a bag-valve mask and supplemental oxygen. Positioning the patient on the side helps drain vomitus and protects the airway before assisted ventilations continue.",
    "when you question an edlerly woman with a respiratory complaint she speaks in short two or 3 word sentences is this signifigant": "Correct answer: Yes, she is probably very short of breath. Speaking only a few words at a time is a practical sign of increased work of breathing.",
    "cpap is indicated for patients who": "Correct answer: Have pulmonary edema and can follow verbal commands. CPAP is useful for selected alert patients, especially pulmonary edema, because pressure helps keep alveoli open.",
    "how does cpap improve oxygenation and ventilation in patients with certain respiratory problems": "Correct answer: It prevents alveolar collapse by pushing air into the lungs during inhalation. CPAP is useful for selected alert patients, especially pulmonary edema, because pressure helps keep alveoli open.",
    "for which of the following conditions is albuterol prescribed": "Correct answer: Asthma. Albuterol is a bronchodilator used for bronchospasm, commonly in asthma.",
    "typically the highest continuous positive airway pressure cpap pressure used by the emt without special permission from medical direction is": "Correct answer: 10 cmH2O. CPAP is useful for selected alert patients, especially pulmonary edema, because pressure helps keep alveoli open.",
    "a 12 year old female patient is having an asthma attack after participating in some strenuous activity during recess at school she s taken several doses of her own bronchodilator with little relief your partner immediately administers oxygen providing supplemental oxygen will increase the amount of oxygen molecules carried by the in her blood helping oxygenate critical organs like the brain": "Correct answer: Hemoglobin. When respiratory distress is present, oxygen should be titrated to meet tissue oxygen needs rather than withheld because of chronic lung disease.",
    "you are ventilating an adult patient with a bag valve mask when you notice that his abdomen is getting bigger you should": "Correct answer: Apply cricoid pressure. Cyanosis with shallow respirations calls for assisted ventilations with high-flow oxygen.",
    "the first rule of safe lifting is to": "Correct answer: Keep your back in a straight, vertical position. Safe lifting starts with a straight, vertical back and using leg strength instead of bending at the waist.",
    "which of the following best describes body mechanics": "Correct answer: Proper use of the body to facilitate lifting and moving objects. Body mechanics means using posture, balance, and coordinated movement to lift and move safely.",
    "during an emergency move which of the following techniques should be used whenever possible to minimize the possibility of further aggravating a possible spinal injury": "Correct answer: Move the patient in the direction of the long axis of the body. Moving along the long axis reduces twisting and helps limit additional spinal movement during urgent moves.",
    "when moving a conscious weak patient down a flight of stairs you should": "Correct answer: Secure the patient to a scoop stretcher and carry him or her feet first down the stairs to the awaiting stretcher. Stair movement requires the right device, secure patient positioning, and clear communication before the move starts.",
    "when transporting a patient to the hospital you should": "Correct answer: Be safe and get the patient to the hospital in the shortest practical time. Transport should balance urgency with safety; the shortest practical time is not the same as reckless speed.",
    "the term body mechanics describes the proper use of your body to lift without injury what are the three considerations to review before any lift": "Correct answer: The object, your limitations, and communication. Positioning the patient on the side helps drain vomitus and protects the airway before assisted ventilations continue.",
    "when a stretcher with a patient secured to it is elevated what occurs": "Correct answer: The center of gravity is raised and this increases the tip hazard. Raising a stretcher raises the center of gravity, increasing the chance of tipping if the team is not careful.",
    "which of the following devices should be used to carry a patient down the stairs whenever possible": "Correct answer: Stair chair. Stair movement requires the right device, secure patient positioning, and clear communication before the move starts.",
    "why do you hear rales when you auscultate the lungs of a patient who has pulmonary edema": "Correct answer: The alveoli pop open with each inspiration. CPAP is useful for selected alert patients, especially pulmonary edema, because pressure helps keep alveoli open.",
    "an unresponsive 94 year old female was found by her husband in bed he tells you that she has a history of diabetes you do not observe chest rise or air movement but she has a pulse you should first": "Correct answer: Ventilate her with a BVM. Cyanosis with shallow respirations calls for assisted ventilations with high-flow oxygen.",
    "you are moving an elderly patient down the stairs using a stair chair the patient is alert and very anxious what should you do prior to moving the patient to prevent her from grabbing the railing and causing you to fall": "Correct answer: Explain to the patient what you are doing and advise her to hold her hands together and not let go until you are finished moving her. Stair movement requires the right device, secure patient positioning, and clear communication before the move starts.",
    "you and your partner arrive on the scene of a 400 pound patient lying in bed he complains of nausea and vomiting for the past 3 days when he tries to sit up he gets very dizzy and has a syncopal episode realizing that he cannot assist you in getting on the stretcher you decide to do which of the following": "Correct answer: Call for additional manpower to safely move the patient. Positioning the patient on the side helps drain vomitus and protects the airway before assisted ventilations continue.",
    "which device is appropriate for moving a patient with a suspected pelvic injury": "Correct answer: Scoop stretcher. Stair movement requires the right device, secure patient positioning, and clear communication before the move starts.",
    "you are performing abdominal thrusts on a choking adult when they suddenly lose consciousness you should next": "Correct answer: Begin CPR. Positioning the patient on the side helps drain vomitus and protects the airway before assisted ventilations continue.",
    "during 2 rescuer child cpr the compression to ventilation ratio should be": "Correct answer: 15:2. Two-rescuer child CPR uses a 15:2 compression-to-ventilation ratio to provide more frequent ventilations.",
    "during 1 rescuer adult cpr the compression rate should be": "Correct answer: 100-120. Adult CPR compressions should be delivered at 100 to 120 per minute with adequate depth and recoil.",
    "you and your emt partner are preparing to ventilate an elderly non trauma patient who has a stoma your partner performs the head tilt chin lift maneuver and you ask him to return the patient s head to a neutral position why this is not a pediatric patient your partner protests what would you say": "Correct answer: It is not necessary to position the airway of a stoma breather when providing ventilations. Pediatric airway positioning is sensitive; overextension can obstruct the airway, so a small repositioning change may restore chest rise.",
    "you are transporting a 44 year old female with chest pain and sudden respiratory distress she is agitated anxious and refuses to have a nonrebreather mask applied which of the following is the best option": "Correct answer: Use a nasal cannula instead. Respiratory distress means the patient is working harder but is still compensating; watch closely for mental-status or skin-color changes.",
    "which of these patients would require a tracheostomy mask for supplemental oxygen administration": "Correct answer: A patient with a stoma. Patients breathing through a stoma need ventilation or oxygen delivery through the stoma rather than the mouth and nose.",
    "after establishing that an adult patient is unresponsive you should": "Correct answer: Assess for breathing and a pulse. After confirming unresponsiveness, quickly assess breathing and pulse to decide whether ventilations, CPR, or both are needed.",
    "during the primary assessment of an unresponsive two month old infant which pulse should be palpated": "Correct answer: Brachial. After confirming unresponsiveness, quickly assess breathing and pulse to decide whether ventilations, CPR, or both are needed.",
    "a 60 year old man is found to be unresponsive pulseless and apneic you should": "Correct answer: Begin CPR immediately and use an AED as soon as it becomes available. If a choking patient becomes unresponsive, begin CPR and check the airway during the resuscitation sequence.",
    "cpr will not be effective if the patient is": "Correct answer: Prone. Effective CPR requires the patient to be supine on a firm surface so compressions can generate blood flow.",
    "in most cases cardiopulmonary arrest in infants and children is caused by": "Correct answer: Respiratory arrest. Pediatric cardiac arrest is often secondary to respiratory failure or arrest, making airway and ventilation assessment critical.",
    "what is the correct ratio of compressions to ventilations when performing two rescuer adult cpr": "Correct answer: 30:2. Two-rescuer adult CPR uses a 30:2 compression-to-ventilation ratio.",
  },
  [REFRESHER_A_VERSION_B_QUIZ_ID]: {
    "a patient is found supine with noisy snoring respirations after a syncopal episode what should you do first to improve the airway": "Correct answer: Reposition the head and open the airway. Snoring respirations usually mean relaxed upper-airway tissue is partially obstructing airflow, so manual airway positioning is the first priority.",
    "during assessment you hear a wet bubbling sound from the patient s mouth with each breath which airway problem is most likely present": "Correct answer: Fluid or secretions in the upper airway. Gurgling indicates material in the airway and should prompt suctioning to clear blood, vomitus, or secretions.",
    "which finding best indicates that an oropharyngeal airway is inappropriate": "Correct answer: The patient gags when the device is inserted. An OPA is used only when the gag reflex is absent because it can trigger vomiting or airway complications.",
    "you are sizing an oropharyngeal airway for an adult which measurement is most appropriate": "Correct answer: From the corner of the mouth to the angle of the jaw. Proper sizing helps the OPA hold the tongue forward without pushing it deeper into the airway.",
    "a conscious patient with an intact gag reflex needs an airway adjunct which device is usually more appropriate if not contraindicated": "Correct answer: Nasopharyngeal airway. NPAs are generally better tolerated in conscious or semiconscious patients with an intact gag reflex, unless contraindications are present.",
    "which patient finding is most concerning for a rapidly developing upper airway obstruction": "Correct answer: High-pitched stridor heard during breathing. Stridor is an upper-airway warning sign and can indicate significant narrowing that may worsen quickly.",
    "when ventilating a patient with dentures that are secure and improving facial structure what should you generally do": "Correct answer: Leave the dentures in place during mask ventilation. Secure dentures may improve facial contour and help maintain an effective mask seal.",
    "a pediatric patient becomes harder to ventilate after the head is tilted far backward what is the best next adjustment": "Correct answer: Return the head toward a neutral or sniffing position. Pediatric airways can obstruct with overextension, so small position changes may restore airway alignment.",
    "which structure is part of the lower airway": "Correct answer: Alveoli. The lower airway includes structures below the larynx and trachea, including bronchi, bronchioles, and alveoli.",
    "a patient vomits while you are preparing to ventilate what action best protects the airway first": "Correct answer: Roll the patient onto the side and suction as needed. Positioning and suctioning help clear vomitus and reduce the risk of aspiration before assisted ventilations continue.",
    "a patient with respiratory distress is sitting upright speaking two word phrases and using accessory muscles what does this pattern suggest": "Correct answer: Increased work of breathing with limited ventilatory reserve. Short phrases and accessory-muscle use are practical signs that the patient is working hard to breathe.",
    "which change most strongly suggests respiratory distress is progressing toward respiratory failure": "Correct answer: Declining mental status and worsening skin signs. Failure occurs when compensatory mechanisms cannot meet demand, often shown by mental-status and perfusion changes.",
    "a copd patient at home on low flow oxygen is now severely short of breath and cyanotic what is the best oxygen approach": "Correct answer: Provide enough oxygen to correct hypoxia and monitor closely. EMT care prioritizes adequate oxygenation when hypoxia or severe distress is present.",
    "which medication is intended to relieve bronchospasm in an asthma patient": "Correct answer: Albuterol. Albuterol is a bronchodilator used for bronchospasm, commonly in asthma or reactive airway disease.",
    "cpap is most appropriate for which patient": "Correct answer: An alert patient with pulmonary edema who can follow commands. CPAP requires an appropriate, breathing patient who can tolerate the mask and benefit from positive pressure.",
    "how does cpap help many patients with pulmonary edema": "Correct answer: It helps keep alveoli open and improves oxygen exchange. Positive pressure can reduce alveolar collapse and improve oxygenation in selected patients.",
    "a patient has a pulse but is breathing 5 times per minute with poor chest rise what is the priority intervention": "Correct answer: Assist ventilations with a bag-valve mask and oxygen. A very slow rate with poor chest rise means ventilation is inadequate even when a pulse is present.",
    "a patient receiving bvm ventilations develops gastric distention which correction is most appropriate": "Correct answer: Ventilate only until visible chest rise is achieved. Excessive volume or force can push air into the stomach; effective ventilations use just enough volume for chest rise.",
    "what does pulse oximetry fail to directly measure": "Correct answer: Ventilation and carbon dioxide removal. Pulse oximetry estimates oxygen saturation but does not prove adequate ventilation or CO2 clearance.",
    "a patient is cyanotic diaphoretic and breathing rapidly but shallowly which concern should be highest": "Correct answer: Inadequate ventilation despite a fast respiratory rate. Rapid shallow breathing may not move enough tidal volume and can progress to respiratory failure.",
    "before suctioning the mouth of a patient with secretions what should you do with the catheter or rigid tip": "Correct answer: Insert to the needed depth before applying suction while withdrawing. Applying suction mainly during withdrawal helps clear material while reducing trauma and hypoxia risk.",
    "which situation should make you bring suction to the patient s side early": "Correct answer: Any patient at risk for blood, vomit, or secretions in the airway. Early suction readiness prevents delays when the airway fills with material.",
    "a patient breathes through a permanent stoma and needs oxygen what delivery route should you prioritize": "Correct answer: Apply oxygen over the stoma. A stoma breather ventilates through the neck opening, so oxygen or ventilations must be directed there.",
    "when ventilating a stoma breather which statement is correct": "Correct answer: Head tilt is not needed to open the airway through the stoma. Airflow bypasses the upper airway, so care focuses on sealing and ventilating through the stoma.",
    "a pocket mask is best described as a device that": "Correct answer: Provides a barrier and supports mouth-to-mask ventilation. A pocket mask improves safety and seal compared with direct mouth-to-mouth ventilation.",
    "what body position principle best protects an emt during a lift": "Correct answer: Keep the back straight and lift with the legs. Safe lifting keeps the load close, back straight, and power coming from the legs.",
    "which factor should be considered before lifting a patient or stretcher": "Correct answer: The object, your limitations, and communication with partners. Planning a lift reduces injury risk by matching the task, team, and communication before movement starts.",
    "why does raising a loaded stretcher increase risk": "Correct answer: The center of gravity rises and tipping becomes more likely. A higher center of gravity makes the stretcher less stable, especially during turns or uneven movement.",
    "which move is preferred to reduce twisting of a patient with a possible spine injury during an emergency move": "Correct answer: Move the patient in line with the long axis of the body. Long-axis movement limits twisting and helps reduce additional spinal motion during urgent movement.",
    "a bariatric patient cannot assist with transfer from bed to stretcher what should you do": "Correct answer: Request adequate additional help and equipment. Safe bariatric movement requires enough trained personnel and equipment to prevent injury to the patient and crew.",
    "when using a stair chair what helps prevent an anxious patient from grabbing the railing": "Correct answer: Explain the move and tell the patient where to keep their hands. Clear instructions and secure positioning reduce sudden movements that can endanger the crew.",
    "which device is generally preferred for carrying a seated patient down stairs when appropriate": "Correct answer: Stair chair. Stair chairs are designed to move appropriate patients on stairs with better control and ergonomics.",
    "transporting with due regard means you should": "Correct answer: Choose the shortest practical safe route without reckless driving. Emergency transport still requires patient, crew, and public safety.",
    "which statement best defines body mechanics": "Correct answer: Using the body efficiently and safely to lift and move. Body mechanics focuses on posture, balance, coordination, and avoiding preventable injury.",
    "for a patient with a suspected pelvic injury who must be moved which device may help minimize movement while allowing transfer": "Correct answer: Scoop stretcher. A scoop stretcher can separate and reassemble around the patient, reducing unnecessary movement during transfer.",
    "an adult choking patient becomes unresponsive while you are providing care what should you do next": "Correct answer: Begin CPR and check the airway during the sequence. Once a choking patient becomes unresponsive, care transitions to CPR with airway checks during ventilations.",
    "for one rescuer adult cpr which compression to ventilation ratio is used": "Correct answer: 30:2. Adult CPR uses a 30:2 compression-to-ventilation ratio for one rescuer and also for two rescuers in standard BLS.",
    "for two rescuer child cpr which compression to ventilation ratio is used": "Correct answer: 15:2. Two-rescuer child CPR uses more frequent ventilations because pediatric arrests are commonly respiratory in origin.",
    "what compression rate should be used during adult cpr": "Correct answer: 100 to 120 per minute. Effective CPR requires compressions at 100 to 120 per minute with adequate depth and full recoil.",
    "after confirming an adult patient is unresponsive what should you assess next": "Correct answer: Breathing and pulse. The next decision is whether the patient needs ventilations, compressions, or both.",
    "which pulse is typically checked during the primary assessment of an unresponsive infant": "Correct answer: Brachial pulse. The brachial pulse is the preferred pulse check location for infants during BLS assessment.",
    "what is the most common underlying cause of cardiac arrest in infants and children": "Correct answer: Respiratory failure or arrest. Pediatric cardiac arrest is often secondary to respiratory problems, so airway and ventilation are especially important.",
    "cpr compressions are least effective when the patient is": "Correct answer: Prone. Effective compressions require the patient to be supine on a firm surface so force can generate blood flow.",
    "an adult is unresponsive pulseless and apneic what should happen as soon as possible": "Correct answer: Begin CPR and apply an AED when available. Early CPR and early defibrillation are core priorities for cardiac arrest.",
    "which action best supports high quality cpr": "Correct answer: Allow full chest recoil after each compression. Full recoil improves venous return and supports blood flow during CPR.",
    "a patient with chest pain refuses a nonrebreather mask but is willing to accept oxygen by another route what should you do": "Correct answer: Use a nasal cannula if clinically appropriate and continue assessment. When a patient cannot tolerate a mask, a nasal cannula may provide supplemental oxygen while preserving cooperation.",
    "which sign suggests a patient may be tiring from respiratory distress": "Correct answer: Decreasing responsiveness with continued abnormal breathing. Fatigue and mental-status decline are warning signs that distress may be progressing to failure.",
    "a patient has pulmonary edema and is alert but anxious which feature must be present before cpap is used": "Correct answer: The patient can follow commands and maintain their own airway. CPAP requires cooperation and airway control because the patient must tolerate positive pressure.",
    "which statement about supplemental oxygen is most accurate": "Correct answer: Oxygen delivery should be matched to the patient's clinical condition and response. Oxygen is a treatment guided by patient presentation, oxygenation, ventilation, and local protocol.",
    "during bvm ventilation what confirms that each breath is likely effective": "Correct answer: Visible chest rise with each ventilation. Chest rise is a key sign that air is entering the lungs with adequate volume.",
  }
};

type FinalExamResult = {
  quizId: string;
  quizName?: string;
  responseId?: string;
  scoreText?: string;
  resultText?: string;
  passed?: boolean;
  completedAt?: string;
  reportUrl?: string;
  percentageScore?: number;
  points?: number;
  availablePoints?: number;
};

type StudentCommentAnalytics = {
  averageScore?: number;
  completedQuizCount: number;
  passedQuizCount: number;
  strongestTopics: string[];
  growthTopics: string[];
  quizSummaries: string[];
};

type FlexiUserProfile = {
  userId: string;
  userName: string;
  email?: string;
  quizzes: JsonRecord[];
};

const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store"
};

let cachedApnsJwt = "";
let cachedApnsJwtExp = 0;

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders(request) });
    }

    try {
      if (request.method === "GET" && url.pathname === "/health") {
        const db = await env.DB.prepare("SELECT 1 AS ok").first();
        return json({
          ok: true,
          service: "classmanager-api",
          environment: env.ENVIRONMENT,
          build: "rms-review-debug-2026-06-26",
          bindings: {
            d1: db?.ok === 1,
            r2: true,
            assets: true
          }
        });
      }

      if (request.method === "POST" && url.pathname === "/session/lookup") {
        return await sessionLookup(request, env);
      }

      if (request.method === "POST" && url.pathname === "/instructor/auth") {
        return await instructorAuth(request, env);
      }

      if (request.method === "POST" && url.pathname === "/instructor/scan") {
        return await instructorScan(request, env, ctx);
      }

      if (request.method === "POST" && url.pathname === "/instructor/attendance/submit") {
        return await instructorAttendanceSubmit(request, env);
      }

      if (request.method === "GET" && url.pathname === "/instructor/active") {
        return await activeInstructor(url, env);
      }

      if (request.method === "GET" && url.pathname === "/instructor/dashboard") {
        return await instructorDashboard(url, env);
      }

      if (request.method === "POST" && url.pathname === "/instructor/student/reset") {
        return await instructorResetStudent(request, env);
      }

      if (request.method === "POST" && url.pathname === "/skills/opened") {
        return await skillsOpened(request, env);
      }

      if (request.method === "GET" && url.pathname.startsWith("/progress/")) {
        return await getProgress(url, env);
      }

      if (request.method === "PATCH" && url.pathname.startsWith("/progress/")) {
        return await patchProgress(request, url, env);
      }

      if (request.method === "POST" && url.pathname === "/devices/register") {
        return await registerDevice(request, env);
      }

      if (request.method === "POST" && url.pathname === "/attendance/submit") {
        return await submitAttendance(request, env);
      }

      if (request.method === "POST" && url.pathname === "/quiz/assign") {
        return await assignQuiz(request, env);
      }

      if (request.method === "GET" && url.pathname.startsWith("/quiz/review/")) {
        return await quizReview(url, env);
      }

      if (request.method === "POST" && url.pathname === "/rms/flexiquiz-result") {
        return await rmsFlexiQuizResult(request, env);
      }

      if (request.method === "GET" && url.pathname.startsWith("/quiz/metadata/")) {
        return await quizMetadata(url, env);
      }

      if (request.method === "POST" && url.pathname === "/email/send") {
        return await sendEmailEndpoint(request, env);
      }

      if (request.method === "POST" && url.pathname === "/aicomments") {
        return await aiCommentsEndpoint(request, env);
      }

      return json({ error: "not_found" }, 404);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.message }, error.status);
      }
      console.error("request failed", error);
      return json({ error: "internal_error" }, 500);
    }
  }
};

async function sessionLookup(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const submissionId = stringField(body, "submissionId");

  if (!submissionId) {
    return json({ error: "missing_submission_id" }, 400);
  }

  if (!env.JOTFORM_API_KEY) {
    return json({ error: "jotform_not_configured" }, 503);
  }

  const source = await fetchJotformSubmission(env, submissionId);
  const normalized = normalizeSessionLookup(source, submissionId);
  const selected = normalized.options[0];
  const attendee = selected ? attendeeWithOption(normalized.attendee, selected) : normalized.attendee;

  await ensureProgressParents(env, {
    studentId: attendee.oemsId || attendee.submissionId,
    classSessionId: sessionIdFor(attendee.courseDate ?? selected?.dateRaw ?? attendee.submissionId),
    oemsId: attendee.oemsId || undefined,
    firstName: attendee.firstName || "Unknown",
    lastName: attendee.lastName || "Student",
    email: attendee.email || undefined,
    courseId: attendee.courseId,
    courseTitle: attendee.courseType || "Class Session",
    courseDate: attendee.courseDate ?? selected?.dateRaw ?? "undated",
    sourceSubmissionId: attendee.submissionId,
    sourceFormId: normalized.formId
  });

  await audit(env, "session.lookup", {
    studentId: attendee.oemsId || attendee.submissionId,
    classSessionId: sessionIdFor(attendee.courseDate ?? selected?.dateRaw ?? attendee.submissionId),
    payload: {
      submissionId,
      formId: normalized.formId,
      formType: normalized.formType,
      optionCount: normalized.options.length
    }
  });

  return json({
    ok: true,
    submissionId,
    formId: normalized.formId,
    formType: normalized.formType,
    attendee,
    options: normalized.options
  });
}

async function instructorAuth(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const instructorId = stringField(body, "instructorId");

  if (!instructorId) {
    return json({ error: "missing_instructor_id" }, 400);
  }

  if (!env.JOTFORM_API_KEY) {
    return json({ error: "jotform_not_configured" }, 503);
  }

  const url = new URL(joinUrl(env.JOTFORM_BASE_URL, "/form/242266064536154/submissions"));
  url.searchParams.set("apiKey", env.JOTFORM_API_KEY);
  url.searchParams.set("limit", "1000");

  const response = await fetch(url, {
    headers: { accept: "application/json" }
  });

  if (!response.ok) {
    return json({ error: "instructor_lookup_failed" }, 502);
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  const submissions = arrayField(data, "content").filter(isJsonRecord);
  const normalizedId = instructorId.trim();

  for (const submission of submissions) {
    const answers = recordField(submission, "answers");
    if (!answers) {
      continue;
    }

    const oemsId = answerString(answers, "15").trim();
    if (oemsId !== normalizedId) {
      continue;
    }

    return json({
      ok: true,
      instructor: {
        fullName: answerString(answers, "3"),
        email: answerString(answers, "5"),
        oemsId
      }
    });
  }

  return json({ error: "instructor_not_authorized" }, 404);
}

async function instructorScan(request: Request, env: Env, ctx?: ExecutionContext): Promise<Response> {
  const body = await readJson(request);
  const personId = stringField(body, "personId");
  const deviceId = stringField(body, "deviceId");
  const now = new Date().toISOString();

  if (!personId) {
    return json({ error: "missing_person_id" }, 400);
  }

  const instructor = await resolveInstructorProfile(env, personId);
  await upsertInstructorProfile(env, instructor, now);

  ctx?.waitUntil(fetchRegistrationCourses(env).catch((error) => {
    console.warn("background registration course refresh failed", error);
  }));
  const courses = await resolveInstructorCourses(env);
  const defaultCourse = courses.find((course) => course.isToday);
  const attendance = defaultCourse
    ? await instructorAttendanceForCourse(env, personId, defaultCourse.classSessionId)
    : undefined;

  await audit(env, "instructor.scan", {
    actorId: personId,
    deviceId,
    payload: {
      defaultCourseId: defaultCourse?.id ?? null,
      courseCount: courses.length
    }
  });

  return json({
    ok: true,
    instructor,
    defaultCourse: defaultCourse ?? null,
    courses,
    attendance: attendance ?? null
  });
}

async function instructorAttendanceSubmit(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const personId = stringField(body, "personId");
  const inOut = stringField(body, "inOut");
  const deviceId = stringField(body, "deviceId");
  const attestation = recordField(body, "attestation");
  const course = recordField(body, "course");

  if (!personId || !inOut || !course || !attestation) {
    return json({ error: "missing_instructor_attendance_fields" }, 400);
  }

  const classSessionId = stringField(course, "classSessionId");
  const courseTitle = stringField(course, "title") ?? stringField(course, "courseTitle") ?? "Class Session";
  const courseDate = stringField(course, "date") ?? stringField(course, "courseDate") ?? classSessionId;
  const courseId = stringField(course, "courseId");
  if (!classSessionId || !courseDate) {
    return json({ error: "missing_instructor_course" }, 400);
  }

  const now = new Date().toISOString();
  const attendanceId = `${personId}:${classSessionId}`;
  const isCheckIn = inOut === "Check-In";
  const isCheckOut = inOut === "Check-Out";
  if (!isCheckIn && !isCheckOut) {
    return json({ error: "invalid_inout" }, 400);
  }

  const existingAttendance = await instructorAttendanceForId(env, attendanceId);
  if (isCheckIn && existingAttendance?.checkedInAt) {
    await touchInstructorDeviceContext(env, {
      deviceId,
      personId,
      classSessionId
    });
    await audit(env, "instructor.attendance_duplicate_checkin", {
      actorId: personId,
      classSessionId,
      deviceId,
      payload: {
        attendanceId,
        checkedInAt: existingAttendance.checkedInAt
      }
    });
    return json({
      ok: true,
      attendance: existingAttendance,
      duplicate: true,
      warnings: ["instructor_already_checked_in"],
      updatedAt: now
    });
  }

  const instructor = await resolveInstructorProfile(env, personId);
  await upsertInstructorProfile(env, instructor, now);

  await env.DB.prepare(
    `INSERT INTO instructor_attendance (
       id, person_id, device_id, class_session_id, course_id, course_title,
       course_date, source, checked_in_at, checked_out_at, updated_at
     ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 'classmanager_app', ?8, ?9, ?10)
     ON CONFLICT(id) DO UPDATE SET
       device_id = COALESCE(excluded.device_id, instructor_attendance.device_id),
       class_session_id = COALESCE(excluded.class_session_id, instructor_attendance.class_session_id),
       course_id = COALESCE(excluded.course_id, instructor_attendance.course_id),
       course_title = COALESCE(excluded.course_title, instructor_attendance.course_title),
       course_date = COALESCE(excluded.course_date, instructor_attendance.course_date),
       checked_in_at = COALESCE(instructor_attendance.checked_in_at, excluded.checked_in_at),
       checked_out_at = COALESCE(excluded.checked_out_at, instructor_attendance.checked_out_at),
       updated_at = excluded.updated_at`
  ).bind(
    attendanceId,
    personId,
    deviceId ?? null,
    classSessionId,
    courseId ?? null,
    courseTitle,
    courseDate,
    isCheckIn ? now : now,
    isCheckOut ? now : null,
    now
  ).run();

  await touchInstructorDeviceContext(env, {
    deviceId,
    personId,
    classSessionId
  });

  const warnings: string[] = [];
  let rms: { ok: boolean; attestationId?: string } | undefined;
  if (env.ACADEMY_RMS_BASE_URL && env.ACADEMY_RMS_ATTENDANCE_SECRET) {
    try {
      rms = await postAcademyRmsAttendance(env, {
        kind: "instructor_attendance",
        personId,
        inOut,
        classSessionId,
        courseId,
        courseTitle,
        courseDate,
        attestation,
        deviceId,
        submittedAt: now
      });
    } catch (error) {
      console.error("rms instructor attendance submit failed", error);
      warnings.push("rms_submit_failed");
    }
  } else {
    warnings.push("rms_attendance_not_configured");
  }

  await audit(env, "instructor.attendance_submit", {
    actorId: personId,
    classSessionId,
    deviceId,
    payload: {
      attendanceId,
      inOut,
      courseId: courseId ?? null,
      courseTitle,
      rmsAttestationId: rms?.attestationId ?? null,
      warnings
    }
  });

  return json({
    ok: true,
    attendance: {
      id: attendanceId,
      checkedInAt: isCheckIn ? (existingAttendance?.checkedInAt ?? now) : await existingInstructorCheckIn(env, attendanceId),
      checkedOutAt: isCheckOut ? now : null,
      classSessionId,
      courseId,
      courseTitle,
      courseDate
    },
    rmsAttestationId: rms?.attestationId,
    warnings,
    updatedAt: now
  });
}

async function instructorDashboard(url: URL, env: Env): Promise<Response> {
  const limit = Math.min(Math.max(numberFromUnknown(url.searchParams.get("limit")) ?? 100, 1), 250);
  const courses = await resolveInstructorCourses(env);
  const classSessionId = url.searchParams.get("classSessionId")?.trim() || courses.find((course) => course.isToday)?.classSessionId || courses[0]?.classSessionId;
  const selectedCourse = courses.find((course) => course.classSessionId === classSessionId);
  const instructorPersonId = url.searchParams.get("instructorPersonId")?.trim();
  const deviceId = url.searchParams.get("deviceId")?.trim();
  if (!classSessionId) {
    return json({
      ok: true,
      generatedAt: new Date().toISOString(),
      course: null,
      courses,
      attendance: null,
      students: [],
      quizResults: [],
      finalResults: [],
      skillsVerifications: []
    });
  }

  if (instructorPersonId && deviceId) {
    await touchInstructorDeviceContext(env, {
      deviceId,
      personId: instructorPersonId,
      classSessionId
    });
  }

  const rows = await env.DB.prepare(
    `SELECT
       COALESCE(scs.student_id, sp.student_id) AS student_id,
       COALESCE(scs.class_session_id, sp.class_session_id) AS class_session_id,
       COALESCE(sp.did_check_in, 0) AS did_check_in,
       COALESCE(sp.did_check_out, 0) AS did_check_out,
       sp.did_open_skills, sp.did_open_quiz, sp.check_in_at, sp.check_out_at,
       sp.updated_at AS progress_updated_at,
       COALESCE(scs.first_name, s.first_name) AS first_name,
       COALESCE(scs.last_name, s.last_name) AS last_name,
       COALESCE(scs.email, s.email) AS email,
       COALESCE(scs.oems_id, s.oems_id) AS oems_id,
       COALESCE(scs.course_title, cs.course_title) AS course_title,
       COALESCE(scs.course_date, cs.course_date) AS course_date,
       COALESCE(scs.course_id, cs.course_id) AS course_id,
       CASE WHEN scs.id IS NULL THEN 0 ELSE 1 END AS expected
     FROM scheduled_course_students scs
     LEFT JOIN student_progress sp
       ON sp.student_id = scs.student_id AND sp.class_session_id = scs.class_session_id
     LEFT JOIN students s ON s.id = COALESCE(sp.student_id, scs.student_id)
     LEFT JOIN class_sessions cs ON cs.id = COALESCE(sp.class_session_id, scs.class_session_id)
     WHERE scs.class_session_id = ?1
     UNION
     SELECT
       sp.student_id, sp.class_session_id, sp.did_check_in, sp.did_check_out,
       sp.did_open_skills, sp.did_open_quiz, sp.check_in_at, sp.check_out_at,
       sp.updated_at AS progress_updated_at,
       s.first_name, s.last_name, s.email, s.oems_id,
       cs.course_title, cs.course_date, cs.course_id,
       0 AS expected
     FROM student_progress sp
     JOIN students s ON s.id = sp.student_id
     JOIN class_sessions cs ON cs.id = sp.class_session_id
     WHERE sp.class_session_id = ?1
       AND NOT EXISTS (
         SELECT 1 FROM scheduled_course_students scs
         WHERE scs.class_session_id = sp.class_session_id AND scs.student_id = sp.student_id
       )
     ORDER BY last_name, first_name
     LIMIT ?2`
  ).bind(classSessionId, limit).all<JsonRecord>();

  const attempts = await env.DB.prepare(
    `SELECT qa.student_id, qa.class_session_id, qa.quiz_id, qa.result_text,
            qa.score_text, qa.passed, qa.completed_at, qa.updated_at
     FROM quiz_attempts qa
     WHERE qa.class_session_id = ?1
       AND lower(COALESCE(qa.result_text, '')) NOT IN ('not_submitted', 'not submitted', 'in_progress', 'in progress')
     ORDER BY COALESCE(qa.completed_at, qa.updated_at) DESC
     LIMIT 500`
  ).bind(classSessionId).all<JsonRecord>();

  const finals = await env.DB.prepare(
    `SELECT student_id, class_session_id, quiz_id, quiz_name, response_id,
            score_text, result_text, passed, percentage_score, points,
            available_points, completed_at, updated_at
     FROM final_exam_results
     WHERE class_session_id = ?1
     ORDER BY COALESCE(completed_at, updated_at) DESC
     LIMIT 250`
  ).bind(classSessionId).all<JsonRecord>();

  const skills = await env.DB.prepare(
    `SELECT student_id, class_session_id, instructor_person_id, opened_at,
            completed_at, updated_at
     FROM skills_verifications
     WHERE class_session_id = ?1
     ORDER BY opened_at DESC
     LIMIT 250`
  ).bind(classSessionId).all<JsonRecord>();
  const attendance = instructorPersonId
    ? await instructorAttendanceForCourse(env, instructorPersonId, classSessionId)
    : undefined;

  return json({
    ok: true,
    generatedAt: new Date().toISOString(),
    course: selectedCourse ?? null,
    courses,
    attendance: attendance ?? null,
    students: (rows.results ?? []).map(dashboardStudent),
    quizResults: (attempts.results ?? []).map(dashboardQuizResult),
    finalResults: (finals.results ?? []).map(dashboardFinalResult),
    skillsVerifications: (skills.results ?? []).map(dashboardSkillsVerification)
  });
}

async function instructorResetStudent(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const personId = stringField(body, "personId");
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");
  const confirmation = stringField(body, "confirmation");
  const deviceId = stringField(body, "deviceId");

  if (!personId || !studentId || !classSessionId) {
    return json({ error: "missing_reset_fields" }, 400);
  }
  if (confirmation !== "RESET STUDENT") {
    return json({ error: "reset_confirmation_required" }, 400);
  }

  const deletedFinals = await env.DB.prepare(
    `DELETE FROM final_exam_results WHERE student_id = ?1 AND class_session_id = ?2`
  ).bind(studentId, classSessionId).run();
  const deletedAttempts = await env.DB.prepare(
    `DELETE FROM quiz_attempts WHERE student_id = ?1 AND class_session_id = ?2`
  ).bind(studentId, classSessionId).run();
  const deletedSkills = await env.DB.prepare(
    `DELETE FROM skills_verifications WHERE student_id = ?1 AND class_session_id = ?2`
  ).bind(studentId, classSessionId).run();
  const flexiReset = await resetFlexiQuizUserForStudent(env, { studentId, classSessionId });
  const deletedProgress = await env.DB.prepare(
    `DELETE FROM student_progress WHERE student_id = ?1 AND class_session_id = ?2`
  ).bind(studentId, classSessionId).run();
  await env.DB.prepare(
    `UPDATE device_tokens
     SET student_id = NULL, class_session_id = NULL, email = NULL, flexiquiz_user_id = NULL,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
     WHERE student_id = ?1 AND class_session_id = ?2`
  ).bind(studentId, classSessionId).run();

  await audit(env, "instructor.student_reset", {
    studentId,
    classSessionId,
    actorId: personId,
    deviceId,
    payload: {
      deletedFinals: deletedFinals.meta.changes,
      deletedAttempts: deletedAttempts.meta.changes,
      deletedSkills: deletedSkills.meta.changes,
      deletedProgress: deletedProgress.meta.changes,
      flexiquiz: flexiReset
    }
  });

  return json({
    ok: true,
    deleted: {
      finalExamResults: deletedFinals.meta.changes,
      quizAttempts: deletedAttempts.meta.changes,
      skillsVerifications: deletedSkills.meta.changes,
      progressRows: deletedProgress.meta.changes
    },
    flexiquiz: flexiReset
  });
}

async function resetFlexiQuizUserForStudent(
  env: Env,
  input: { studentId: string; classSessionId: string }
): Promise<JsonRecord> {
  if (!env.FLEXIQUIZ_API_KEY) {
    return { ok: false, skipped: true, reason: "flexiquiz_not_configured" };
  }

  const identity = await env.DB.prepare(
    `SELECT
       scs.submission_id,
       scs.email,
       scs.first_name,
       scs.last_name,
       scs.oems_id,
       dt.flexiquiz_user_id
     FROM scheduled_course_students scs
     LEFT JOIN device_tokens dt
       ON dt.student_id = scs.student_id AND dt.class_session_id = scs.class_session_id
     WHERE scs.student_id = ?1 AND scs.class_session_id = ?2
     ORDER BY dt.updated_at DESC
     LIMIT 1`
  ).bind(input.studentId, input.classSessionId).first<JsonRecord>();

  const fallback = await env.DB.prepare(
    `SELECT s.email, s.first_name, s.last_name, s.oems_id,
            cs.source_submission_id,
            dt.flexiquiz_user_id
     FROM students s
     JOIN class_sessions cs ON cs.id = ?2
     LEFT JOIN device_tokens dt
       ON dt.student_id = s.id AND dt.class_session_id = ?2
     WHERE s.id = ?1
     ORDER BY dt.updated_at DESC
     LIMIT 1`
  ).bind(input.studentId, input.classSessionId).first<JsonRecord>();

  const source = identity ?? fallback;
  const sourceSubmissionId = stringField(source ?? {}, "submission_id") ?? stringField(source ?? {}, "source_submission_id");
  const email = stringField(source ?? {}, "email");
  const flexiquizUserName = classRegistrationFlexiQuizUserName({
    email,
    sourceSubmissionId,
    studentId: input.studentId,
    classSessionId: input.classSessionId
  });

  const userIds = new Set<string>();
  const storedUserId = stringField(source ?? {}, "flexiquiz_user_id");
  if (storedUserId) {
    userIds.add(storedUserId);
  }

  const generatedUserId = await flexiFindUserId(env, flexiquizUserName);
  if (generatedUserId) {
    userIds.add(generatedUserId);
  }

  if (userIds.size === 0) {
    return {
      ok: true,
      deleted: false,
      flexiquizUserName,
      reason: "flexiquiz_user_not_found"
    };
  }

  const deleted: JsonRecord[] = [];
  const failed: JsonRecord[] = [];
  for (const userId of userIds) {
    const result = await flexiDeleteUser(env, userId);
    if (result.ok) {
      deleted.push({ userId, status: result.status });
    } else {
      failed.push({ userId, status: result.status, body: result.body });
    }
  }

  return {
    ok: failed.length === 0,
    deleted: deleted.length > 0,
    flexiquizUserName,
    deletedUsers: deleted,
    failedUsers: failed
  };
}

async function skillsOpened(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");
  const instructorPersonId = stringField(body, "instructorPersonId");
  const now = new Date().toISOString();

  if (!studentId || !classSessionId) {
    return json({ error: "missing_skills_fields" }, 400);
  }

  await writeProgress(env, {
    studentId,
    classSessionId,
    didOpenSkills: true,
    deviceId: stringField(body, "deviceId")
  });

  await env.DB.prepare(
    `INSERT INTO skills_verifications (
      id, student_id, class_session_id, instructor_person_id, opened_at, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?5)
    ON CONFLICT(id) DO UPDATE SET
      instructor_person_id = COALESCE(excluded.instructor_person_id, skills_verifications.instructor_person_id),
      updated_at = excluded.updated_at`
  ).bind(
    `${classSessionId}:${studentId}:skills`,
    studentId,
    classSessionId,
    instructorPersonId ?? null,
    now
  ).run();

  await audit(env, "skills.opened", {
    studentId,
    classSessionId,
    actorId: instructorPersonId,
    deviceId: stringField(body, "deviceId")
  });

  return json({ ok: true, updatedAt: now });
}

async function activeInstructor(url: URL, env: Env): Promise<Response> {
  const classSessionId = url.searchParams.get("classSessionId")?.trim();
  if (!classSessionId) {
    return json({ error: "missing_class_session_id" }, 400);
  }

  const row = await env.DB.prepare(
    `SELECT i.person_id, i.full_name, i.first_name, i.last_name, i.email, i.oems_id,
            ia.checked_in_at, ia.checked_out_at, ia.course_title, ia.course_date
     FROM instructor_attendance ia
     JOIN instructors i ON i.person_id = ia.person_id
     WHERE ia.class_session_id = ?1
     ORDER BY CASE WHEN ia.checked_out_at IS NULL THEN 0 ELSE 1 END,
              ia.checked_in_at DESC
     LIMIT 1`
  ).bind(classSessionId).first<JsonRecord>();

  if (!row) {
    return json({ ok: true, instructor: null });
  }

  return json({
    ok: true,
    instructor: instructorProfileFromRow(row),
    attendance: {
      checkedInAt: stringField(row, "checked_in_at") ?? null,
      checkedOutAt: stringField(row, "checked_out_at") ?? null,
      courseTitle: stringField(row, "course_title") ?? null,
      courseDate: stringField(row, "course_date") ?? null
    }
  });
}

function knownInstructorName(personId: string): string | undefined {
  const known: Record<string, string> = {
    "704bbc3f-9503-44e5-a442-e6cbf21c4ebe": "Patrick McIlhenney"
  };
  return known[personId];
}

async function resolveInstructorProfile(env: Env, personId: string): Promise<InstructorProfile> {
  const cached = await env.DB.prepare(
    `SELECT person_id, full_name, first_name, last_name, email, oems_id
     FROM instructors
     WHERE person_id = ?1
     LIMIT 1`
  ).bind(personId).first<JsonRecord>();

  const fallback = cached ? instructorProfileFromRow(cached) : {
    personId,
    fullName: knownInstructorName(personId) ?? "Instructor"
  };

  if (!env.ACADEMY_RMS_BASE_URL) {
    return fallback;
  }

  try {
    const params = new URLSearchParams({ person_id: personId });
    const endpoint = `${joinUrl(env.ACADEMY_RMS_BASE_URL, "/api/classmanager/person-profile")}?${params.toString()}`;
    const response = await fetch(endpoint, {
      headers: env.ACADEMY_RMS_ATTENDANCE_SECRET ? {
        "x-classmanager-secret": env.ACADEMY_RMS_ATTENDANCE_SECRET
      } : undefined
    });
    if (!response.ok) {
      throw new Error(`rms_person_${response.status}`);
    }
    const data = await response.json<JsonRecord>();
    const person = recordField(data, "person");
    if (!person) {
      return fallback;
    }
    const firstName = stringField(person, "first_name");
    const lastName = stringField(person, "last_name");
    const fullName = [firstName, lastName].filter(Boolean).join(" ").trim() ||
      stringField(person, "full_name") ||
      fallback.fullName;
    return {
      personId,
      fullName,
      firstName,
      lastName,
      email: stringField(person, "primary_email") ?? fallback.email,
      oemsId: stringField(person, "njoems_id") ?? fallback.oemsId
    };
  } catch (error) {
    console.warn("rms instructor profile lookup failed", { personId, error: String(error) });
    return fallback;
  }
}

async function upsertInstructorProfile(env: Env, profile: InstructorProfile, now = new Date().toISOString()): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO instructors (person_id, full_name, email, oems_id, first_name, last_name, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
     ON CONFLICT(person_id) DO UPDATE SET
       full_name = COALESCE(excluded.full_name, instructors.full_name),
       email = COALESCE(excluded.email, instructors.email),
       oems_id = COALESCE(excluded.oems_id, instructors.oems_id),
       first_name = COALESCE(excluded.first_name, instructors.first_name),
       last_name = COALESCE(excluded.last_name, instructors.last_name),
       updated_at = excluded.updated_at`
  ).bind(
    profile.personId,
    profile.fullName,
    profile.email ?? null,
    profile.oemsId ?? null,
    profile.firstName ?? null,
    profile.lastName ?? null,
    now
  ).run();
}

function instructorProfileFromRow(row: JsonRecord): InstructorProfile {
  const personId = stringField(row, "person_id") ?? "";
  const firstName = stringField(row, "first_name");
  const lastName = stringField(row, "last_name");
  const fullName = stringField(row, "full_name") ||
    [firstName, lastName].filter(Boolean).join(" ").trim() ||
    knownInstructorName(personId) ||
    "Instructor";
  return {
    personId,
    fullName,
    firstName,
    lastName,
    email: stringField(row, "email"),
    oemsId: stringField(row, "oems_id")
  };
}

async function existingInstructorCheckIn(env: Env, attendanceId: string): Promise<string | undefined> {
  const row = await env.DB.prepare(
    `SELECT checked_in_at FROM instructor_attendance WHERE id = ?1`
  ).bind(attendanceId).first<JsonRecord>();
  return row ? stringField(row, "checked_in_at") : undefined;
}

async function instructorAttendanceForId(env: Env, attendanceId: string): Promise<JsonRecord | undefined> {
  const row = await env.DB.prepare(
    `SELECT id, class_session_id, course_id, course_title, course_date,
            checked_in_at, checked_out_at
     FROM instructor_attendance
     WHERE id = ?1
     LIMIT 1`
  ).bind(attendanceId).first<JsonRecord>();
  return row ? instructorAttendanceFromRow(row) : undefined;
}

async function instructorAttendanceForCourse(
  env: Env,
  personId: string,
  classSessionId: string
): Promise<JsonRecord | undefined> {
  const row = await env.DB.prepare(
    `SELECT id, class_session_id, course_id, course_title, course_date,
            checked_in_at, checked_out_at
     FROM instructor_attendance
     WHERE person_id = ?1 AND class_session_id = ?2
     ORDER BY checked_in_at DESC
     LIMIT 1`
  ).bind(personId, classSessionId).first<JsonRecord>();
  return row ? instructorAttendanceFromRow(row) : undefined;
}

function instructorAttendanceFromRow(row: JsonRecord): JsonRecord {
  return {
    id: stringField(row, "id") ?? "",
    checkedInAt: stringField(row, "checked_in_at") ?? "",
    checkedOutAt: stringField(row, "checked_out_at") ?? null,
    classSessionId: stringField(row, "class_session_id") ?? null,
    courseId: stringField(row, "course_id") ?? null,
    courseTitle: stringField(row, "course_title") ?? null,
    courseDate: stringField(row, "course_date") ?? null
  };
}

async function resolveInstructorCourses(env: Env): Promise<InstructorCourse[]> {
  const rows = await env.DB.prepare(
    `SELECT id, class_session_id, course_id, course_title, course_date, course_location, expected_count, raw_json
     FROM scheduled_courses
     ORDER BY course_date DESC, course_title`
  ).all<JsonRecord>();
  const included = await fetchIncludedInstructorCourses(env);
  const scheduled = [...(rows.results ?? []).map(courseFromScheduledRow), ...included];
  if (scheduled.length > 0) {
    return instructorCourseMenuList(scheduled);
  }

  const sessions = await env.DB.prepare(
    `SELECT id, course_id, course_title, course_date
     FROM class_sessions
     ORDER BY updated_at DESC
     LIMIT 100`
  ).all<JsonRecord>();
  return instructorCourseMenuList((sessions.results ?? []).map((row) => {
    const date = stringField(row, "course_date") ?? "";
    const classSessionId = stringField(row, "id") ?? sessionIdFor(date);
    const title = stringField(row, "course_title") ?? "Class Session";
    const courseId = stringField(row, "course_id");
    return {
      id: [classSessionId, courseId, title].filter(Boolean).join(":"),
      classSessionId,
      courseId,
      title,
      date,
      expectedCount: 0,
      isToday: datesMatchToday(date)
    };
  }));
}

async function fetchRegistrationCourses(env: Env): Promise<InstructorCourse[]> {
  const url = new URL(joinUrl(env.JOTFORM_BASE_URL, `/form/${REGISTRATION_FORM_ID}/submissions`));
  url.searchParams.set("apiKey", env.JOTFORM_API_KEY ?? "");
  url.searchParams.set("limit", "250");
  url.searchParams.set("orderby", "id");

  const response = await fetch(url, {
    headers: { accept: "application/json" },
    signal: AbortSignal.timeout(12_000)
  });
  if (!response.ok) {
    throw new HttpError(502, "registration_course_lookup_failed");
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  const submissions = arrayField(data, "content").filter(isJsonRecord);
  const courseMap = new Map<string, { course: InstructorCourse; students: JsonRecord[] }>();

  for (const submission of submissions) {
    const answers = recordField(submission, "answers");
    const submissionId = stringField(submission, "id");
    const formId = stringField(submission, "form_id") ?? REGISTRATION_FORM_ID;
    if (!answers || !submissionId || !answer(answers, "39")) {
      continue;
    }

    const normalized = normalizeRegistrationSubmission(answers, submissionId, formId);
    for (const option of normalized.options) {
      const attendee = attendeeWithOption(normalized.attendee, option);
      const course = instructorCourseFromAttendee(attendee, formId);
      const existing = courseMap.get(course.id) ?? { course, students: [] };
      existing.students.push({
        attendee,
        formId,
        course
      });
      existing.course.expectedCount = existing.students.length;
      courseMap.set(course.id, existing);
    }
  }

  const includedEntries = await fetchIncludedInstructorCourseEntries(env);
  for (const entry of includedEntries) {
    const existing = courseMap.get(entry.course.id) ?? { course: entry.course, students: [] };
    existing.students.push({
      attendee: entry.attendee,
      formId: entry.formId,
      course: entry.course
    });
    existing.course.expectedCount = Math.max(existing.course.expectedCount, existing.students.length);
    courseMap.set(entry.course.id, existing);
  }

  const now = new Date().toISOString();
  for (const entry of courseMap.values()) {
    await upsertScheduledCourse(env, entry.course, now);
    for (const student of entry.students) {
      await upsertScheduledStudent(env, student, now);
    }
  }

  return instructorCourseMenuList([...courseMap.values()].map((entry) => entry.course));
}

async function fetchIncludedInstructorCourses(env: Env): Promise<InstructorCourse[]> {
  return (await fetchIncludedInstructorCourseEntries(env)).map((entry) => entry.course);
}

async function fetchIncludedInstructorCourseEntries(env: Env): Promise<Array<{
  course: InstructorCourse;
  attendee: NormalizedAttendee;
  formId: string;
}>> {
  if (!env.JOTFORM_API_KEY || INSTRUCTOR_INCLUDED_SUBMISSION_IDS.size === 0) {
    return [];
  }

  const entries: Array<{ course: InstructorCourse; attendee: NormalizedAttendee; formId: string }> = [];
  for (const submissionId of INSTRUCTOR_INCLUDED_SUBMISSION_IDS) {
    const source = await fetchJotformSubmission(env, submissionId).catch((error) => {
      console.warn("included instructor course lookup failed", { submissionId, error: String(error) });
      return undefined;
    });
    if (!source) {
      continue;
    }
    const content = recordField(source, "content");
    const answers = recordField(content, "answers");
    const formId = stringField(content ?? {}, "form_id") ?? REGISTRATION_FORM_ID;
    if (!answers) {
      continue;
    }

    const normalized = answer(answers, "39")
      ? normalizeRegistrationSubmission(answers, submissionId, formId)
      : normalizeRefresherSubmission(answers, submissionId, formId);
    const options = normalized.options.length > 0
      ? normalized.options
      : [{
          courseType: normalized.attendee.courseType || "Class Session",
          datePretty: normalized.attendee.courseDate ?? "",
          dateRaw: normalized.attendee.courseDate ?? "",
          courseId: normalized.attendee.courseId,
          courseLocation: normalized.attendee.courseLocation
        }];

    for (const option of options) {
      const attendee = attendeeWithOption(normalized.attendee, option);
      entries.push({
        course: {
          ...instructorCourseFromAttendee(attendee, formId),
          expectedCount: 1,
          displayDate: validCourseDate(attendee.courseDate ?? "") ? undefined : "Legacy test course",
          alwaysInclude: true
        },
        attendee,
        formId
      });
    }
  }
  return entries;
}

function instructorCourseFromAttendee(attendee: NormalizedAttendee, formId: string): InstructorCourse {
  const date = normalizeDateToMMDDYYYY(attendee.courseDate ?? "");
  const classSessionId = sessionIdFor(date || attendee.courseId || attendee.submissionId);
  const title = attendee.courseType || "Class Session";
  const courseId = attendee.courseId;
  const id = [classSessionId, courseId, title].filter(Boolean).join(":");
  return {
    id,
    classSessionId,
    courseId,
    title,
    date,
    location: attendee.courseLocation,
    expectedCount: 0,
    isToday: datesMatchToday(date)
  };
}

async function upsertScheduledCourse(env: Env, course: InstructorCourse, now: string): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO scheduled_courses (
      id, class_session_id, course_id, course_title, course_date, course_location,
      source_form_id, expected_count, raw_json, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
    ON CONFLICT(id) DO UPDATE SET
      class_session_id = excluded.class_session_id,
      course_id = excluded.course_id,
      course_title = excluded.course_title,
      course_date = excluded.course_date,
      course_location = excluded.course_location,
      source_form_id = excluded.source_form_id,
      expected_count = excluded.expected_count,
      raw_json = excluded.raw_json,
      updated_at = excluded.updated_at`
  ).bind(
    course.id,
    course.classSessionId,
    course.courseId ?? null,
    course.title,
    course.date,
    course.location ?? null,
    REGISTRATION_FORM_ID,
    course.expectedCount,
    JSON.stringify(course),
    now
  ).run();
}

async function upsertScheduledStudent(env: Env, row: JsonRecord, now: string): Promise<void> {
  const attendee = recordField(row, "attendee") as NormalizedAttendee | undefined;
  const course = recordField(row, "course") as InstructorCourse | undefined;
  const formId = stringField(row, "formId") ?? REGISTRATION_FORM_ID;
  if (!attendee || !course) {
    return;
  }

  const studentId = attendee.oemsId || attendee.submissionId;
  const id = `${course.classSessionId}:${studentId}:${attendee.submissionId}`;
  await env.DB.prepare(
    `INSERT INTO scheduled_course_students (
      id, class_session_id, course_id, submission_id, student_id,
      first_name, last_name, email, oems_id, course_title, course_date,
      course_location, dob, raw_json, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)
    ON CONFLICT(class_session_id, student_id, submission_id) DO UPDATE SET
      course_id = excluded.course_id,
      first_name = excluded.first_name,
      last_name = excluded.last_name,
      email = excluded.email,
      oems_id = excluded.oems_id,
      course_title = excluded.course_title,
      course_date = excluded.course_date,
      course_location = excluded.course_location,
      dob = excluded.dob,
      raw_json = excluded.raw_json,
      updated_at = excluded.updated_at`
  ).bind(
    id,
    course.classSessionId,
    course.courseId ?? null,
    attendee.submissionId,
    studentId,
    attendee.firstName || "Unknown",
    attendee.lastName || "Student",
    attendee.email || null,
    attendee.oemsId || null,
    course.title,
    course.date,
    course.location ?? null,
    attendee.dob ?? null,
    JSON.stringify(attendee),
    now
  ).run();
}

function courseFromScheduledRow(row: JsonRecord): InstructorCourse {
  const date = stringField(row, "course_date") ?? "";
  const raw = parseJsonRecord(stringField(row, "raw_json") ?? "") ?? {};
  return {
    id: stringField(row, "id") ?? [stringField(row, "class_session_id"), stringField(row, "course_id"), stringField(row, "course_title")].filter(Boolean).join(":"),
    classSessionId: stringField(row, "class_session_id") ?? sessionIdFor(date),
    courseId: stringField(row, "course_id"),
    title: stringField(row, "course_title") ?? "Class Session",
    date,
    displayDate: stringField(raw, "displayDate"),
    location: stringField(row, "course_location"),
    expectedCount: numberFromUnknown(row.expected_count) ?? 0,
    isToday: datesMatchToday(date),
    alwaysInclude: boolFromUnknown(raw.alwaysInclude)
  };
}

function instructorCourseMenuList(courses: InstructorCourse[]): InstructorCourse[] {
  const deduped = dedupeInstructorCourses(courses);
  const todayValue = dateSortValue(todayEasternDate());
  const windowed = deduped.filter((course) => {
    if (course.isToday) {
      return true;
    }
    if (course.alwaysInclude) {
      return true;
    }
    const value = dateSortValue(course.date);
    if (!Number.isFinite(value) || value === Number.MAX_SAFE_INTEGER) {
      return false;
    }
    const delta = daysBetweenDateValues(todayValue, value);
    return delta >= -INSTRUCTOR_PAST_COURSE_DAYS && delta <= INSTRUCTOR_UPCOMING_COURSE_DAYS;
  });

  const scoped = windowed.length > 0 ? windowed : deduped;
  return scoped
    .sort(compareInstructorCourses)
    .slice(0, INSTRUCTOR_MAX_COURSES);
}

function dedupeInstructorCourses(courses: InstructorCourse[]): InstructorCourse[] {
  const merged = new Map<string, InstructorCourse>();
  for (const course of courses) {
    const key = [
      course.classSessionId,
      courseDateKey(course.date),
      normalizedCourseTitle(course.title),
      normalizedCourseTitle(course.location ?? "")
    ].join(":");
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, course);
      continue;
    }

    merged.set(key, {
      ...existing,
      id: course.courseId && !existing.courseId ? course.id : existing.id,
      courseId: existing.courseId ?? course.courseId,
      title: existing.title.length >= course.title.length ? existing.title : course.title,
      location: existing.location ?? course.location,
      expectedCount: Math.max(existing.expectedCount, course.expectedCount),
      displayDate: existing.displayDate ?? course.displayDate,
      isToday: existing.isToday || course.isToday,
      alwaysInclude: existing.alwaysInclude || course.alwaysInclude
    });
  }
  return [...merged.values()];
}

function compareInstructorCourses(a: InstructorCourse, b: InstructorCourse): number {
  if (a.isToday !== b.isToday) {
    return a.isToday ? -1 : 1;
  }
  const today = dateSortValue(todayEasternDate());
  const aValue = dateSortValue(a.date);
  const bValue = dateSortValue(b.date);
  const aLegacy = Boolean(a.alwaysInclude && aValue === Number.MAX_SAFE_INTEGER);
  const bLegacy = Boolean(b.alwaysInclude && bValue === Number.MAX_SAFE_INTEGER);
  if (aLegacy !== bLegacy) {
    return aLegacy ? -1 : 1;
  }
  const aPast = aValue < today;
  const bPast = bValue < today;
  if (aPast !== bPast) {
    return aPast ? -1 : 1;
  }
  if (aValue !== bValue) {
    return aPast ? bValue - aValue : aValue - bValue;
  }
  return a.title.localeCompare(b.title);
}

function datesMatchToday(rawDate: string): boolean {
  return normalizeDateToMMDDYYYY(rawDate) === todayEasternDate();
}

function dateSortValue(rawDate: string): number {
  const normalized = normalizeDateToMMDDYYYY(rawDate);
  const match = normalized.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (!match) {
    return Number.MAX_SAFE_INTEGER;
  }
  const month = Number(match[1]);
  const day = Number(match[2]);
  const year = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return Number.MAX_SAFE_INTEGER;
  }
  return Number(`${match[3]}${match[1]}${match[2]}`);
}

function validCourseDate(rawDate: string): boolean {
  return dateSortValue(rawDate) !== Number.MAX_SAFE_INTEGER;
}

function courseDateKey(rawDate: string): string {
  return normalizeDateToMMDDYYYY(rawDate).replace(/\//g, "-");
}

function normalizedCourseTitle(value: string): string {
  return cleanText(value)
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

function daysBetweenDateValues(start: number, end: number): number {
  const startDate = dateFromSortValue(start);
  const endDate = dateFromSortValue(end);
  if (!startDate || !endDate) {
    return Number.MAX_SAFE_INTEGER;
  }
  return Math.round((endDate.getTime() - startDate.getTime()) / 86_400_000);
}

function dateFromSortValue(value: number): Date | undefined {
  if (!Number.isFinite(value) || value === Number.MAX_SAFE_INTEGER) {
    return undefined;
  }
  const text = String(value).padStart(8, "0");
  const year = Number(text.slice(0, 4));
  const month = Number(text.slice(4, 6));
  const day = Number(text.slice(6, 8));
  if (!year || !month || !day) {
    return undefined;
  }
  return new Date(Date.UTC(year, month - 1, day));
}

function todayEasternDate(): string {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    month: "2-digit",
    day: "2-digit",
    year: "numeric"
  }).format(new Date());
}

function dashboardStudent(row: JsonRecord): JsonRecord {
  return {
    studentId: stringField(row, "student_id"),
    classSessionId: stringField(row, "class_session_id"),
    firstName: stringField(row, "first_name") ?? "",
    lastName: stringField(row, "last_name") ?? "",
    email: stringField(row, "email"),
    oemsId: stringField(row, "oems_id"),
    courseTitle: stringField(row, "course_title") ?? "Class Session",
    courseDate: stringField(row, "course_date"),
    courseId: stringField(row, "course_id"),
    didCheckIn: boolFromUnknown(row.did_check_in) ?? false,
    didCheckOut: boolFromUnknown(row.did_check_out) ?? false,
    didOpenSkills: boolFromUnknown(row.did_open_skills) ?? false,
    didOpenQuiz: boolFromUnknown(row.did_open_quiz) ?? false,
    expected: boolFromUnknown(row.expected) ?? false,
    checkInAt: stringField(row, "check_in_at"),
    checkOutAt: stringField(row, "check_out_at"),
    updatedAt: stringField(row, "progress_updated_at")
  };
}

function dashboardQuizResult(row: JsonRecord): JsonRecord {
  return {
    studentId: stringField(row, "student_id"),
    classSessionId: stringField(row, "class_session_id"),
    quizId: stringField(row, "quiz_id"),
    resultText: stringField(row, "result_text"),
    scoreText: stringField(row, "score_text"),
    passed: boolFromUnknown(row.passed),
    completedAt: stringField(row, "completed_at"),
    updatedAt: stringField(row, "updated_at")
  };
}

function dashboardFinalResult(row: JsonRecord): JsonRecord {
  return {
    studentId: stringField(row, "student_id"),
    classSessionId: stringField(row, "class_session_id"),
    quizId: stringField(row, "quiz_id"),
    quizName: stringField(row, "quiz_name"),
    responseId: stringField(row, "response_id"),
    scoreText: stringField(row, "score_text"),
    resultText: stringField(row, "result_text"),
    passed: boolFromUnknown(row.passed),
    percentageScore: numberFromUnknown(row.percentage_score),
    points: numberFromUnknown(row.points),
    availablePoints: numberFromUnknown(row.available_points),
    completedAt: stringField(row, "completed_at"),
    updatedAt: stringField(row, "updated_at")
  };
}

function dashboardSkillsVerification(row: JsonRecord): JsonRecord {
  return {
    studentId: stringField(row, "student_id"),
    classSessionId: stringField(row, "class_session_id"),
    instructorPersonId: stringField(row, "instructor_person_id"),
    openedAt: stringField(row, "opened_at"),
    completedAt: stringField(row, "completed_at"),
    updatedAt: stringField(row, "updated_at")
  };
}

async function fetchJotformSubmission(env: Env, submissionId: string): Promise<JsonRecord> {
  const url = new URL(joinUrl(env.JOTFORM_BASE_URL, `/submission/${encodeURIComponent(submissionId)}`));
  url.searchParams.set("apiKey", env.JOTFORM_API_KEY ?? "");

  const response = await fetch(url, {
    headers: { accept: "application/json" }
  });

  if (response.status === 404) {
    throw new HttpError(404, "submission_not_found");
  }

  if (!response.ok) {
    throw new HttpError(502, "jotform_lookup_failed");
  }

  return await response.json<JsonRecord>();
}

function normalizeSessionLookup(source: JsonRecord, requestedSubmissionId: string): {
  formId: string;
  formType: "registration" | "refresher";
  attendee: NormalizedAttendee;
  options: SessionOption[];
} {
  const content = recordField(source, "content");
  const answers = recordField(content, "answers");
  if (!content || !answers) {
    throw new HttpError(502, "malformed_jotform_submission");
  }

  const submissionId = stringField(content, "id") ?? requestedSubmissionId;
  const formId = stringField(content, "form_id") ?? "";
  const isRegistration = Boolean(answer(answers, "39"));

  if (isRegistration) {
    return normalizeRegistrationSubmission(answers, submissionId, formId);
  }

  return normalizeRefresherSubmission(answers, submissionId, formId);
}

function normalizeRegistrationSubmission(
  answers: JsonRecord,
  submissionId: string,
  formId: string
): {
  formId: string;
  formType: "registration";
  attendee: NormalizedAttendee;
  options: SessionOption[];
} {
  const name = answerObject(answers, "4");
  const dobAnswer = answerObject(answers, "7");
  const dobValue = stringField(answer(answers, "7") ?? {}, "prettyFormat") ??
    normalizeDateToMMDDYYYY(stringField(dobAnswer, "datetime") ?? "");
  const location = answerString(answers, "46");
  const products = registrationProducts(answers);
  const firstProduct = products[0];
  const firstOption = firstProduct ? productToOption(firstProduct, location) : undefined;

  const attendee: NormalizedAttendee = {
    submissionId,
    firstName: stringField(name, "first") ?? "",
    lastName: stringField(name, "last") ?? "",
    email: answerString(answers, "5"),
    oemsId: answerString(answers, "6"),
    courseType: firstOption?.courseType ?? "",
    courseDate: firstOption?.dateRaw,
    courseId: firstOption?.courseId,
    ceuValue: firstOption?.ceuValue,
    productCategories: firstOption?.productCategories,
    dob: dobValue || undefined,
    courseImageURL: firstOption?.courseImageURL,
    courseLocation: location || undefined
  };

  return {
    formId,
    formType: "registration",
    attendee,
    options: products.map((product) => productToOption(product, location))
  };
}

function normalizeRefresherSubmission(
  answers: JsonRecord,
  submissionId: string,
  formId: string
): {
  formId: string;
  formType: "refresher";
  attendee: NormalizedAttendee;
  options: SessionOption[];
} {
  const options = [
    ["60", "Refresher A"],
    ["74", "Refresher B"],
    ["77", "Refresher C"]
  ].flatMap(([qid, label]) => {
    const rawDate = answerString(answers, qid);
    if (!rawDate) {
      return [];
    }
    return [{
      courseType: label,
      datePretty: rawDate,
      dateRaw: extractDatePart(rawDate) ?? rawDate
    }];
  });

  const firstOption = options[0];
  const attendee: NormalizedAttendee = {
    submissionId,
    firstName: answerString(answers, "32"),
    lastName: answerString(answers, "33"),
    email: answerString(answers, "4"),
    oemsId: answerString(answers, "6"),
    courseType: firstOption?.courseType ?? answerString(answers, "96"),
    courseDate: firstOption?.dateRaw
  };

  return {
    formId,
    formType: "refresher",
    attendee,
    options
  };
}

function registrationProducts(answers: JsonRecord): JsonRecord[] {
  const courseField = answer(answers, "39");
  if (!courseField) {
    return [];
  }

  const answerPayload = recordField(courseField, "answer");
  const selectedJson = answerPayload ? stringField(answerPayload, "1") : undefined;
  const selectedProduct = selectedJson ? parseJsonRecord(selectedJson) : undefined;
  const products = arrayField(courseField, "products").filter(isJsonRecord);

  if (selectedProduct) {
    return [selectedProduct, ...products.filter((product) => stringField(product, "name") !== stringField(selectedProduct, "name"))];
  }

  return products;
}

function productToOption(product: JsonRecord, courseLocation?: string): SessionOption {
  const name = firstNonEmpty(
    stringField(product, "name"),
    stringField(product, "title"),
    stringField(product, "label"),
    stringField(product, "text"),
    "Unnamed Course"
  );
  const description = stringField(product, "description") ?? "";
  const fields = parseDescriptionFields(description);
  return {
    courseType: cleanCourseName(name),
    datePretty: description || fields.date || "",
    dateRaw: fields.date ?? "",
    courseId: fields.courseId,
    ceuValue: fields.ceuValue,
    productCategories: productCategories(product),
    courseImageURL: firstImage(product),
    courseLocation: courseLocation || undefined
  };
}

function attendeeWithOption(attendee: NormalizedAttendee, option: SessionOption): NormalizedAttendee {
  return {
    ...attendee,
    courseType: option.courseType,
    courseDate: option.dateRaw || attendee.courseDate,
    courseId: option.courseId ?? attendee.courseId,
    ceuValue: option.ceuValue ?? attendee.ceuValue,
    productCategories: option.productCategories ?? attendee.productCategories,
    courseImageURL: option.courseImageURL ?? attendee.courseImageURL,
    courseLocation: option.courseLocation ?? attendee.courseLocation
  };
}

async function getProgress(url: URL, env: Env): Promise<Response> {
  const { classSessionId, studentId } = progressPath(url);
  if (!classSessionId || !studentId) {
    return json({ error: "bad_progress_path" }, 400);
  }

  const row = await env.DB.prepare(
    `SELECT * FROM student_progress WHERE class_session_id = ?1 AND student_id = ?2`
  ).bind(classSessionId, studentId).first<JsonRecord>();

  const attempts = await env.DB.prepare(
    `SELECT quiz_id, result_text, score_text, passed, completed_at, updated_at
     FROM quiz_attempts
     WHERE class_session_id = ?1 AND student_id = ?2
     ORDER BY COALESCE(completed_at, updated_at) DESC`
  ).bind(classSessionId, studentId).all<JsonRecord>();

  const quizResults: Record<string, string> = {};
  const completedQuizIds: string[] = [];
  for (const attempt of attempts.results ?? []) {
    const quizId = stringField(attempt, "quiz_id");
    if (!quizId || quizResults[quizId]) {
      continue;
    }
    completedQuizIds.push(quizId);
    quizResults[quizId] = quizResultSummary(attempt);
  }

  const finalExamResult = await latestFinalExamResult(env, studentId, classSessionId);

  const progress = row ? { ...row } : null;
  if (progress || completedQuizIds.length > 0 || finalExamResult) {
    return json({
      classSessionId,
      studentId,
      progress: {
        ...(progress ?? {
          did_check_in: 0,
          did_check_out: 0,
          did_open_skills: 0,
          did_open_quiz: completedQuizIds.length > 0 ? 1 : 0,
          check_in_at: null,
          updated_at: null
        }),
        completed_quiz_ids: completedQuizIds,
        quiz_results: quizResults,
        final_exam_result: finalExamResult ?? null
      }
    });
  }

  return json({ classSessionId, studentId, progress: null });
}

async function latestFinalExamResult(
  env: Env,
  studentId: string,
  classSessionId: string
): Promise<FinalExamResult | undefined> {
  const row = await env.DB.prepare(
    `SELECT quiz_id, quiz_name, response_id, score_text, result_text, passed,
            percentage_score, points, available_points, report_url, completed_at
     FROM final_exam_results
     WHERE student_id = ?1 AND class_session_id = ?2
     ORDER BY COALESCE(completed_at, updated_at) DESC
     LIMIT 1`
  ).bind(studentId, classSessionId).first<JsonRecord>();

  if (!row) {
    return undefined;
  }

  return {
    quizId: stringField(row, "quiz_id") ?? "",
    quizName: stringField(row, "quiz_name"),
    responseId: stringField(row, "response_id"),
    scoreText: stringField(row, "score_text"),
    resultText: stringField(row, "result_text"),
    passed: boolFromUnknown(row.passed),
    completedAt: stringField(row, "completed_at"),
    reportUrl: stringField(row, "report_url"),
    percentageScore: numberFromUnknown(row.percentage_score),
    points: numberFromUnknown(row.points),
    availablePoints: numberFromUnknown(row.available_points)
  };
}

async function patchProgress(request: Request, url: URL, env: Env): Promise<Response> {
  const { classSessionId, studentId } = progressPath(url);
  if (!classSessionId || !studentId) {
    return json({ error: "bad_progress_path" }, 400);
  }

  const body = await readJson(request);
  const now = new Date().toISOString();
  const id = `${classSessionId}:${studentId}`;
  const courseDate = stringField(body, "courseDate") ?? classSessionId;

  await ensureProgressParents(env, {
    studentId,
    classSessionId,
    oemsId: stringField(body, "oemsId") ?? studentId,
    firstName: stringField(body, "firstName") ?? "Unknown",
    lastName: stringField(body, "lastName") ?? "Student",
    email: stringField(body, "email"),
    courseId: stringField(body, "courseId"),
    courseTitle: stringField(body, "courseTitle") ?? "Class Session",
    courseDate,
    sourceSubmissionId: stringField(body, "sourceSubmissionId"),
    sourceFormId: stringField(body, "sourceFormId")
  });

  await env.DB.prepare(
    `INSERT INTO student_progress (
      id, student_id, class_session_id, did_check_in, did_check_out,
      did_open_skills, did_open_quiz, check_in_at, check_out_at,
      last_device_id, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
    ON CONFLICT(student_id, class_session_id) DO UPDATE SET
      did_check_in = max(did_check_in, excluded.did_check_in),
      did_check_out = max(did_check_out, excluded.did_check_out),
      did_open_skills = max(did_open_skills, excluded.did_open_skills),
      did_open_quiz = max(did_open_quiz, excluded.did_open_quiz),
      check_in_at = COALESCE(excluded.check_in_at, check_in_at),
      check_out_at = COALESCE(excluded.check_out_at, check_out_at),
      last_device_id = COALESCE(excluded.last_device_id, last_device_id),
      updated_at = excluded.updated_at`
  ).bind(
    id,
    studentId,
    classSessionId,
    boolInt(body.didCheckIn),
    boolInt(body.didCheckOut),
    boolInt(body.didOpenSkills),
    boolInt(body.didOpenQuiz),
    stringField(body, "checkInAt") ?? null,
    stringField(body, "checkOutAt") ?? null,
    stringField(body, "deviceId") ?? null,
    now
  ).run();

  await audit(env, "progress.patch", {
    studentId,
    classSessionId,
    deviceId: stringField(body, "deviceId"),
    payload: body
  });

  await touchDeviceContext(env, {
    deviceId: stringField(body, "deviceId"),
    studentId,
    classSessionId,
    email: stringField(body, "email")
  });

  if (boolFromUnknown(body.didCheckOut) === true) {
    await maybeSendInstructorCheckoutReminder(env, classSessionId);
  }

  return json({ ok: true, id, updatedAt: now });
}

async function registerDevice(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const token = stringField(body, "token");
  const deviceId = stringField(body, "deviceId");
  const apnsEnvironment = normalizeApnsEnvironment(stringField(body, "apnsEnvironment"));
  const platform = stringField(body, "platform") ?? "ios";

  if (!token || !deviceId) {
    return json({ error: "missing_device_token" }, 400);
  }

  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO device_tokens (
      token, device_id, apns_environment, platform, created_at, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?5)
    ON CONFLICT(token) DO UPDATE SET
      device_id = excluded.device_id,
      apns_environment = excluded.apns_environment,
      platform = excluded.platform,
      updated_at = excluded.updated_at`
  ).bind(token, deviceId, apnsEnvironment, platform, now).run();

  await audit(env, "device.registered", {
    deviceId,
    payload: {
      apnsEnvironment,
      platform,
      tokenSuffix: token.slice(-8)
    }
  });

  return json({ ok: true, updatedAt: now });
}

async function touchDeviceContext(
  env: Env,
  input: {
    deviceId?: string | null;
    studentId?: string | null;
    classSessionId?: string | null;
    email?: string | null;
    flexiquizUserId?: string | null;
  }
): Promise<void> {
  const deviceId = input.deviceId?.trim();
  if (!deviceId) {
    return;
  }

  await env.DB.prepare(
    `UPDATE device_tokens
     SET student_id = COALESCE(?2, student_id),
         class_session_id = COALESCE(?3, class_session_id),
         email = COALESCE(?4, email),
         flexiquiz_user_id = COALESCE(?5, flexiquiz_user_id),
         updated_at = ?6
     WHERE device_id = ?1`
  ).bind(
    deviceId,
    input.studentId ?? null,
    input.classSessionId ?? null,
    input.email ?? null,
    input.flexiquizUserId ?? null,
    new Date().toISOString()
  ).run();
}

async function touchInstructorDeviceContext(
  env: Env,
  input: {
    deviceId?: string | null;
    personId?: string | null;
    classSessionId?: string | null;
  }
): Promise<void> {
  const deviceId = input.deviceId?.trim();
  if (!deviceId) {
    return;
  }

  await env.DB.prepare(
    `UPDATE device_tokens
     SET instructor_person_id = COALESCE(?2, instructor_person_id),
         instructor_class_session_id = COALESCE(?3, instructor_class_session_id),
         updated_at = ?4
     WHERE device_id = ?1`
  ).bind(
    deviceId,
    input.personId ?? null,
    input.classSessionId ?? null,
    new Date().toISOString()
  ).run();
}

async function submitAttendance(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const formId = stringField(body, "formId");
  const inOut = stringField(body, "inOut");
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");
  const attendee = recordField(body, "attendee");
  const fields = recordField(body, "fields");
  const attestation = recordField(body, "attestation");
  const deviceId = stringField(body, "deviceId");

  if (!formId || !inOut || !studentId || !classSessionId || !attendee || !fields) {
    return json({ error: "missing_attendance_fields" }, 400);
  }

  if (!env.JOTFORM_API_KEY && !env.ACADEMY_RMS_BASE_URL) {
    return json({ error: "attendance_destinations_not_configured" }, 503);
  }

  const now = new Date().toISOString();
  const didCheckIn = inOut === "Check-In";
  const didCheckOut = inOut === "Check-Out";
  const warnings: string[] = [];
  let rms: { ok: boolean; attestationId?: string } | undefined;
  let jotform: { submissionId?: string } = {};

  if (env.ACADEMY_RMS_BASE_URL && env.ACADEMY_RMS_ATTENDANCE_SECRET && attestation) {
    try {
      rms = await postAcademyRmsAttendance(env, {
        formId,
        inOut,
        studentId,
        classSessionId,
        attendee,
        fields,
        attestation,
        deviceId,
        submittedAt: now
      });
    } catch (error) {
      console.error("rms attendance submit failed", error);
      warnings.push("rms_submit_failed");
    }
  } else {
    warnings.push("rms_attendance_not_configured");
  }

  if (env.JOTFORM_API_KEY) {
    try {
      jotform = await postJotformSubmission(env, formId, fields);
    } catch (error) {
      console.error("jotform attendance submit failed", error);
      warnings.push("jotform_submit_failed");
    }
  } else {
    warnings.push("jotform_not_configured");
  }

  if (!rms?.ok && !jotform.submissionId) {
    return json({ error: "attendance_submit_failed", warnings }, 502);
  }

  await ensureProgressParents(env, {
    studentId,
    classSessionId,
    oemsId: stringField(attendee, "oemsId") ?? studentId,
    firstName: stringField(attendee, "firstName") ?? "Unknown",
    lastName: stringField(attendee, "lastName") ?? "Student",
    email: stringField(attendee, "email"),
    courseId: stringField(attendee, "courseId"),
    courseTitle: stringField(attendee, "courseType") ?? "Class Session",
    courseDate: stringField(attendee, "courseDate") ?? classSessionId,
    sourceSubmissionId: stringField(attendee, "submissionId"),
    sourceFormId: formId
  });

  await writeProgress(env, {
    studentId,
    classSessionId,
    didCheckIn,
    didCheckOut,
    checkInAt: didCheckIn ? now : undefined,
    checkOutAt: didCheckOut ? now : undefined,
    deviceId
  });

  await touchDeviceContext(env, {
    deviceId,
    studentId,
    classSessionId,
    email: stringField(attendee, "email")
  });

  await audit(env, "attendance.submit", {
    studentId,
    classSessionId,
    deviceId,
    payload: {
      formId,
      inOut,
      jotformSubmissionId: jotform.submissionId ?? null,
      rmsAttestationId: rms?.attestationId ?? null,
      warnings
    }
  });

  if (didCheckOut) {
    await maybeSendInstructorCheckoutReminder(env, classSessionId);
  }

  return json({
    ok: true,
    formId,
    inOut,
    submissionId: jotform.submissionId,
    rmsAttestationId: rms?.attestationId,
    warnings,
    updatedAt: now
  });
}

async function postAcademyRmsAttendance(
  env: Env,
  payload: JsonRecord
): Promise<{ ok: boolean; attestationId?: string }> {
  const url = joinUrl(env.ACADEMY_RMS_BASE_URL ?? "", "/api/webhooks/classmanager-attendance");
  const response = await fetch(url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "x-classmanager-secret": env.ACADEMY_RMS_ATTENDANCE_SECRET ?? ""
    },
    body: JSON.stringify(payload)
  });
  const parsed: JsonRecord = await response.json<JsonRecord>().catch(() => ({}));
  if (!response.ok || parsed.ok === false) {
    throw new HttpError(response.status || 502, stringField(parsed, "error") ?? "rms_submit_failed");
  }
  return {
    ok: true,
    attestationId: stringField(parsed, "attestation_id") ?? stringField(parsed, "attestationId")
  };
}

async function postJotformSubmission(
  env: Env,
  formId: string,
  fields: JsonRecord
): Promise<{ submissionId?: string }> {
  const url = new URL(joinUrl(env.JOTFORM_BASE_URL, `/form/${encodeURIComponent(formId)}/submissions`));
  url.searchParams.set("apiKey", env.JOTFORM_API_KEY ?? "");
  const body = new URLSearchParams();

  for (const [key, value] of Object.entries(fields)) {
    if (typeof value === "string" && value.trim().length > 0) {
      body.set(jotformSubmissionFieldName(key), value.trim());
    }
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/x-www-form-urlencoded; charset=utf-8"
    },
    body
  });

  if (!response.ok) {
    throw new HttpError(502, "jotform_submit_failed");
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  const content = recordField(data, "content");
  return {
    submissionId: content ? stringField(content, "submissionID") : undefined
  };
}

function jotformSubmissionFieldName(key: string): string {
  const clean = key.trim();
  const firstBracket = clean.indexOf("[");
  if (firstBracket === -1) {
    return `submission[${clean}]`;
  }

  const root = clean.slice(0, firstBracket);
  const suffix = clean.slice(firstBracket);
  return `submission[${root}]${suffix}`;
}

async function writeProgress(
  env: Env,
  input: {
    studentId: string;
    classSessionId: string;
    didCheckIn?: boolean;
    didCheckOut?: boolean;
    didOpenSkills?: boolean;
    didOpenQuiz?: boolean;
    checkInAt?: string;
    checkOutAt?: string;
    deviceId?: string;
  }
): Promise<void> {
  const now = new Date().toISOString();
  const id = `${input.classSessionId}:${input.studentId}`;

  await env.DB.prepare(
    `INSERT INTO student_progress (
      id, student_id, class_session_id, did_check_in, did_check_out,
      did_open_skills, did_open_quiz, check_in_at, check_out_at,
      last_device_id, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
    ON CONFLICT(student_id, class_session_id) DO UPDATE SET
      did_check_in = max(did_check_in, excluded.did_check_in),
      did_check_out = max(did_check_out, excluded.did_check_out),
      did_open_skills = max(did_open_skills, excluded.did_open_skills),
      did_open_quiz = max(did_open_quiz, excluded.did_open_quiz),
      check_in_at = COALESCE(excluded.check_in_at, check_in_at),
      check_out_at = COALESCE(excluded.check_out_at, check_out_at),
      last_device_id = COALESCE(excluded.last_device_id, last_device_id),
      updated_at = excluded.updated_at`
  ).bind(
    id,
    input.studentId,
    input.classSessionId,
    input.didCheckIn ? 1 : 0,
    input.didCheckOut ? 1 : 0,
    input.didOpenSkills ? 1 : 0,
    input.didOpenQuiz ? 1 : 0,
    input.checkInAt ?? null,
    input.checkOutAt ?? null,
    input.deviceId ?? null,
    now
  ).run();
}

async function ensureProgressParents(
  env: Env,
  input: {
    studentId: string;
    classSessionId: string;
    oemsId?: string;
    firstName: string;
    lastName: string;
    email?: string;
    courseId?: string;
    courseTitle: string;
    courseDate: string;
    sourceSubmissionId?: string;
    sourceFormId?: string;
  }
): Promise<void> {
  const now = new Date().toISOString();

  await env.DB.prepare(
    `INSERT INTO students (id, oems_id, first_name, last_name, email, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6)
     ON CONFLICT(id) DO UPDATE SET
       oems_id = COALESCE(excluded.oems_id, oems_id),
       first_name = CASE WHEN excluded.first_name != 'Unknown' THEN excluded.first_name ELSE first_name END,
       last_name = CASE WHEN excluded.last_name != 'Student' THEN excluded.last_name ELSE last_name END,
       email = COALESCE(excluded.email, email),
       updated_at = excluded.updated_at`
  ).bind(
    input.studentId,
    input.oemsId ?? null,
    input.firstName,
    input.lastName,
    input.email ?? null,
    now
  ).run();

  await env.DB.prepare(
    `INSERT INTO class_sessions (
      id, course_id, course_title, course_date, source_submission_id, source_form_id, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
    ON CONFLICT(id) DO UPDATE SET
      course_id = COALESCE(excluded.course_id, course_id),
      course_title = CASE WHEN excluded.course_title != 'Class Session' THEN excluded.course_title ELSE course_title END,
      course_date = excluded.course_date,
      source_submission_id = COALESCE(excluded.source_submission_id, source_submission_id),
      source_form_id = COALESCE(excluded.source_form_id, source_form_id),
      updated_at = excluded.updated_at`
  ).bind(
    input.classSessionId,
    input.courseId ?? null,
    input.courseTitle,
    input.courseDate,
    input.sourceSubmissionId ?? null,
    input.sourceFormId ?? null,
    now
  ).run();
}

async function assignQuiz(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const email = stringField(body, "email");
  const quizId = stringField(body, "quizId");
  const firstName = stringField(body, "firstName") ?? "";
  const lastName = stringField(body, "lastName") ?? "";
  const oemsId = stringField(body, "oemsId") ?? "";
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");
  const sourceSubmissionId = stringField(body, "sourceSubmissionId") ?? stringField(body, "submissionId");
  const courseTitle = stringField(body, "courseTitle") ?? "Class Session";
  const courseDate = stringField(body, "courseDate") ?? classSessionId ?? "undated";
  const deviceId = stringField(body, "deviceId");

  if (!email || !quizId) {
    return json({ error: "missing_email_or_quiz_id" }, 400);
  }

  if (!env.FLEXIQUIZ_API_KEY || !env.FLEXIQUIZ_SSO_SHARED_SECRET) {
    return json({ error: "flexiquiz_not_configured" }, 503);
  }

  const warnings: string[] = [];
  const quizCheck = await flexiQuizStatus(env, quizId);
  if (!quizCheck.ok) {
    await audit(env, "quiz.preflight.failed", {
      studentId,
      classSessionId,
      deviceId,
      payload: { email, quizId, status: quizCheck.status, body: quizCheck.body }
    });
    return json({ error: "flexiquiz_quiz_unavailable", status: quizCheck.status, warnings }, 502);
  }

  const flexiquizUserName = classRegistrationFlexiQuizUserName({
    email,
    sourceSubmissionId,
    studentId,
    classSessionId
  });
  let flexiquizUserId = await flexiFindUserId(env, flexiquizUserName);
  let flexiUserProfile: FlexiUserProfile | undefined;

  if (!flexiquizUserId) {
    flexiquizUserId = await flexiCreateUser(env, {
      userName: flexiquizUserName,
      email,
      firstName,
      lastName,
      password: classRegistrationFlexiQuizPassword({ lastName, oemsId, sourceSubmissionId, studentId })
    }).catch((error) => {
      console.warn("flexiquiz create failed", error);
      warnings.push("flexiquiz_create_failed");
      return undefined;
    });
  }

  if (flexiquizUserId) {
    flexiUserProfile = await flexiGetUserProfile(env, flexiquizUserId);
    if (!flexiUserProfile) {
      warnings.push("flexiquiz_user_profile_unavailable");
    }
    const alreadyAssigned = flexiUserProfile
      ? flexiUserHasQuiz(flexiUserProfile, quizId)
      : await flexiUserHasQuizByEndpoint(env, flexiquizUserId, quizId);
    let assignmentStatus: { ok: boolean; status: number; body?: string } | undefined;
    if (!alreadyAssigned) {
      assignmentStatus = await flexiAssignQuiz(env, flexiquizUserId, quizId);
      if (!assignmentStatus.ok) {
        warnings.push("flexiquiz_assign_failed");
        await audit(env, "quiz.assign.failed", {
          studentId,
          classSessionId,
          deviceId,
          payload: { email, quizId, flexiquizUserId, flexiquizUserName, status: assignmentStatus.status, body: assignmentStatus.body }
        });
      }
      flexiUserProfile = await flexiGetUserProfile(env, flexiquizUserId) ?? flexiUserProfile;
    }

    const hasQuizAccess = flexiUserProfile
      ? flexiUserHasQuiz(flexiUserProfile, quizId)
      : alreadyAssigned;
    if (!hasQuizAccess) {
      await audit(env, "quiz.assign.unavailable", {
        studentId,
        classSessionId,
        deviceId,
        payload: {
          email,
          quizId,
          flexiquizUserId,
          flexiquizUserName,
          status: assignmentStatus?.status ?? null,
          body: assignmentStatus?.body ?? null,
          quizCount: flexiUserProfile?.quizzes.length ?? null,
          warnings
        }
      });
      return json({
        error: "flexiquiz_quiz_not_assigned",
        status: assignmentStatus?.status ?? null,
        warnings
      }, 502);
    }
  } else {
    return json({ error: "flexiquiz_user_not_confirmed", warnings }, 502);
  }

  const launchUrl = await buildFlexiQuizSsoUrl(env, flexiquizUserId, quizId);

  if (studentId && classSessionId) {
    await ensureProgressParents(env, {
      studentId,
      classSessionId,
      oemsId: oemsId || studentId,
      firstName: firstName || "Unknown",
      lastName: lastName || "Student",
      email,
      courseTitle,
      courseDate,
      sourceSubmissionId
    });
    await writeProgress(env, {
      studentId,
      classSessionId,
      didOpenQuiz: true,
      deviceId
    });
    await touchDeviceContext(env, {
      deviceId,
      studentId,
      classSessionId,
      email,
      flexiquizUserId
    });
  }

  await audit(env, "quiz.assign.requested", {
    studentId,
    classSessionId,
    deviceId,
    payload: { email, quizId, flexiquizUserId: flexiquizUserId ?? null, flexiquizUserName, jwtSubject: "user_id", sourceSubmissionId: sourceSubmissionId ?? null, warnings }
  });

  return json({
    ok: true,
    email,
    quizId,
    launchUrl,
    flexiquizUserId,
    flexiquizUserName,
    warnings
  });
}

async function flexiFindUserId(env: Env, userName: string): Promise<string | undefined> {
  const response = await flexiPost(env, "/v1/users/find", {
    user_name: userName
  });

  if (!response.ok) {
    return undefined;
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  return stringField(data, "user_id");
}

function classRegistrationFlexiQuizUserName(input: {
  email?: string;
  sourceSubmissionId?: string;
  studentId?: string;
  classSessionId?: string;
}): string {
  const registrationKey = slugForFlexiQuizIdentity(input.sourceSubmissionId);
  if (registrationKey) {
    return `classmanager.${registrationKey}@gcemstrainingacademy.org`;
  }

  const studentKey = slugForFlexiQuizIdentity(input.studentId);
  const sessionKey = slugForFlexiQuizIdentity(input.classSessionId);
  if (studentKey && sessionKey) {
    return `classmanager.${studentKey}.${sessionKey}@gcemstrainingacademy.org`;
  }

  return (input.email ?? "").trim().toLowerCase();
}

function classRegistrationFlexiQuizPassword(input: {
  lastName?: string;
  oemsId?: string;
  sourceSubmissionId?: string;
  studentId?: string;
}): string {
  const base = [
    input.lastName,
    input.oemsId,
    input.sourceSubmissionId,
    input.studentId
  ].map((value) => value?.trim()).find(Boolean);
  return `${base ?? crypto.randomUUID()}!Cm3`;
}

function slugForFlexiQuizIdentity(value?: string): string {
  return (value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

async function flexiQuizStatus(env: Env, quizId: string): Promise<{ ok: boolean; status: number; body?: string }> {
  const response = await flexiGet(env, `/v1/quizzes/${encodeURIComponent(quizId)}`);
  const text = await response.text().catch(() => "");
  if (!response.ok) {
    return { ok: false, status: response.status, body: text };
  }

  const data = text ? parseJsonRecord(text) ?? {} : {};
  const status = stringField(data, "status")?.toLowerCase();
  if (status && status !== "open") {
    return { ok: false, status: 409, body: text };
  }

  return { ok: true, status: response.status };
}

async function flexiCreateUser(
  env: Env,
  input: {
    userName: string;
    email: string;
    firstName: string;
    lastName: string;
    password: string;
  }
): Promise<string | undefined> {
  const response = await flexiPost(env, "/v1/users", {
    user_name: input.userName,
    password: input.password,
    user_type: "respondent",
    email_address: input.email,
    first_name: input.firstName,
    last_name: input.lastName,
    suspended: "false",
    manage_users: "false",
    manage_groups: "false",
    edit_quizzes: "false",
    send_welcome_email: "false"
  });

  if (!response.ok) {
    return undefined;
  }

  const data = await response.json<JsonRecord>().catch(() => ({}));
  return stringField(data, "user_id");
}

async function flexiGetUserProfile(env: Env, userId: string): Promise<FlexiUserProfile | undefined> {
  const response = await flexiGet(env, `/v1/users/${encodeURIComponent(userId)}`);
  if (!response.ok) {
    return undefined;
  }
  const payload = await response.json<unknown>().catch(() => undefined);
  const record = recordFromPayload(payload);
  if (!record) {
    return undefined;
  }
  const userName = stringField(record, "user_name");
  const resolvedUserId = stringField(record, "user_id") ?? userId;
  if (!userName) {
    return undefined;
  }
  return {
    userId: resolvedUserId,
    userName,
    email: stringField(record, "email_address"),
    quizzes: arrayField(record, "quizzes").filter(isJsonRecord)
  };
}

function flexiUserHasQuiz(profile: FlexiUserProfile, quizId: string): boolean {
  return profile.quizzes.some((record) =>
    stringField(record, "quiz_id") === quizId ||
    stringField(record, "quizId") === quizId
  );
}

async function flexiUserHasQuizByEndpoint(env: Env, userId: string, quizId: string): Promise<boolean> {
  const response = await flexiGet(env, `/v1/users/${encodeURIComponent(userId)}/quizzes`);
  if (!response.ok) {
    return false;
  }
  const payload = await response.json<unknown>().catch(() => undefined);
  return recordsFromPayload(payload).some((record) => stringField(record, "quiz_id") === quizId || stringField(record, "quizId") === quizId);
}

async function flexiAssignQuiz(env: Env, userId: string, quizId: string): Promise<{ ok: boolean; status: number; body?: string }> {
  const response = await flexiPost(env, `/v1/users/${encodeURIComponent(userId)}/quizzes`, {
    quiz_id: quizId
  });
  return {
    ok: response.ok,
    status: response.status,
    body: response.ok ? undefined : await response.text().catch(() => undefined)
  };
}

async function flexiDeleteUser(env: Env, userId: string): Promise<{ ok: boolean; status: number; body?: string }> {
  const response = await flexiRequest(env, "DELETE", `/v1/users/${encodeURIComponent(userId)}`);
  return {
    ok: response.ok || response.status === 404,
    status: response.status,
    body: response.ok ? undefined : await response.text().catch(() => undefined)
  };
}

async function flexiPost(env: Env, path: string, fields: Record<string, string>): Promise<Response> {
  const url = new URL(joinUrl(env.FLEXIQUIZ_API_BASE, path));
  const body = new URLSearchParams();
  for (const [key, value] of Object.entries(fields)) {
    body.set(key, value);
  }

  return await fetch(url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/x-www-form-urlencoded; charset=utf-8",
      "x-api-key": env.FLEXIQUIZ_API_KEY ?? ""
    },
    body
  });
}

async function flexiRequest(env: Env, method: string, path: string): Promise<Response> {
  const url = new URL(joinUrl(env.FLEXIQUIZ_API_BASE, path));
  return await fetch(url, {
    method,
    headers: {
      accept: "application/json",
      "x-api-key": env.FLEXIQUIZ_API_KEY ?? ""
    }
  });
}

async function quizReview(url: URL, env: Env): Promise<Response> {
  const quizId = decodeURIComponent(url.pathname.split("/").pop() ?? "");
  const email = url.searchParams.get("email")?.trim();
  const studentId = url.searchParams.get("studentId")?.trim();
  const classSessionId = url.searchParams.get("classSessionId")?.trim();
  const sourceSubmissionId = url.searchParams.get("sourceSubmissionId")?.trim() || undefined;
  const deviceId = url.searchParams.get("deviceId")?.trim();
  const includeInProgress = url.searchParams.get("includeInProgress") === "1";
  const questionStart = intFromUnknown(url.searchParams.get("questionStart") ?? undefined);
  const questionEnd = intFromUnknown(url.searchParams.get("questionEnd") ?? undefined);
  const debug = url.searchParams.get("debug") === "1";

  if (!quizId) {
    return json({ error: "missing_quiz_id" }, 400);
  }

  if (!env.FLEXIQUIZ_API_KEY) {
    return json({ error: "flexiquiz_not_configured" }, 503);
  }

  if (!email) {
    const cached = await cachedQuizReview(env, quizId);
    if (cached) {
      return json(cached);
    }
    return json({ error: "missing_email" }, 400);
  }

  const flexiquizUserName = classRegistrationFlexiQuizUserName({
    email,
    sourceSubmissionId,
    studentId,
    classSessionId
  });
  const flexiquizUserId = await flexiFindUserId(env, flexiquizUserName);
  if (!flexiquizUserId) {
    return json({ error: "flexiquiz_user_not_found" }, 404);
  }

  const responses = await flexiListResponses(env, flexiquizUserId, quizId);
  const latest = includeInProgress
    ? responses[0]
    : responses.find((item) => responseLooksCompleted(item)) ?? responses[0];
  if (!latest) {
    return json({ error: "review_not_found" }, 404);
  }
  if (!includeInProgress && !responseLooksCompleted(latest)) {
    return json({ error: "review_not_submitted" }, 404);
  }

  const responseId = responseIdFrom(latest);
  const warnings: string[] = [];
  let detail: JsonRecord | undefined;
  let responseQuestions: JsonRecord[] = [];

  if (responseId) {
    responseQuestions = await flexiResponseQuestions(env, quizId, responseId).catch((error) => {
      console.warn("FlexiQuiz response questions lookup failed", error);
      warnings.push("response_questions_unavailable");
      return [];
    });
    if (responseQuestions.length > 0) {
      warnings.push("response_questions_loaded");
    }
    detail = await flexiResponseDetail(env, flexiquizUserId, quizId, responseId);
    if (!detail) {
      warnings.push("response_detail_unavailable");
    }
  } else {
    warnings.push("response_id_unavailable");
  }

  const reportUrl = firstText([detail, latest], [
    "response_report_url",
    "responseReportUrl",
    "report_url",
    "review_url",
    "reviewUrl"
  ]);
  let reportHtml: string | undefined;
  if (reportUrl) {
    reportHtml = await fetchTextLimited(reportUrl, 250_000).catch(() => undefined);
    if (!reportHtml) {
      warnings.push("response_report_unavailable");
    }
  }

  let review = normalizeQuizReview({
    quizId,
    latest,
    detail,
    questionRecords: responseQuestions,
    reportHtml,
    fallbackResponseId: responseId,
    fallbackReportUrl: reportUrl,
    warnings
  });

  try {
    const rmsReview = await fetchRmsQuizReview(env, {
      responseId: review.responseId ?? responseId,
      quizId,
      email,
      flexiquizUserId,
      debug
    });
    if (rmsReview) {
      const rmsWarning = firstText([rmsReview], ["__rmsLookupWarning"]);
      if (rmsWarning) {
        review.warnings.push(rmsWarning);
      } else {
        if (debug) {
          const rows = Array.isArray(rmsReview.question_rows) ? rmsReview.question_rows.length : -1;
          const count = firstText([recordField(rmsReview, "result")], ["question_count"]);
          review.warnings.push(`rms_review_rows_${rows}${count ? `_count_${count}` : ""}`);
        }
        review = mergeRmsQuizReview(review, rmsReview);
      }
    }
  } catch (error) {
    console.warn("RMS quiz review merge failed", error);
    review.warnings.push("rms_review_unavailable");
  }

  review = applyQuestionRationales(review);
  review = filterQuizReviewQuestions(review, questionStart, questionEnd);
  if (debug) {
    review.warnings.push("debug_seen");
  }

  if (studentId && classSessionId) {
    await audit(env, "quiz.review.requested", {
      studentId,
      classSessionId,
      deviceId,
      payload: {
        quizId,
        flexiquizUserName,
        responseId: review.responseId ?? null,
        scoreText: review.scoreText ?? null,
        passed: review.passed ?? null,
        questionCount: review.questions.length,
        questions: review.questions.slice(0, 100).map((question) => ({
          prompt: question.prompt,
          isCorrect: question.isCorrect ?? null,
          feedback: question.feedback ?? null
        })),
        warnings: review.warnings
      }
    });
    const completedReview = reviewLooksCompleted(review, latest);
    if (includeInProgress || completedReview) {
      await saveQuizAttempt(env, {
        studentId,
        classSessionId,
        flexiquizUserId,
        review,
        questionStart,
        questionEnd
      }).catch((error) => console.warn("quiz attempt save failed", error));
    }
    if (!questionStart && !questionEnd && review.responseId && completedReview) {
      const finalSources = [detail ?? {}, latest];
      const passingScore = minimumPassingScoreForQuiz(quizId, finalSources);
      const scoreText = review.scoreText ?? scoreTextFromSources(finalSources);
      const resultText = review.resultText ?? firstText(finalSources, ["grade", "result", "result_text", "response_status", "status"]);
      await saveFinalExamResult(env, {
        quizId,
        quizName: firstText(finalSources, ["quiz_name", "quizName", "name", "title"]),
        responseId: review.responseId,
        scoreText,
        resultText,
        passed: review.passed ??
          passStatusFromText(resultText ?? scoreText) ??
          passStatusFromScore(scoreText, passingScore),
        completedAt: review.completedAt ?? stringField(latest, "date_submitted") ?? stringField(latest, "submitted_at") ?? stringField(latest, "completed_at"),
        reportUrl: review.reportUrl,
        percentageScore: firstNumber(finalSources, ["percentage_score", "percentageScore"]),
        points: firstNumber(finalSources, ["points"]),
        availablePoints: firstNumber(finalSources, ["available_points", "availablePoints"]),
        studentId,
        classSessionId,
        email,
        flexiquizUserId,
        raw: {
          source: "quiz_review",
          latest,
          detail: detail ?? null,
          warnings: review.warnings
        }
      }).catch((error) => console.warn("final exam direct save failed", error));
    }
    await touchDeviceContext(env, {
      deviceId,
      studentId,
      classSessionId,
      email,
      flexiquizUserId
    });
  }

  return json(review);
}

async function rmsFlexiQuizResult(request: Request, env: Env): Promise<Response> {
  if (!rmsCallbackAuthorized(request, env)) {
    return json({ error: "unauthorized" }, 401);
  }

  const body = await readJson(request);
  const result = recordField(body, "result") ?? body;
  const responseId = stringField(result, "response_id") ?? stringField(result, "responseId");
  const quizId = stringField(result, "quiz_id") ?? stringField(result, "quizId");
  const email = stringField(result, "email_address") ?? stringField(result, "email") ?? stringField(result, "user_name");
  const flexiquizUserId = stringField(result, "user_id") ?? stringField(result, "userId");

  if (!responseId || !quizId || (!email && !flexiquizUserId)) {
    return json({ error: "missing_flexiquiz_result_identity" }, 400);
  }

  const contexts = await matchingDeviceContexts(env, { email, flexiquizUserId });
  const finalResult = finalExamResultFromRms(result);
  let saved = 0;
  let sent = 0;
  let failed = 0;

  for (const context of contexts) {
    const studentId = stringField(context, "student_id");
    const classSessionId = stringField(context, "class_session_id");
    if (!studentId || !classSessionId) {
      continue;
    }

    await saveFinalExamResult(env, {
      ...finalResult,
      quizId,
      responseId,
      studentId,
      classSessionId,
      email,
      flexiquizUserId,
      raw: result
    });
    saved += 1;

    const token = stringField(context, "token");
    if (!token) {
      continue;
    }
    try {
      await sendFinalExamApns(env, {
        token,
        apnsEnvironment: normalizeApnsEnvironment(stringField(context, "apns_environment")),
        studentId,
        classSessionId,
        result: {
          ...finalResult,
          quizId,
          responseId
        }
      });
      sent += 1;
      await env.DB.prepare(
        `UPDATE device_tokens SET last_push_at = ?2, updated_at = ?2 WHERE token = ?1`
      ).bind(token, new Date().toISOString()).run();
    } catch (error) {
      failed += 1;
      await handleApnsFailure(env, token, error);
      console.warn("final exam APNs failed", { tokenSuffix: token.slice(-8), error: String(error) });
    }
  }

  await audit(env, "rms.flexiquiz.final_result", {
    payload: {
      quizId,
      responseId,
      email,
      flexiquizUserId,
      passed: finalResult.passed ?? null,
      scoreText: finalResult.scoreText ?? null,
      saved,
      sent,
      failed
    }
  });

  return json({ ok: true, matched: contexts.length, saved, sent, failed });
}

async function matchingDeviceContexts(
  env: Env,
  input: { email?: string; flexiquizUserId?: string }
): Promise<JsonRecord[]> {
  const email = input.email?.trim().toLowerCase();
  const flexiquizUserId = input.flexiquizUserId?.trim();
  const rows = await env.DB.prepare(
    `SELECT token, device_id, apns_environment, student_id, class_session_id, email, flexiquiz_user_id
     FROM device_tokens
     WHERE (?1 IS NOT NULL AND LOWER(COALESCE(email, '')) = ?1)
        OR (?2 IS NOT NULL AND COALESCE(flexiquiz_user_id, '') = ?2)
     ORDER BY updated_at DESC
     LIMIT 20`
  ).bind(email ?? null, flexiquizUserId ?? null).all<JsonRecord>();

  const seen = new Set<string>();
  const unique: JsonRecord[] = [];
  for (const row of rows.results ?? []) {
    const token = stringField(row, "token");
    if (!token || seen.has(token)) {
      continue;
    }
    seen.add(token);
    unique.push(row);
  }
  return unique;
}

async function maybeSendInstructorCheckoutReminder(env: Env, classSessionId: string): Promise<void> {
  const counts = await env.DB.prepare(
    `SELECT
       SUM(CASE WHEN did_check_in = 1 THEN 1 ELSE 0 END) AS checked_in_count,
       SUM(CASE WHEN did_check_in = 1 AND did_check_out = 1 THEN 1 ELSE 0 END) AS checked_out_count
     FROM student_progress
     WHERE class_session_id = ?1`
  ).bind(classSessionId).first<JsonRecord>();
  const checkedIn = numberFromUnknown(counts?.checked_in_count) ?? 0;
  const checkedOut = numberFromUnknown(counts?.checked_out_count) ?? 0;
  if (checkedIn === 0 || checkedIn !== checkedOut) {
    return;
  }

  const instructors = await env.DB.prepare(
    `SELECT ia.id, ia.person_id, ia.course_title, dt.token, dt.apns_environment
     FROM instructor_attendance ia
     JOIN device_tokens dt
       ON dt.instructor_person_id = ia.person_id
      AND dt.instructor_class_session_id = ia.class_session_id
     WHERE ia.class_session_id = ?1
       AND ia.checked_out_at IS NULL
       AND ia.checkout_reminder_sent_at IS NULL
     ORDER BY ia.checked_in_at DESC
     LIMIT 20`
  ).bind(classSessionId).all<JsonRecord>();

  for (const row of instructors.results ?? []) {
    const token = stringField(row, "token");
    const attendanceId = stringField(row, "id");
    if (!token || !attendanceId) {
      continue;
    }
    try {
      await sendInstructorReminderApns(env, {
        token,
        apnsEnvironment: normalizeApnsEnvironment(stringField(row, "apns_environment")),
        classSessionId,
        title: "Instructor checkout needed",
        body: `All students are checked out for ${stringField(row, "course_title") ?? "this class"}. Please complete instructor checkout.`
      });
      await env.DB.prepare(
        `UPDATE instructor_attendance
         SET checkout_reminder_sent_at = ?2, updated_at = ?2
         WHERE id = ?1`
      ).bind(attendanceId, new Date().toISOString()).run();
    } catch (error) {
      await handleApnsFailure(env, token, error);
      console.warn("instructor checkout APNs failed", { tokenSuffix: token.slice(-8), error: String(error) });
    }
  }
}

async function notifyInstructorDashboard(
  env: Env,
  input: {
    classSessionId: string;
    studentId?: string;
    event: string;
    title: string;
    body: string;
    quizId?: string;
    responseId?: string;
    scoreText?: string;
    resultText?: string;
    completedAt?: string;
  }
): Promise<void> {
  const instructors = await env.DB.prepare(
    `SELECT DISTINCT dt.token, dt.apns_environment
     FROM instructor_attendance ia
     JOIN device_tokens dt
       ON dt.instructor_person_id = ia.person_id
      AND dt.instructor_class_session_id = ia.class_session_id
     WHERE ia.class_session_id = ?1
       AND ia.checked_in_at IS NOT NULL
     ORDER BY dt.updated_at DESC
     LIMIT 20`
  ).bind(input.classSessionId).all<JsonRecord>();

  let sent = 0;
  let failed = 0;
  for (const row of instructors.results ?? []) {
    const token = stringField(row, "token");
    if (!token) {
      continue;
    }
    try {
      await sendInstructorDashboardApns(env, {
        token,
        apnsEnvironment: normalizeApnsEnvironment(stringField(row, "apns_environment")),
        ...input
      });
      sent += 1;
      await env.DB.prepare(
        `UPDATE device_tokens SET last_push_at = ?2, updated_at = ?2 WHERE token = ?1`
      ).bind(token, new Date().toISOString()).run();
    } catch (error) {
      failed += 1;
      await handleApnsFailure(env, token, error);
      console.warn("instructor dashboard APNs failed", { tokenSuffix: token.slice(-8), error: String(error) });
    }
  }

  await audit(env, "instructor.dashboard.push", {
    studentId: input.studentId,
    classSessionId: input.classSessionId,
    payload: {
      event: input.event,
      quizId: input.quizId ?? null,
      responseId: input.responseId ?? null,
      scoreText: input.scoreText ?? null,
      sent,
      failed
    }
  });
}

async function studentDisplayName(env: Env, studentId?: string): Promise<string> {
  if (!studentId) {
    return "Student";
  }
  const row = await env.DB.prepare(
    `SELECT first_name, last_name
     FROM students
     WHERE id = ?1
     LIMIT 1`
  ).bind(studentId).first<JsonRecord>();
  const name = [stringField(row ?? {}, "first_name"), stringField(row ?? {}, "last_name")]
    .filter(Boolean)
    .join(" ")
    .trim();
  return name || "Student";
}

function finalExamResultFromRms(result: JsonRecord): FinalExamResult {
  const percentageScore = firstNumber([result], ["percentage_score", "percentageScore"]);
  const points = firstNumber([result], ["points"]);
  const availablePoints = firstNumber([result], ["available_points", "availablePoints"]);
  const scoreText = scoreTextFromSources([result]);
  const resultText = firstText([result], ["grade", "result", "result_text", "response_status", "status"]);
  const passingScore = minimumPassingScoreForFinalExam(result);
  const passed = (percentageScore !== undefined ? percentageScore >= passingScore : undefined) ??
    boolFromUnknown(firstValue([result], ["passed", "pass"])) ??
    passStatusFromText(resultText ?? scoreText) ??
    passStatusFromScore(scoreText, passingScore);

  return {
    quizId: stringField(result, "quiz_id") ?? stringField(result, "quizId") ?? "",
    quizName: stringField(result, "quiz_name") ?? stringField(result, "quizName"),
    responseId: stringField(result, "response_id") ?? stringField(result, "responseId"),
    scoreText,
    resultText,
    passed,
    completedAt: stringField(result, "submitted_at") ?? stringField(result, "submittedAt") ?? stringField(result, "completed_at"),
    reportUrl: stringField(result, "response_report_url") ?? stringField(result, "responseReportUrl"),
    percentageScore,
    points,
    availablePoints
  };
}

function minimumPassingScoreForFinalExam(result: JsonRecord): number {
  const quizId = stringField(result, "quiz_id") ?? stringField(result, "quizId") ?? "";
  return minimumPassingScoreForQuiz(quizId, [result]);
}

function minimumPassingScoreForQuiz(quizId: string, sources: JsonRecord[]): number {
  const quizName = (firstText(sources, ["quiz_name", "quizName", "name", "title"]) ?? "").toLowerCase();
  if (
    quizId === REFRESHER_A_VERSION_B_QUIZ_ID ||
    quizId === REFRESHER_B_VERSION_B_QUIZ_ID ||
    quizId === REFRESHER_C_VERSION_B_QUIZ_ID ||
    quizName.includes("version b")
  ) {
    return REFRESHER_VERSION_B_PASSING_SCORE;
  }
  if (
    quizId === REFRESHER_A_COMBINED_QUIZ_ID ||
    quizId === REFRESHER_B_COMBINED_QUIZ_ID ||
    quizId === REFRESHER_C_COMBINED_QUIZ_ID ||
    quizName.includes("refresher a") ||
    quizName.includes("refresher b") ||
    quizName.includes("refresher c")
  ) {
    return REFRESHER_VERSION_A_PASSING_SCORE;
  }
  return REFRESHER_VERSION_A_PASSING_SCORE;
}

async function saveFinalExamResult(
  env: Env,
  input: FinalExamResult & {
    studentId: string;
    classSessionId: string;
    email?: string;
    flexiquizUserId?: string;
    raw: JsonRecord;
  }
): Promise<void> {
  const id = input.responseId
    ? `${input.classSessionId}:${input.studentId}:${input.quizId}:${input.responseId}`
    : crypto.randomUUID();
  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO final_exam_results (
      id, student_id, class_session_id, quiz_id, quiz_name, response_id,
      flexiquiz_user_id, email, score_text, result_text, passed, percentage_score,
      points, available_points, report_url, completed_at, raw_json, created_at, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?18)
    ON CONFLICT(student_id, class_session_id, quiz_id, response_id) DO UPDATE SET
      quiz_name = COALESCE(excluded.quiz_name, final_exam_results.quiz_name),
      flexiquiz_user_id = COALESCE(excluded.flexiquiz_user_id, final_exam_results.flexiquiz_user_id),
      email = COALESCE(excluded.email, final_exam_results.email),
      score_text = COALESCE(excluded.score_text, final_exam_results.score_text),
      result_text = COALESCE(excluded.result_text, final_exam_results.result_text),
      passed = COALESCE(excluded.passed, final_exam_results.passed),
      percentage_score = COALESCE(excluded.percentage_score, final_exam_results.percentage_score),
      points = COALESCE(excluded.points, final_exam_results.points),
      available_points = COALESCE(excluded.available_points, final_exam_results.available_points),
      report_url = COALESCE(excluded.report_url, final_exam_results.report_url),
      completed_at = COALESCE(excluded.completed_at, final_exam_results.completed_at),
      raw_json = excluded.raw_json,
      updated_at = excluded.updated_at`
  ).bind(
    id,
    input.studentId,
    input.classSessionId,
    input.quizId,
    input.quizName ?? null,
    input.responseId ?? null,
    input.flexiquizUserId ?? null,
    input.email ?? null,
    input.scoreText ?? null,
    input.resultText ?? null,
    input.passed === undefined ? null : boolInt(input.passed),
    input.percentageScore ?? null,
    input.points ?? null,
    input.availablePoints ?? null,
    input.reportUrl ?? null,
    input.completedAt ?? now,
    JSON.stringify(input.raw),
    now
  ).run();

  await notifyInstructorDashboard(env, {
    classSessionId: input.classSessionId,
    studentId: input.studentId,
    event: "final_exam_result",
    title: "Final exam result ready",
    body: `${await studentDisplayName(env, input.studentId)} final exam: ${input.scoreText ?? input.resultText ?? "result received"}.`,
    quizId: input.quizId,
    responseId: input.responseId,
    scoreText: input.scoreText,
    resultText: input.resultText,
    completedAt: input.completedAt ?? now
  });
}

async function quizMetadata(url: URL, env: Env): Promise<Response> {
  const quizId = decodeURIComponent(url.pathname.split("/").pop() ?? "");
  const expectedName = url.searchParams.get("expectedName")?.trim();

  if (!quizId) {
    return json({ error: "missing_quiz_id" }, 400);
  }

  if (!env.FLEXIQUIZ_API_KEY) {
    return json({ error: "flexiquiz_not_configured" }, 503);
  }

  const response = await flexiGet(env, `/v1/quizzes/${encodeURIComponent(quizId)}`);
  const text = await response.text().catch(() => "");
  const metadata = text ? parseJsonRecord(text) ?? {} : {};
  const name = firstText([metadata], ["name", "quiz_name", "title"]);
  const status = firstText([metadata], ["status", "quiz_status"]);
  const expectedNameMatches = expectedName && name
    ? name.trim().toLowerCase() === expectedName.trim().toLowerCase()
    : undefined;

  if (!response.ok) {
    return json({
      error: "flexiquiz_quiz_lookup_failed",
      quizId,
      statusCode: response.status,
      name,
      status
    }, 502);
  }

  return json({
    ok: true,
    quizId,
    name,
    status,
    expectedName,
    expectedNameMatches
  });
}

async function saveQuizAttempt(
  env: Env,
  input: {
    studentId: string;
    classSessionId: string;
    flexiquizUserId?: string;
    review: QuizReviewPayload;
    questionStart?: number;
    questionEnd?: number;
  }
): Promise<void> {
  const now = new Date().toISOString();
  const section = sectionAttemptSummary(input.review, input.questionStart, input.questionEnd);
  if (section && section.answered === 0) {
    return;
  }
  const quizId = section?.quizId ?? input.review.quizId;
  const attemptId = section
    ? `${input.review.responseId ?? input.review.quizId}:section:${input.questionStart}-${input.questionEnd}`
    : input.review.responseId ?? crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO quiz_attempts (
      id, student_id, class_session_id, flexiquiz_user_id, quiz_id, response_id,
      result_text, score_text, passed, review_url, review_released, completed_at,
      created_at, updated_at
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 1, ?11, ?12, ?12)
    ON CONFLICT(id) DO UPDATE SET
      flexiquiz_user_id = excluded.flexiquiz_user_id,
      quiz_id = excluded.quiz_id,
      response_id = excluded.response_id,
      result_text = excluded.result_text,
      score_text = excluded.score_text,
      passed = excluded.passed,
      review_url = excluded.review_url,
      review_released = 1,
      completed_at = excluded.completed_at,
      updated_at = excluded.updated_at`
  ).bind(
    attemptId,
    input.studentId,
    input.classSessionId,
    input.flexiquizUserId ?? null,
    quizId,
    input.review.responseId ?? null,
    section?.resultText ?? input.review.resultText ?? null,
    section?.scoreText ?? input.review.scoreText ?? null,
    section ? null : input.review.passed === undefined ? null : boolInt(input.review.passed),
    input.review.reportUrl ?? null,
    section ? now : input.review.completedAt ?? now,
    now
  ).run();

  await notifyInstructorDashboard(env, {
    classSessionId: input.classSessionId,
    studentId: input.studentId,
    event: section ? "quiz_section_result" : "quiz_attempt",
    title: "Quiz result ready",
    body: `${await studentDisplayName(env, input.studentId)} ${section?.quizId ?? quizId}: ${section?.scoreText ?? input.review.scoreText ?? "submitted"}.`,
    quizId,
    responseId: input.review.responseId,
    scoreText: section?.scoreText ?? input.review.scoreText,
    resultText: section?.resultText ?? input.review.resultText,
    completedAt: section ? now : input.review.completedAt ?? now
  });
}

function sectionAttemptSummary(
  review: QuizReviewPayload,
  questionStart?: number,
  questionEnd?: number
): { quizId: string; scoreText: string; resultText: string; answered: number } | undefined {
  if (questionStart === undefined || questionEnd === undefined) {
    return undefined;
  }

  const sectionQuestions = review.questions.filter((question) =>
    question.number >= questionStart && question.number <= questionEnd
  );
  const answered = sectionQuestions.filter((question) =>
    (question.studentAnswer ?? "").trim().length > 0 ||
    question.isCorrect === true ||
    question.isCorrect === false
  );
  const correct = answered.filter((question) => question.isCorrect === true).length;
  return {
    quizId: sectionQuizId(review.quizId, questionStart, questionEnd),
    scoreText: `${correct}/${answered.length}`,
    resultText: "section_submitted",
    answered: answered.length
  };
}

function sectionQuizId(quizId: string, questionStart: number, questionEnd: number): string {
  if (quizId === REFRESHER_A_COMBINED_QUIZ_ID) {
    if (questionStart === 1 && questionEnd === 12) return "refresher-a-page-1";
    if (questionStart === 13 && questionEnd === 25) return "refresher-a-page-2";
    if (questionStart === 26 && questionEnd === 38) return "refresher-a-page-3";
    if (questionStart === 39 && questionEnd === 50) return "refresher-a-page-4";
  }
  if (quizId === REFRESHER_B_COMBINED_QUIZ_ID) {
    if (questionStart === 1 && questionEnd === 12) return "refresher-b-page-1";
    if (questionStart === 13 && questionEnd === 25) return "refresher-b-page-2";
    if (questionStart === 26 && questionEnd === 37) return "refresher-b-page-3";
    if (questionStart === 38 && questionEnd === 50) return "refresher-b-page-4";
  }
  if (quizId === REFRESHER_C_COMBINED_QUIZ_ID) {
    if (questionStart === 1 && questionEnd === 13) return "refresher-c-page-1";
    if (questionStart === 14 && questionEnd === 25) return "refresher-c-page-2";
    if (questionStart === 26 && questionEnd === 38) return "refresher-c-page-3";
    if (questionStart === 39 && questionEnd === 50) return "refresher-c-page-4";
  }
  return `${quizId}:section:${questionStart}-${questionEnd}`;
}

async function fetchRmsQuizReview(
  env: Env,
  input: {
    responseId?: string;
    quizId: string;
    email?: string;
    flexiquizUserId?: string;
    debug?: boolean;
  }
): Promise<JsonRecord | undefined> {
  if (!env.ACADEMY_RMS_BASE_URL || !env.ACADEMY_RMS_ATTENDANCE_SECRET) {
    return input.debug ? { __rmsLookupWarning: "rms_review_not_configured" } : undefined;
  }
  const params = new URLSearchParams();
  if (input.responseId) params.set("response_id", input.responseId);
  if (input.quizId) params.set("quiz_id", input.quizId);
  if (input.email) params.set("email", input.email);
  if (input.flexiquizUserId) params.set("user_id", input.flexiquizUserId);

  if ([...params.keys()].length === 0) {
    return undefined;
  }

  const endpoint = `${joinUrl(env.ACADEMY_RMS_BASE_URL, "/api/classmanager/flexiquiz-review")}?${params.toString()}`;
  const res = await fetch(endpoint, {
    headers: {
      "accept": "application/json",
      "x-classmanager-secret": env.ACADEMY_RMS_ATTENDANCE_SECRET
    }
  });
  const text = await res.text();
  if (res.status === 404) {
    return { __rmsLookupWarning: "rms_review_not_ready" };
  }
  if (!res.ok) {
    console.warn("RMS quiz review lookup failed", { status: res.status, body: text.slice(0, 500) });
    return { __rmsLookupWarning: `rms_review_status_${res.status}` };
  }
  let payload: unknown;
  try {
    payload = JSON.parse(text) as unknown;
  } catch (error) {
    console.warn("RMS quiz review returned non-JSON response", { body: text.slice(0, 500), error });
    const contentType = res.headers.get("content-type") ?? "unknown";
    const bodyPrefix = cleanText(text.slice(0, 80)).replace(/[^a-zA-Z0-9._:/ -]/g, "").slice(0, 60).replace(/\s+/g, "-");
    return input.debug ? { __rmsLookupWarning: `rms_review_non_json_${res.status}_${contentType}_${bodyPrefix}` } : undefined;
  }
  return isJsonRecord(payload) ? payload : undefined;
}

function mergeRmsQuizReview(review: QuizReviewPayload, rmsPayload: JsonRecord): QuizReviewPayload {
  const result = recordField(rmsPayload, "result");
  const questionRows = Array.isArray(rmsPayload.question_rows)
    ? rmsPayload.question_rows.filter(isJsonRecord)
    : [];
  const rmsQuestions = questionRows.map((row, index) => rmsQuestionToReviewQuestion(row, index));
  const warnings = rmsQuestions.length > 0
    ? review.warnings.filter((warning) => warning !== "question_detail_unavailable")
    : review.warnings;
  const scoreText = scoreTextFromSources([result].filter(isJsonRecord));
  const resultText = firstText([result], ["grade", "result", "result_text", "response_status", "status"]);
  const passed = boolFromUnknown(firstValue([result].filter(isJsonRecord), ["passed", "pass"])) ??
    passStatusFromText(resultText ?? scoreText) ??
    review.passed;

  return {
    ...review,
    responseId: firstText([result], ["response_id", "responseId"]) ?? review.responseId,
    resultText: resultText ?? review.resultText,
    scoreText: scoreText ?? review.scoreText,
    passed,
    completedAt: firstText([result], ["submitted_at", "submittedAt", "completed_at", "completedAt"]) ?? review.completedAt,
    reportUrl: firstText([result], ["response_report_url", "responseReportUrl"]) ?? review.reportUrl,
    questions: rmsQuestions.length > 0 ? rmsQuestions : review.questions,
    warnings
  };
}

function rmsQuestionToReviewQuestion(row: JsonRecord, index: number): QuizReviewQuestion {
  const correctness = firstText([row], ["correctness", "result", "status"]);
  return {
    id: firstText([row], ["id", "question_id", "questionId"]) ?? String(index + 1),
    number: Number(firstNumber([row], ["number", "question_number", "questionNumber"]) ?? index + 1),
    prompt: firstText([row], ["question", "prompt", "text", "title"]) ?? `Question ${index + 1}`,
    choices: choicesFromRmsQuestion(row),
    studentAnswer: firstText([row], ["answer", "student_answer", "studentAnswer", "selected_answer", "selectedAnswer"]),
    correctAnswer: firstText([row], ["correct_answer", "correctAnswer", "expected_answer", "expectedAnswer"]),
    isCorrect: boolFromUnknown(firstValue([row], ["is_correct", "isCorrect", "correct"])) ?? /^correct\b/i.test(correctness ?? ""),
    feedback: firstText([row], ["feedback", "comment", "comments", "explanation", "rationale"]),
    points: firstText([row], ["points", "score", "marks"])
  };
}

function choicesFromRmsQuestion(row: JsonRecord): string[] | undefined {
  const direct = row.choices ?? row.options ?? row.possible_answers ?? row.possibleAnswers;
  if (!Array.isArray(direct)) {
    return undefined;
  }
  const choices = direct.map((value) => {
    if (isJsonRecord(value)) {
      return firstText([value], ["text", "label", "answer", "value", "option"]);
    }
    return textFromUnknown(value);
  }).filter((value): value is string => Boolean(value));
  return choices.length > 0 ? choices : undefined;
}

async function cachedQuizReview(env: Env, attemptId: string): Promise<QuizReviewPayload | undefined> {
  const row = await env.DB.prepare(
    `SELECT id, quiz_id, response_id, result_text, score_text, passed, review_url, review_released, completed_at
     FROM quiz_attempts WHERE id = ?1 OR response_id = ?1`
  ).bind(attemptId).first<JsonRecord>();

  if (!row || row.review_released !== 1) {
    return undefined;
  }

  return {
    ok: true,
    quizId: stringField(row, "quiz_id") ?? attemptId,
    responseId: stringField(row, "response_id") ?? stringField(row, "id"),
    resultText: stringField(row, "result_text"),
    scoreText: stringField(row, "score_text"),
    passed: boolFromUnknown(row.passed),
    completedAt: stringField(row, "completed_at"),
    reportUrl: stringField(row, "review_url"),
    questions: [],
    warnings: ["cached_attempt_has_no_question_detail"]
  };
}

async function flexiListResponses(env: Env, userId: string, quizId: string): Promise<JsonRecord[]> {
  const response = await flexiPost(env, `/v1/users/${encodeURIComponent(userId)}/responses`, {
    quiz_id: quizId,
    limit: "10",
    order: "desc"
  });

  if (response.ok) {
    const payload = await response.json<unknown>().catch(() => undefined);
    const records = recordsFromPayload(payload);
    if (records.length > 0) {
      return records;
    }
  }

  const profile = await flexiGetUserProfile(env, userId);
  const profileResponses = (profile?.quizzes ?? []).filter((record) =>
    stringField(record, "quiz_id") === quizId ||
    stringField(record, "quizId") === quizId
  );
  if (profileResponses.length > 0) {
    return profileResponses;
  }

  throw new HttpError(502, "flexiquiz_responses_failed");
}

async function flexiResponseQuestions(
  env: Env,
  quizId: string,
  responseId: string
): Promise<JsonRecord[]> {
  const response = await flexiGet(
    env,
    `/v1/quizzes/${encodeURIComponent(quizId)}/responses/${encodeURIComponent(responseId)}/questions`
  );
  if (!response.ok) {
    return [];
  }
  const payload = await response.json<unknown>().catch(() => undefined);
  return recordsFromPayload(payload);
}

async function flexiResponseDetail(
  env: Env,
  userId: string,
  quizId: string,
  responseId: string
): Promise<JsonRecord | undefined> {
  const paths = [
    `/v1/users/${encodeURIComponent(userId)}/responses/${encodeURIComponent(responseId)}`,
    `/v1/quizzes/${encodeURIComponent(quizId)}/responses/${encodeURIComponent(responseId)}`,
    `/v1/responses/${encodeURIComponent(responseId)}`
  ];

  for (const path of paths) {
    const response = await flexiGet(env, path);
    if (!response.ok) {
      continue;
    }
    const payload = await response.json<unknown>().catch(() => undefined);
    const record = recordFromPayload(payload);
    if (record) {
      return record;
    }
  }

  return undefined;
}

async function flexiGet(env: Env, path: string): Promise<Response> {
  const url = new URL(joinUrl(env.FLEXIQUIZ_API_BASE, path));
  return await fetch(url, {
    method: "GET",
    headers: {
      accept: "application/json",
      "x-api-key": env.FLEXIQUIZ_API_KEY ?? ""
    }
  });
}

function normalizeQuizReview(input: {
  quizId: string;
  latest: JsonRecord;
  detail?: JsonRecord;
  questionRecords?: JsonRecord[];
  reportHtml?: string;
  fallbackResponseId?: string;
  fallbackReportUrl?: string;
  warnings: string[];
}): QuizReviewPayload {
  const sources = [input.detail, recordField(input.detail, "content"), recordField(input.detail, "response"), input.latest, recordField(input.latest, "content")]
    .filter(isJsonRecord);
  const directQuestionRecords = input.questionRecords ?? [];
  const questions = normalizeQuestionRecords(directQuestionRecords.length > 0 ? directQuestionRecords : questionRecordsFromSources(sources));
  const htmlQuestions = questions.length > 0 ? [] : parseQuestionsFromReportHtml(input.reportHtml);

  if (questions.length === 0 && htmlQuestions.length === 0) {
    input.warnings.push("question_detail_unavailable");
  }

  const resultText = firstText(sources, ["result_text", "resultText", "result", "grade", "pass_fail", "outcome", "status"]);
  const scoreText = scoreTextFromSources(sources);
  const passingScore = minimumPassingScoreForQuiz(input.quizId, sources);
  const percentageScore = firstNumber(sources, ["percentage_score", "percentageScore", "percentage", "percent"]);
  const passed = (percentageScore !== undefined ? percentageScore >= passingScore : undefined) ??
    boolFromUnknown(firstValue(sources, ["passed", "pass", "is_passed", "isPassed", "success"])) ??
    passStatusFromText(resultText ?? scoreText) ??
    passStatusFromScore(scoreText, passingScore);

  return {
    ok: true,
    quizId: input.quizId,
    responseId: firstText(sources, ["response_id", "responseId", "id", "response_guid", "responseGuid"]) ?? input.fallbackResponseId,
    resultText,
    scoreText,
    passed,
    completedAt: firstText(sources, ["completed_at", "completedAt", "date_completed", "submitted_at", "submit_date", "finished_at"]),
    reportUrl: input.fallbackReportUrl,
    questions: questions.length > 0 ? questions : htmlQuestions,
    warnings: input.warnings
  };
}

function filterQuizReviewQuestions(
  review: QuizReviewPayload,
  questionStart?: number,
  questionEnd?: number
): QuizReviewPayload {
  if (questionStart === undefined && questionEnd === undefined) {
    return review;
  }
  const lower = questionStart ?? Number.MIN_SAFE_INTEGER;
  const upper = questionEnd ?? Number.MAX_SAFE_INTEGER;
  return {
    ...review,
    questions: review.questions.filter((question) => question.number >= lower && question.number <= upper),
    warnings: [...review.warnings, `question_range_${lower}_${upper}`]
  };
}

function applyQuestionRationales(review: QuizReviewPayload): QuizReviewPayload {
  let mappedCount = 0;
  const questions = review.questions.map((question) => {
    const existing = question.feedback?.trim();
    if (existing) {
      return { ...question, feedback: existing };
    }

    const mapped = mappedRationaleForQuestion(review.quizId, question);
    if (mapped) {
      mappedCount += 1;
      return { ...question, feedback: mapped };
    }

    return question;
  });

  if (mappedCount === 0) {
    return review;
  }

  return {
    ...review,
    questions,
    warnings: [...review.warnings, `rationales_mapped_${mappedCount}`]
  };
}

function mappedRationaleForQuestion(quizId: string, question: QuizReviewQuestion): string | undefined {
  const knownRationale = knownRationaleForQuestion(quizId, question);
  if (knownRationale) {
    return knownRationale;
  }

  return fallbackRationaleForQuestion(question);
}

function knownRationaleForQuestion(quizId: string, question: QuizReviewQuestion): string | undefined {
  const key = questionRationaleKey(question.prompt);
  const rationales = KNOWN_QUESTION_RATIONALES_BY_QUIZ[quizId];
  const quizSpecific = rationales?.[key]?.trim();
  if (quizSpecific) {
    return quizSpecific;
  }

  for (const map of Object.values(KNOWN_QUESTION_RATIONALES_BY_QUIZ)) {
    const mapped = map[key]?.trim();
    if (mapped) {
      return mapped;
    }
  }
  return undefined;
}

function fallbackRationaleForQuestion(question: QuizReviewQuestion): string | undefined {
  const correctAnswer = question.correctAnswer?.trim();
  if (!correctAnswer) {
    return undefined;
  }

  const studentAnswer = question.studentAnswer?.trim();
  if (studentAnswer && question.isCorrect === false) {
    return `The keyed correct answer is "${correctAnswer}". Your selected answer was "${studentAnswer}", so review the question wording and answer choices that point to "${correctAnswer}".`;
  }

  if (question.isCorrect === true) {
    return `The keyed correct answer is "${correctAnswer}". This item was answered correctly; use the question wording and answer choices to reinforce why this option fits best.`;
  }

  return `The keyed correct answer is "${correctAnswer}". Review the question wording and answer choices that point to this option.`;
}

function questionRationaleKey(value: string): string {
  return cleanText(value)
    .toLowerCase()
    .replace(/[“”]/g, "\"")
    .replace(/[‘’]/g, "'")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function scoreTextFromSources(sources: JsonRecord[]): string | undefined {
  const direct = firstText(sources, ["score_text", "scoreText", "score"]);
  if (direct) {
    return direct;
  }
  const percentage = firstNumber(sources, ["percentage_score", "percentageScore", "percentage", "percent"]);
  if (percentage !== undefined) {
    return `${Math.round(percentage)}%`;
  }
  const points = firstNumber(sources, ["points"]);
  const available = firstNumber(sources, ["available_points", "availablePoints"]);
  if (points !== undefined && available !== undefined && available > 0) {
    return `${Math.round((points / available) * 100)}% (${points}/${available})`;
  }
  return firstText(sources, ["grade"]);
}

function responseLooksCompleted(response: JsonRecord): boolean {
  const status = firstText([response], ["status", "state", "result", "result_text"])?.toLowerCase() ?? "";
  if (/(^|[^a-z])(not[_ -]?submitted|unsubmitted|incomplete|in[_ -]?progress|pending|started|open)([^a-z]|$)/.test(status)) {
    return false;
  }
  if (/(complete|completed|submitted|finished|pass|fail)/.test(status)) {
    return true;
  }
  return Boolean(firstText([response], ["completed_at", "completedAt", "date_completed", "submitted_at", "submit_date"]));
}

function reviewLooksCompleted(review: QuizReviewPayload, latest: JsonRecord): boolean {
  if (responseLooksCompleted(latest)) {
    return true;
  }
  return Boolean(review.completedAt);
}

function responseIdFrom(response: JsonRecord): string | undefined {
  return firstText([response], ["response_id", "responseId", "id", "response_guid", "responseGuid"]);
}

function recordsFromPayload(payload: unknown): JsonRecord[] {
  if (Array.isArray(payload)) {
    return payload.filter(isJsonRecord);
  }
  if (!isJsonRecord(payload)) {
    return [];
  }
  const arrays = [
    payload.content,
    payload.responses,
    payload.data,
    payload.items,
    recordField(payload, "content")?.responses,
    recordField(payload, "content")?.items
  ];
  for (const value of arrays) {
    if (Array.isArray(value)) {
      return value.filter(isJsonRecord);
    }
  }
  return [payload];
}

function recordFromPayload(payload: unknown): JsonRecord | undefined {
  if (isJsonRecord(payload)) {
    return recordField(payload, "content") ?? recordField(payload, "data") ?? recordField(payload, "response") ?? payload;
  }
  if (Array.isArray(payload)) {
    return payload.find(isJsonRecord);
  }
  return undefined;
}

function questionRecordsFromSources(sources: JsonRecord[]): JsonRecord[] {
  for (const source of sources) {
    const direct = [
      source.questions,
      source.answers,
      source.question_answers,
      source.questionAnswers,
      source.responses,
      source.items,
      source.results
    ];
    for (const value of direct) {
      if (Array.isArray(value)) {
        const records = value.filter(isJsonRecord);
        if (records.some(looksLikeQuestionRecord)) {
          return records;
        }
      }
    }

    const deep = deepQuestionRecords(source, 0);
    if (deep.length > 0) {
      return deep;
    }
  }
  return [];
}

function deepQuestionRecords(value: unknown, depth: number): JsonRecord[] {
  if (depth > 4) {
    return [];
  }
  if (Array.isArray(value)) {
    const records = value.filter(isJsonRecord);
    if (records.length > 0 && records.some(looksLikeQuestionRecord)) {
      return records;
    }
    for (const item of value) {
      const nested = deepQuestionRecords(item, depth + 1);
      if (nested.length > 0) {
        return nested;
      }
    }
    return [];
  }
  if (!isJsonRecord(value)) {
    return [];
  }
  for (const item of Object.values(value)) {
    const nested = deepQuestionRecords(item, depth + 1);
    if (nested.length > 0) {
      return nested;
    }
  }
  return [];
}

function looksLikeQuestionRecord(record: JsonRecord): boolean {
  return Boolean(firstText([record], ["question", "question_text", "questionText", "prompt", "title", "text", "name"])) &&
    Boolean(firstValue([record], ["answer", "user_answer", "userAnswer", "student_answer", "selected_answer", "correct_answer", "correctAnswer", "is_correct", "isCorrect", "points_scored", "pointsScored", "options"]));
}

function normalizeQuestionRecords(records: JsonRecord[]): QuizReviewQuestion[] {
  return records.map((record, index) => {
    const options = optionRecordsFromUnknown(firstValue([record], ["options", "choices", "answers", "possible_answers", "possibleAnswers"]));
    const prompt = firstText([record], ["question_text", "questionText", "question", "prompt", "title", "text", "name"]) ?? `Question ${index + 1}`;
    const studentAnswer = selectedOptionsText(options) ??
      answerText(firstValue([record], ["user_answer", "userAnswer", "student_answer", "studentAnswer", "selected_answer", "selectedAnswer", "response", "answer"]));
    const correctAnswer = correctOptionsText(options) ??
      answerText(firstValue([record], ["correct_answer", "correctAnswer", "right_answer", "rightAnswer", "expected_answer", "expectedAnswer"]));
    const hasAnswer = Boolean(studentAnswer?.trim());
    const isCorrect = hasAnswer
      ? correctnessFromPoints(record) ??
        correctnessFromOptions(options) ??
        boolFromUnknown(firstValue([record], ["is_correct", "isCorrect", "correct", "was_correct", "wasCorrect", "passed", "result"])) ??
        correctnessFromText(firstText([record], ["result", "status"]))
      : undefined;
    return {
      id: firstText([record], ["id", "question_id", "questionId"]),
      number: intFromUnknown(firstValue([record], ["number", "question_number", "questionNumber", "order", "position"])) ?? index + 1,
      prompt: cleanText(prompt),
      choices: optionChoicesText(options) ?? stringArrayFromUnknown(firstValue([record], ["choices", "options", "possible_answers", "possibleAnswers", "answers"])),
      studentAnswer,
      correctAnswer,
      isCorrect,
      feedback: feedbackFromQuestionRecord(record),
      points: hasAnswer ? pointsTextFromQuestionRecord(record) : undefined
    };
  });
}

function optionRecordsFromUnknown(value: unknown): JsonRecord[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isJsonRecord);
}

function optionChoicesText(options: JsonRecord[]): string[] | undefined {
  const choices = options.map((option) => firstText([option], ["text", "label", "name", "value"])).filter((value): value is string => Boolean(value));
  return choices.length > 0 ? choices : undefined;
}

function selectedOptionsText(options: JsonRecord[]): string | undefined {
  const selected = options
    .filter((option) => boolFromUnknown(option.selected) === true)
    .map((option) => firstText([option], ["answer", "text", "label", "name", "value"]))
    .filter((value): value is string => Boolean(value));
  return selected.length > 0 ? selected.join(", ") : undefined;
}

function correctOptionsText(options: JsonRecord[]): string | undefined {
  const correct = options
    .filter((option) => boolFromUnknown(option.correct) === true)
    .map((option) => firstText([option], ["text", "label", "name", "value"]))
    .filter((value): value is string => Boolean(value));
  return correct.length > 0 ? correct.join(", ") : undefined;
}

function correctnessFromOptions(options: JsonRecord[]): boolean | undefined {
  if (options.length === 0) {
    return undefined;
  }
  const selected = options.filter((option) => boolFromUnknown(option.selected) === true);
  if (selected.length === 0) {
    return undefined;
  }
  return selected.every((option) => boolFromUnknown(option.correct) === true);
}

function correctnessFromPoints(record: JsonRecord): boolean | undefined {
  const scored = firstNumber([record], ["points_scored", "pointsScored"]);
  const available = firstNumber([record], ["points_available", "pointsAvailable"]);
  if (scored === undefined || available === undefined || available <= 0) {
    return undefined;
  }
  return scored >= available;
}

function pointsTextFromQuestionRecord(record: JsonRecord): string | undefined {
  const scored = firstNumber([record], ["points_scored", "pointsScored"]);
  const available = firstNumber([record], ["points_available", "pointsAvailable"]);
  if (scored !== undefined && available !== undefined) {
    return `${scored}/${available}`;
  }
  return firstText([record], ["points", "score", "mark", "marks"]);
}

function feedbackFromQuestionRecord(record: JsonRecord): string | undefined {
  return firstText([record], ["feedback", "feedback_text", "feedbackText", "comment", "comments", "explanation", "rationale"])?.trim();
}

function parseQuestionsFromReportHtml(html?: string): QuizReviewQuestion[] {
  if (!html) {
    return [];
  }
  const plain = cleanText(stripTags(html));
  if (!plain.toLowerCase().includes("question")) {
    return [];
  }
  const chunks = plain.split(/\bQuestion\s+\d+[:.)-]?\s*/i).slice(1);
  return chunks.slice(0, 100).map((chunk, index) => {
    const isCorrect = correctnessFromText(chunk);
    const feedback = regexValue(chunk, /Feedback\s*[:\-]\s*([^]+?)(?=\s*(?:Question\s+\d+|Correct Answer|Your Answer|$))/i);
    return {
      number: index + 1,
      prompt: cleanText(chunk.split(/Your Answer|Correct Answer|Feedback/i)[0] ?? `Question ${index + 1}`),
      studentAnswer: regexValue(chunk, /Your Answer\s*[:\-]\s*([^]+?)(?=\s*(?:Correct Answer|Feedback|Question\s+\d+|$))/i),
      correctAnswer: regexValue(chunk, /Correct Answer\s*[:\-]\s*([^]+?)(?=\s*(?:Feedback|Question\s+\d+|$))/i),
      isCorrect,
      feedback
    };
  }).filter((question) => question.prompt.length > 0);
}

async function fetchTextLimited(url: string, limit: number): Promise<string | undefined> {
  const response = await fetch(url, { headers: { accept: "text/html, text/plain;q=0.9" } });
  if (!response.ok || !response.body) {
    return undefined;
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let received = 0;
  let text = "";

  while (received < limit) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    received += value.byteLength;
    text += decoder.decode(value, { stream: true });
  }
  text += decoder.decode();
  await reader.cancel().catch(() => undefined);
  return text;
}

async function sendEmailEndpoint(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const to = stringField(body, "to");
  const subject = stringField(body, "subject");
  const messagePlainText = stringField(body, "messagePlainText");
  const messageHTML = stringField(body, "messageHTML");
  const attachmentGuid = stringField(body, "attachmentGuid");

  if (!to || !subject || !messagePlainText) {
    return json({ error: "missing_email_fields" }, 400);
  }

  const result = await sendSmarterMail(env, {
    to,
    subject,
    messagePlainText,
    messageHTML,
    attachmentGuid
  });

  return json(result);
}

async function aiCommentsEndpoint(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const studentName = stringField(body, "studentName") ?? "The student";
  const courseTitle = stringField(body, "courseTitle") ?? "the course";
  const context = stringField(body, "context") ?? "course completion";
  const studentId = stringField(body, "studentId");
  const classSessionId = stringField(body, "classSessionId");

  const analytics = studentId && classSessionId
    ? await buildStudentCommentAnalytics(env, studentId, classSessionId)
    : emptyCommentAnalytics();

  const fallback = studentCommentFallback(studentName, courseTitle, analytics);
  if (!env.AI) {
    return json({
      success: true,
      comment: fallback,
      usedFallback: true,
      reason: "workers_ai_not_configured",
      analytics
    });
  }

  try {
    const response = await env.AI.run("@cf/meta/llama-3.1-8b-instruct-fp8", {
      messages: [
        {
          role: "system",
          content: [
            "You write concise EMS academy instructor comments for skills validation and course completion records.",
            "Write one polished paragraph, 55 to 85 words.",
            "Return only the paragraph text. Do not introduce it or explain it.",
            "Use the student's first name naturally and avoid gendered pronouns unless provided.",
            "Be specific, positive, and professional.",
            "If analytics include growth topics, frame them as continued review or reinforcement, not failure.",
            "Do not invent exam scores, certifications, attendance, or clinical facts not provided.",
            "Do not mention AI, analytics, payloads, quizzes, or raw data."
          ].join(" ")
        },
        {
          role: "user",
          content: JSON.stringify({
            studentName,
            courseTitle,
            context,
            analytics,
            fallbackToneExamples: [
              `${studentName} demonstrated steady engagement throughout ${courseTitle}, contributed appropriately during class activities, and showed a professional approach to continued EMS development.`,
              `${studentName} completed ${courseTitle} with a positive attitude and consistent participation. Continued review of targeted course topics will help reinforce the material covered today.`
            ]
          })
        }
      ],
      max_tokens: 180,
      temperature: 0.55
    });

    const comment = cleanGeneratedComment(textFromUnknown(response.response));
    if (comment && comment.includes(studentName.split(/\s+/)[0] ?? studentName) && comment.length >= 50) {
      return json({
        success: true,
        comment,
        usedFallback: false,
        analytics
      });
    }

    return json({
      success: true,
      comment: fallback,
      usedFallback: true,
      reason: "ai_response_failed_validation",
      analytics
    });
  } catch (error) {
    console.warn("aicomments failed", error);
    return json({
      success: true,
      comment: fallback,
      usedFallback: true,
      reason: "ai_generation_failed",
      analytics
    });
  }
}

async function buildStudentCommentAnalytics(
  env: Env,
  studentId: string,
  classSessionId: string
): Promise<StudentCommentAnalytics> {
  const attemptsResult = await env.DB.prepare(
    `SELECT quiz_id, result_text, score_text, passed, completed_at, updated_at
     FROM quiz_attempts
     WHERE student_id = ?1 AND class_session_id = ?2
     ORDER BY COALESCE(completed_at, updated_at) ASC`
  ).bind(studentId, classSessionId).all<JsonRecord>();

  const attempts = attemptsResult.results ?? [];
  const scores = attempts.map((attempt) => numericScore(stringField(attempt, "score_text"))).filter((score): score is number => score !== undefined);
  const averageScore = scores.length > 0
    ? Math.round((scores.reduce((sum, score) => sum + score, 0) / scores.length) * 10) / 10
    : undefined;
  const passedQuizCount = attempts.filter((attempt) => boolFromUnknown(attempt.passed) === true).length;
  const quizSummaries = attempts.slice(0, 8).map((attempt, index) => {
    const score = stringField(attempt, "score_text");
    const result = quizResultSummary(attempt);
    return `Quiz ${index + 1}: ${[result, score && !result.includes(score) ? score : undefined].filter(Boolean).join(" ")}`;
  });

  const reviewEvents = await env.DB.prepare(
    `SELECT payload_json
     FROM audit_events
     WHERE student_id = ?1
       AND class_session_id = ?2
       AND event_type = 'quiz.review.requested'
     ORDER BY created_at DESC
     LIMIT 25`
  ).bind(studentId, classSessionId).all<JsonRecord>();

  const strengths = new Map<string, number>();
  const growth = new Map<string, number>();
  for (const row of reviewEvents.results ?? []) {
    const payload = parseJsonRecord(stringField(row, "payload_json") ?? "");
    const questions = Array.isArray(payload?.questions) ? payload.questions.filter(isJsonRecord) : [];
    for (const question of questions) {
      const topic = topicFromQuestion(question);
      if (!topic) {
        continue;
      }
      const correct = boolFromUnknown(question.isCorrect);
      if (correct === true) {
        strengths.set(topic, (strengths.get(topic) ?? 0) + 1);
      } else if (correct === false) {
        growth.set(topic, (growth.get(topic) ?? 0) + 1);
      }
    }
  }

  return {
    averageScore,
    completedQuizCount: attempts.length,
    passedQuizCount,
    strongestTopics: topMapKeys(strengths, 3),
    growthTopics: topMapKeys(growth, 3),
    quizSummaries
  };
}

function emptyCommentAnalytics(): StudentCommentAnalytics {
  return {
    completedQuizCount: 0,
    passedQuizCount: 0,
    strongestTopics: [],
    growthTopics: [],
    quizSummaries: []
  };
}

function studentCommentFallback(studentName: string, courseTitle: string, analytics: StudentCommentAnalytics): string {
  const firstName = studentName.split(/\s+/)[0] || studentName;
  if (analytics.strongestTopics.length > 0 || analytics.growthTopics.length > 0) {
    const strength = analytics.strongestTopics[0] ?? "core EMS concepts";
    const growth = analytics.growthTopics[0] ?? "continued review of course material";
    return `${firstName} completed ${courseTitle} with engaged participation and a professional approach to the training day. Their exam review showed solid performance in ${strength}, and continued reinforcement of ${growth} will help strengthen retention moving forward. ${firstName} remained attentive, receptive to feedback, and focused on improving throughout the course.`;
  }
  if (analytics.averageScore !== undefined && analytics.completedQuizCount > 0) {
    const performance = analytics.averageScore >= 85 ? "strong" : analytics.averageScore >= 70 ? "satisfactory" : "developing";
    return `${firstName} completed ${courseTitle} with ${performance} progress across the day's assessments and consistent participation in class activities. They remained professional, attentive, and receptive to feedback throughout the session. Continued review of the course objectives will help reinforce the material and support confident application in the field.`;
  }
  return `${firstName} completed ${courseTitle} with consistent participation, a positive attitude, and a professional approach to the learning environment. They remained engaged with the course material and receptive to instructor feedback throughout the session. Continued review of the day's key objectives will help reinforce understanding and support future EMS practice.`;
}

function cleanGeneratedComment(value?: string): string | undefined {
  if (!value) {
    return undefined;
  }
  return value
    .replace(/^["'\s]+|["'\s]+$/g, "")
    .replace(/^here(?:'s| is)\s+(?:a|the)?\s*(?:polished\s+)?(?:paragraph|comment)[^:]*:\s*/i, "")
    .replace(/^comment:\s*/i, "")
    .trim();
}

function numericScore(value?: string): number | undefined {
  if (!value) {
    return undefined;
  }
  const match = value.match(/(\d+(?:\.\d+)?)/);
  if (!match) {
    return undefined;
  }
  const score = Number.parseFloat(match[1]);
  return Number.isFinite(score) ? score : undefined;
}

function topicFromQuestion(question: JsonRecord): string | undefined {
  const source = [
    firstText([question], ["topic", "category", "objective", "tag"]),
    firstText([question], ["prompt", "question", "questionText", "question_text"]),
    firstText([question], ["feedback", "feedbackText", "feedback_text"])
  ].filter(Boolean).join(" ");
  const normalized = source.toLowerCase();
  const topicPatterns: Array<[string, RegExp]> = [
    ["airway management", /\bairway|ventilat|oxygen|breath|respirat|bag.?valve|bvm\b/],
    ["cardiology", /\bcardiac|heart|chest pain|ecg|ekg|stroke|shock|aed\b/],
    ["trauma assessment", /\btrauma|bleed|hemorrhage|fracture|spinal|burn|head injury\b/],
    ["medical assessment", /\bdiabetes|seizure|allerg|overdose|poison|medical assessment|altered mental\b/],
    ["communication skills", /\bcommunicat|handoff|report|radio|documentation|consent|scene size.?up\b/],
    ["operations and safety", /\bsafety|hazmat|incident command|triage|lifting|ppe|scene\b/],
    ["pediatric care", /\bpediatric|child|infant|newborn|pepp\b/],
    ["obstetrics", /\bobstetric|pregnan|delivery|newborn\b/]
  ];
  return topicPatterns.find(([, pattern]) => pattern.test(normalized))?.[0];
}

function topMapKeys(map: Map<string, number>, count: number): string[] {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, count)
    .map(([key]) => key);
}

async function buildFlexiQuizSsoUrl(env: Env, userId: string, quizId: string): Promise<string> {
  const jwt = await signHs256(
    { alg: "HS256", typ: "JWT" },
    {
      user_id: userId,
      exp: Math.floor(Date.now() / 1000) + 5 * 60
    },
    env.FLEXIQUIZ_SSO_SHARED_SECRET ?? ""
  );
  const url = new URL(env.FLEXIQUIZ_AUTH_URL);
  url.searchParams.set("cla", "t");
  url.searchParams.set("jwt", jwt);
  url.searchParams.set("quiz_id", quizId);
  return url.toString();
}

async function signHs256(header: JsonRecord, payload: JsonRecord, secret: string): Promise<string> {
  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signingInput));
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

async function sendSmarterMail(
  env: Env,
  message: {
    to: string;
    subject: string;
    messagePlainText: string;
    messageHTML?: string;
    attachmentGuid?: string;
  }
): Promise<JsonRecord> {
  const missing = [
    ["SM_USERNAME", env.SM_USERNAME],
    ["SM_PASSWORD", env.SM_PASSWORD],
    ["FROM_ADDRESS", env.FROM_ADDRESS],
    ["REPLY_TO_ADDRESS", env.REPLY_TO_ADDRESS]
  ].filter(([, value]) => !value).map(([name]) => name);

  if (missing.length > 0) {
    return { ok: false, error: "smartermail_not_configured", missing };
  }

  const authResponse = await fetch(joinUrl(env.SM_BASE_URL, env.SM_AUTH), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      username: env.SM_USERNAME,
      password: env.SM_PASSWORD
    })
  });

  if (!authResponse.ok) {
    return { ok: false, error: "smartermail_auth_failed", status: authResponse.status };
  }

  const authJson = await authResponse.json<JsonRecord>().catch(() => ({}));
  const token = stringField(authJson, "accessToken") ??
    stringField(authJson, "token") ??
    stringField(authJson, "jwt");

  const payload: JsonRecord = {
    from: env.FROM_ADDRESS,
    replyTo: env.REPLY_TO_ADDRESS,
    to: message.to,
    subject: message.subject,
    messagePlainText: message.messagePlainText,
    messageHTML: message.messageHTML ?? message.messagePlainText
  };

  if (message.attachmentGuid) {
    payload.attachmentGuid = message.attachmentGuid;
  }

  const sendResponse = await fetch(joinUrl(env.SM_BASE_URL, env.SM_SEND_EMAIL), {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {})
    },
    body: JSON.stringify(payload)
  });

  return { ok: sendResponse.ok, status: sendResponse.status };
}

async function audit(
  env: Env,
  eventType: string,
  fields: {
    studentId?: string | null;
    classSessionId?: string | null;
    actorId?: string | null;
    deviceId?: string | null;
    payload?: JsonRecord;
  } = {}
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO audit_events (
      id, event_type, student_id, class_session_id, actor_id, device_id, payload_json
    ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`
  ).bind(
    crypto.randomUUID(),
    eventType,
    fields.studentId ?? null,
    fields.classSessionId ?? null,
    fields.actorId ?? null,
    fields.deviceId ?? null,
    JSON.stringify(fields.payload ?? {})
  ).run();
}

class HttpError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
  }
}

function progressPath(url: URL): { classSessionId?: string; studentId?: string } {
  const parts = url.pathname.split("/").filter(Boolean);
  return {
    classSessionId: parts[1] ? decodeURIComponent(parts[1]) : undefined,
    studentId: parts[2] ? decodeURIComponent(parts[2]) : undefined
  };
}

async function readJson(request: Request): Promise<JsonRecord> {
  return await request.json<JsonRecord>().catch(() => ({}));
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders
  });
}

function corsHeaders(request: Request): HeadersInit {
  const origin = request.headers.get("origin") ?? "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,POST,PATCH,OPTIONS",
    "access-control-allow-headers": "content-type,authorization",
    "access-control-max-age": "86400"
  };
}

function boolInt(value: unknown): number {
  return value === true || value === 1 ? 1 : 0;
}

function sessionIdFor(value: string): string {
  const clean = value.trim();
  return clean ? clean.replace(/\//g, "-") : "undated";
}

function stringField(source: JsonRecord, key: string): string | undefined {
  const value = source[key];
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;
}

function numberField(source: JsonRecord, key: string): number | undefined {
  const value = source[key];
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function recordField(source: JsonRecord | undefined, key: string): JsonRecord | undefined {
  if (!source) {
    return undefined;
  }
  const value = source[key];
  return isJsonRecord(value) ? value : undefined;
}

function arrayField(source: JsonRecord, key: string): unknown[] {
  const value = source[key];
  return Array.isArray(value) ? value : [];
}

function isJsonRecord(value: unknown): value is JsonRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseJsonRecord(value: string): JsonRecord | undefined {
  try {
    const parsed: unknown = JSON.parse(value);
    return isJsonRecord(parsed) ? parsed : undefined;
  } catch {
    return undefined;
  }
}

function answer(answers: JsonRecord, qid: string): JsonRecord | undefined {
  return recordField(answers, qid);
}

function answerObject(answers: JsonRecord, qid: string): JsonRecord {
  return recordField(answer(answers, qid), "answer") ?? {};
}

function answerString(answers: JsonRecord, qid: string): string {
  const field = answer(answers, qid);
  if (!field) {
    return "";
  }

  const raw = field.answer;
  if (typeof raw === "string") {
    return raw.trim();
  }
  if (Array.isArray(raw)) {
    return raw.map(String).join(", ").trim();
  }
  if (isJsonRecord(raw)) {
    return firstNonEmpty(
      stringField(raw, "full"),
      stringField(raw, "datetime"),
      stringField(raw, "date"),
      [stringField(raw, "first"), stringField(raw, "last")].filter(Boolean).join(" ")
    );
  }

  return stringField(field, "text") ?? "";
}

function firstNonEmpty(...values: Array<string | undefined>): string {
  return values.find((value) => value !== undefined && value.trim().length > 0)?.trim() ?? "";
}

function firstValue(sources: JsonRecord[], keys: string[]): unknown {
  for (const source of sources) {
    for (const key of keys) {
      if (source[key] !== undefined && source[key] !== null && source[key] !== "") {
        return source[key];
      }
    }
  }
  return undefined;
}

function firstText(sources: Array<JsonRecord | undefined>, keys: string[]): string | undefined {
  return textFromUnknown(firstValue(sources.filter(isJsonRecord), keys));
}

function firstNumber(sources: Array<JsonRecord | undefined>, keys: string[]): number | undefined {
  for (const source of sources.filter(isJsonRecord)) {
    for (const key of keys) {
      const value = numberField(source, key);
      if (value !== undefined) {
        return value;
      }
    }
  }
  return undefined;
}

function textFromUnknown(value: unknown): string | undefined {
  if (typeof value === "string") {
    const clean = cleanText(value);
    return clean.length > 0 ? clean : undefined;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (Array.isArray(value)) {
    const joined = value.map(textFromUnknown).filter(Boolean).join(", ");
    return joined || undefined;
  }
  if (isJsonRecord(value)) {
    return firstText([value], ["text", "label", "name", "value", "answer", "title", "full"]);
  }
  return undefined;
}

function answerText(value: unknown): string | undefined {
  if (isJsonRecord(value)) {
    const direct = firstText([value], ["text", "label", "name", "value", "answer", "title", "full"]);
    if (direct) {
      return direct;
    }
    const joined = Object.values(value).map(textFromUnknown).filter(Boolean).join(", ");
    return joined || undefined;
  }
  return textFromUnknown(value);
}

function stringArrayFromUnknown(value: unknown): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined;
  }
  const values = value.map(answerText).filter((item): item is string => Boolean(item && item.trim().length > 0));
  return values.length > 0 ? values : undefined;
}

function boolFromUnknown(value: unknown): boolean | undefined {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value === 1 ? true : value === 0 ? false : undefined;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "yes", "y", "1", "pass", "passed", "correct"].includes(normalized)) {
      return true;
    }
    if (["false", "no", "n", "0", "fail", "failed", "incorrect"].includes(normalized)) {
      return false;
    }
  }
  return undefined;
}

function numberFromUnknown(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function intFromUnknown(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function rmsCallbackAuthorized(request: Request, env: Env): boolean {
  const secret = (env.ACADEMY_RMS_ATTENDANCE_SECRET ?? "").trim();
  if (!secret) {
    return false;
  }
  const supplied = (
    request.headers.get("x-classmanager-secret") ??
    request.headers.get("x-webhook-secret") ??
    request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ??
    ""
  ).trim();
  return timingSafeEqual(supplied, secret);
}

function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const aBytes = encoder.encode(a);
  const bBytes = encoder.encode(b);
  if (aBytes.length !== bBytes.length) {
    return false;
  }
  let diff = 0;
  for (let index = 0; index < aBytes.length; index += 1) {
    diff |= aBytes[index] ^ bBytes[index];
  }
  return diff === 0;
}

function passStatusFromText(text?: string): boolean | undefined {
  if (!text) {
    return undefined;
  }
  const normalized = text.toLowerCase();
  if (/\bpass(?:ed)?\b/.test(normalized)) {
    return true;
  }
  if (/\bfail(?:ed)?\b/.test(normalized)) {
    return false;
  }
  return undefined;
}

function passStatusFromScore(text?: string, minimumPassingScore = 70): boolean | undefined {
  if (!text) {
    return undefined;
  }
  const match = text.match(/(\d+(?:\.\d+)?)\s*%?/);
  if (!match) {
    return undefined;
  }
  const score = Number.parseFloat(match[1]);
  return Number.isFinite(score) ? score >= minimumPassingScore : undefined;
}

function quizResultSummary(attempt: JsonRecord): string {
  const score = stringField(attempt, "score_text");
  const result = stringField(attempt, "result_text");
  const passed = boolFromUnknown(attempt.passed) ?? passStatusFromText(result ?? score) ?? passStatusFromScore(score);
  const status = passed === true ? "Passed" : passed === false ? "Failed" : result;
  return [status, score].filter(Boolean).join(" ").trim() || "Completed";
}

function correctnessFromText(text?: string): boolean | undefined {
  if (!text) {
    return undefined;
  }
  const normalized = text.toLowerCase();
  if (/\bincorrect\b|\bwrong\b/.test(normalized)) {
    return false;
  }
  if (/\bcorrect\b|\bright\b/.test(normalized)) {
    return true;
  }
  return undefined;
}

function cleanText(value: string): string {
  return htmlDecode(value)
    .replace(/\s+/g, " ")
    .trim();
}

function stripTags(value: string): string {
  return value
    .replace(/<script\b[^>]*>[^]*?<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[^]*?<\/style>/gi, " ")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|tr|li|h[1-6])>/gi, "\n")
    .replace(/<[^>]+>/g, " ");
}

function htmlDecode(value: string): string {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'");
}

function parseDescriptionFields(description: string): { date?: string; time?: string; courseId?: string; ceuValue?: string } {
  const date = regexValue(description, /Date:\s*([^]+?)(?=\s+Time:|\n|$)/i);
  const time = regexValue(description, /Time:\s*([^]+?)(?=\s+Course ID:|\n|$)/i);
  const courseId = regexValue(description, /Course ID:\s*([A-Za-z0-9-]+)/i);
  const ceuValue = regexValue(description, /CEUs?:\s*([\d.]+)/i);
  return {
    date: date ? normalizeDateToMMDDYYYY(date) : undefined,
    time,
    courseId,
    ceuValue
  };
}

function regexValue(source: string, pattern: RegExp): string | undefined {
  const match = source.match(pattern);
  const value = match?.[1]?.trim();
  return value || undefined;
}

function normalizeDateToMMDDYYYY(raw: string): string {
  const value = raw.trim();
  const slash = value.match(/\b(\d{1,2})\/(\d{1,2})\/(\d{4})\b/);
  if (slash) {
    return `${slash[1].padStart(2, "0")}/${slash[2].padStart(2, "0")}/${slash[3]}`;
  }

  const iso = value.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
  if (iso) {
    return `${iso[2]}/${iso[3]}/${iso[1]}`;
  }

  const longDate = value
    .replace(/&/g, ",")
    .replace(/\([^)]*\)/g, "")
    .trim()
    .match(/\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+((?:19|20)\d{2})\b/i);
  if (longDate) {
    const month = monthNumber(longDate[1]);
    return `${month}/${longDate[2].padStart(2, "0")}/${longDate[3]}`;
  }

  return value;
}

function extractDatePart(raw: string): string | undefined {
  const normalized = normalizeDateToMMDDYYYY(raw);
  return normalized || undefined;
}

function monthNumber(month: string): string {
  const months = [
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december"
  ];
  const index = months.indexOf(month.toLowerCase());
  return index >= 0 ? String(index + 1).padStart(2, "0") : "01";
}

function cleanCourseName(value: string): string {
  const trimmed = value.trim();
  const match = trimmed.match(/\s*\([^)]*\)\s*$/);
  if (!match || match.index === undefined) {
    return trimmed;
  }
  const before = trimmed.slice(0, match.index).trim();
  return before || trimmed;
}

function productCategories(product: JsonRecord): string[] | undefined {
  const cid = stringField(product, "cid");
  if (cid) {
    return [cid];
  }

  const raw = product.connectedCategories;
  if (Array.isArray(raw)) {
    return raw.map(String).map((value) => value.trim()).filter(Boolean);
  }
  if (typeof raw === "string") {
    try {
      const parsed: unknown = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed.map(String).map((value) => value.trim()).filter(Boolean);
      }
    } catch {
      return raw
        .replace(/[\[\]'"]/g, "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean);
    }
  }

  return undefined;
}

function firstImage(product: JsonRecord): string | undefined {
  const raw = product.images;
  if (Array.isArray(raw)) {
    return raw.map(String).find((value) => value.trim().length > 0)?.trim();
  }
  if (typeof raw === "string") {
    try {
      const parsed: unknown = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed.map(String).find((value) => value.trim().length > 0)?.trim();
      }
    } catch {
      return raw.trim() || undefined;
    }
  }
  return undefined;
}

function base64UrlJson(value: JsonRecord): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function normalizeApnsEnvironment(value?: string | null): "prod" | "sandbox" {
  return value?.trim().toLowerCase() === "sandbox" ? "sandbox" : "prod";
}

async function apnsJwt(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedApnsJwt && now < cachedApnsJwtExp) {
    return cachedApnsJwt;
  }

  const keyId = (env.APNS_KEY_ID ?? "").trim();
  const teamId = (env.APNS_TEAM_ID ?? "").trim();
  const keyPem = (env.APNS_KEY ?? env.APNS_PRIVATE_KEY ?? "").trim();
  if (!keyId || !teamId || !keyPem) {
    throw new Error("missing_apns_credentials");
  }

  const header = base64Url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = base64Url(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: now })));
  const data = new TextEncoder().encode(`${header}.${claims}`);
  const rawKey = Uint8Array.from(
    atob(
      keyPem
        .replace("-----BEGIN PRIVATE KEY-----", "")
        .replace("-----END PRIVATE KEY-----", "")
        .replace(/\s+/g, "")
    ),
    (char) => char.charCodeAt(0)
  );

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    rawKey.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, cryptoKey, data);
  cachedApnsJwt = `${header}.${claims}.${base64Url(new Uint8Array(signature))}`;
  cachedApnsJwtExp = now + 50 * 60;
  return cachedApnsJwt;
}

async function sendFinalExamApns(
  env: Env,
  input: {
    token: string;
    apnsEnvironment: "prod" | "sandbox";
    studentId: string;
    classSessionId: string;
    result: FinalExamResult;
  }
): Promise<void> {
  const topic = (env.APNS_BUNDLE_ID ?? "").trim();
  if (!topic) {
    throw new Error("missing_apns_topic");
  }

  const passed = input.result.passed;
  const score = input.result.scoreText ?? (
    input.result.percentageScore !== undefined ? `${input.result.percentageScore}%` : undefined
  );
  const title = passed === false ? "Exam review required" : "Exam result ready";
  const body = passed === false
    ? `Final exam score ${score ?? "received"}. Review and retest required.`
    : `Final exam score ${score ?? "received"}.`;
  const host = input.apnsEnvironment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  const jwt = await apnsJwt(env);

  const response = await fetch(`${host}/3/device/${input.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": `final-exam-${input.classSessionId}-${input.studentId}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        sound: "default",
        "content-available": 1
      },
      type: "classmanager.final_exam_result",
      studentId: input.studentId,
      classSessionId: input.classSessionId,
      quizId: input.result.quizId,
      responseId: input.result.responseId,
      passed,
      scoreText: input.result.scoreText ?? null,
      percentageScore: input.result.percentageScore ?? null,
      completedAt: input.result.completedAt ?? null
    })
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`apns_${response.status}_${text}`);
  }
}

async function sendInstructorReminderApns(
  env: Env,
  input: {
    token: string;
    apnsEnvironment: "prod" | "sandbox";
    classSessionId: string;
    title: string;
    body: string;
  }
): Promise<void> {
  const topic = (env.APNS_BUNDLE_ID ?? "").trim();
  if (!topic) {
    throw new Error("missing_apns_topic");
  }

  const host = input.apnsEnvironment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  const jwt = await apnsJwt(env);

  const response = await fetch(`${host}/3/device/${input.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": `instructor-checkout-${input.classSessionId}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      aps: {
        alert: { title: input.title, body: input.body },
        sound: "default",
        "content-available": 1
      },
      type: "classmanager.instructor_checkout_reminder",
      classSessionId: input.classSessionId
    })
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`apns_${response.status}_${text}`);
  }
}

async function sendInstructorDashboardApns(
  env: Env,
  input: {
    token: string;
    apnsEnvironment: "prod" | "sandbox";
    classSessionId: string;
    studentId?: string;
    event: string;
    title: string;
    body: string;
    quizId?: string;
    responseId?: string;
    scoreText?: string;
    resultText?: string;
    completedAt?: string;
  }
): Promise<void> {
  const topic = (env.APNS_BUNDLE_ID ?? "").trim();
  if (!topic) {
    throw new Error("missing_apns_topic");
  }

  const host = input.apnsEnvironment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";
  const jwt = await apnsJwt(env);

  const response = await fetch(`${host}/3/device/${input.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": `instructor-dashboard-${input.classSessionId}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      aps: {
        alert: { title: input.title, body: input.body },
        sound: "default",
        "content-available": 1
      },
      type: "classmanager.instructor_dashboard_update",
      event: input.event,
      classSessionId: input.classSessionId,
      studentId: input.studentId ?? null,
      quizId: input.quizId ?? null,
      responseId: input.responseId ?? null,
      scoreText: input.scoreText ?? null,
      resultText: input.resultText ?? null,
      completedAt: input.completedAt ?? null
    })
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(`apns_${response.status}_${text}`);
  }
}

async function handleApnsFailure(env: Env, token: string, error: unknown): Promise<void> {
  const message = String(error);
  if (/BadDeviceToken|Unregistered|DeviceTokenNotForTopic/.test(message)) {
    await env.DB.prepare(`DELETE FROM device_tokens WHERE token = ?1`).bind(token).run();
  }
}

function joinUrl(base: string, path: string): string {
  return `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;
}
