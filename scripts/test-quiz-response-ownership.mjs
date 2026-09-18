import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
import { DatabaseSync } from 'node:sqlite';

const read = path => fs.readFileSync(new URL(path, import.meta.url), 'utf8');
const db = new DatabaseSync(':memory:');
db.exec(read('../worker/migrations/0001_initial.sql'));
db.exec(read('../worker/migrations/0002_apns_final_exam_results.sql'));
db.exec(read('../worker/migrations/0021_quiz_response_ownership.sql'));
db.exec("INSERT INTO students(id,first_name,last_name) VALUES ('a','Student','A'),('b','Student','B'); INSERT INTO class_sessions(id,course_title,course_date) VALUES ('class','Refresher A','09/17/2026');");
const response = '11111111-2222-3333-4444-555555555555';
const insertAttempt = db.prepare('INSERT INTO quiz_attempts(id,student_id,class_session_id,quiz_id,response_id) VALUES (?,?,\'class\',\'quiz\',?)');
const insertFinal = db.prepare('INSERT INTO final_exam_results(id,student_id,class_session_id,quiz_id,response_id) VALUES (?,?,\'class\',\'quiz\',?)');
insertAttempt.run('attempt-a','a',response);
insertFinal.run('final-a','a',response);
assert.throws(() => insertAttempt.run('attempt-b','b',response), /quiz_response_owner_conflict/);
assert.throws(() => insertFinal.run('final-b','b',response), /quiz_response_owner_conflict/);
for (const table of ['quiz_attempts','final_exam_results']) {
  assert.throws(() => db.exec(`UPDATE ${table} SET student_id='b' WHERE student_id='a'`), /quiz_response_owner_conflict/);
  db.exec(`UPDATE ${table} SET score_text='10/12' WHERE student_id='a'`);
}
// Legacy workflow markers are shared labels, not actual exam responses.
insertAttempt.run('marker-a','a','quiz-version-a-review-complete');
insertAttempt.run('marker-b','b','quiz-version-a-review-complete');

const source = read('../worker/src/index.ts');
function extract(name, next) {
  const start=source.indexOf(`async function ${name}(`);
  const end=source.indexOf(`async function ${next}(`,start);
  assert.ok(start>=0 && end>start);
  return source.slice(start,end);
}
const env = { DB: { prepare: sql => ({ bind: (...args) => ({
  first: async () => db.prepare(sql).get(...args),
  all: async () => ({results: db.prepare(sql).all(...args)}),
  run: async () => db.prepare(sql).run(...args)
}) }) } };
const context = {
  HttpError: class extends Error { constructor(status,message){super(message);this.status=status;} },
  audit: async () => {},
  stringField: (row,key) => row[key],
  classRegistrationFlexiQuizUserName: ({sourceSubmissionId,studentId,classSessionId}) =>
    `classmanager.${sourceSubmissionId ?? `${studentId}.${classSessionId}`}@gcemstrainingacademy.org`
};
vm.createContext(context);
vm.runInContext(ts.transpile(extract('verifyQuizResponseOwner','saveQuizAttempt')),context);
await context.verifyQuizResponseOwner(env,'a',response);
await assert.rejects(context.verifyQuizResponseOwner(env,'b',response),e=>e.status===409);
await context.verifyQuizResponseOwner(env,'b','quiz-version-a-review-complete');

db.exec('CREATE TABLE scheduled_course_students(student_id TEXT,class_session_id TEXT,submission_id TEXT)');
db.exec("INSERT INTO scheduled_course_students VALUES ('a','class','registration-a'),('b','class','registration-b')");
vm.runInContext(ts.transpile(extract('verifiedResultDeviceContexts','matchingDeviceContexts')),context);
const matches = await context.verifiedResultDeviceContexts(env,[
  {student_id:'a',class_session_id:'class'},
  {student_id:'b',class_session_id:'class'},
  {student_id:'a',class_session_id:'old-class'}
],'classmanager.registration-a@gcemstrainingacademy.org');
assert.equal(matches.length,1);
assert.equal(matches[0].student_id,'a');
db.exec("INSERT INTO scheduled_course_students VALUES ('a','class','123456789')");
const withoutDevice = await context.verifiedResultDeviceContexts(env,[],
  'classmanager.123456789@gcemstrainingacademy.org');
assert.equal(withoutDevice.length,1);
assert.equal(withoutDevice[0].student_id,'a');
assert.equal(withoutDevice[0].token,undefined);
db.exec("INSERT INTO scheduled_course_students VALUES ('b','class','123456789')");
const ambiguous = await context.verifiedResultDeviceContexts(env,[],
  'classmanager.123456789@gcemstrainingacademy.org');
assert.equal(ambiguous.length,0);

vm.runInContext(ts.transpile(extract('touchDeviceContext','touchInstructorDeviceContext')),context);
db.exec("INSERT INTO device_tokens(token,device_id,student_id,class_session_id,email,flexiquiz_user_id) VALUES ('token','tablet','a','class','a@example.test','fq-a')");
await context.touchDeviceContext(env,{deviceId:'tablet',studentId:'a',classSessionId:'class'});
assert.equal(db.prepare('SELECT flexiquiz_user_id FROM device_tokens').get().flexiquiz_user_id,'fq-a');
await context.touchDeviceContext(env,{deviceId:'tablet',studentId:'b',classSessionId:'class'});
let device=db.prepare('SELECT email,flexiquiz_user_id FROM device_tokens').get();
assert.equal(device.flexiquiz_user_id,null);
assert.equal(device.email,null);
await context.touchDeviceContext(env,{deviceId:'tablet',studentId:'b',classSessionId:'class',flexiquizUserId:'fq-b'});
await context.touchDeviceContext(env,{deviceId:'tablet',studentId:'b',classSessionId:'next-class'});
assert.equal(db.prepare('SELECT flexiquiz_user_id FROM device_tokens').get().flexiquiz_user_id,null);
console.log('PASS: response ownership, immutable saves, workflow markers, webhook routing, tablet identity changes');
