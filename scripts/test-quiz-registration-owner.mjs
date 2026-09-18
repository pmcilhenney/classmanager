import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

// Exercise the deployed handler's guard without calling production services.
const source = fs.readFileSync(new URL('../worker/src/index.ts', import.meta.url), 'utf8');
const start = source.indexOf('async function verifyQuizRegistrationOwner(');
const end = source.indexOf('async function assignQuiz(', start);
assert.ok(start >= 0 && end > start);
let lookups = 0;
let audits = 0;
const context = {
  HttpError: class extends Error {
    constructor(status, message) { super(message); this.status = status; }
  },
  stringField: (row, key) => row[key],
  audit: async () => { audits++; },
  fetchJotformSubmission: async () => { lookups++; return {}; },
  normalizeSessionLookup: () => ({ attendee: { oemsId: 'student-a' } })
};
vm.createContext(context);
vm.runInContext(ts.transpile(source.slice(start, end)), context);
const envFor = owners => ({
  DB: { prepare: () => ({ bind: () => ({
    all: async () => ({ results: owners.map(student_id => ({ student_id })) })
  }) }) }
});
const verify = context.verifyQuizRegistrationOwner;
await verify(envFor(['student-a']), 'student-a', 'registration-a');
assert.equal(lookups, 0);
await assert.rejects(verify(envFor(['student-b']), 'student-a', 'registration-b'), e => e.status === 409);
await assert.rejects(verify(envFor(['student-a', 'student-b']), 'student-a', 'conflicting-registration'), e => e.status === 409);
assert.equal(audits, 2);
await assert.rejects(verify(envFor([]), undefined, 'registration-a'), e => e.status === 400);
await assert.rejects(verify(envFor([]), 'student-a', undefined), e => e.status === 400);
await verify(envFor([]), 'student-a', 'uncached-registration');
await assert.rejects(verify(envFor([]), 'student-b', 'uncached-registration'), e => e.status === 409);
assert.equal(lookups, 2);
console.log('Quiz registration ownership checks passed.');
