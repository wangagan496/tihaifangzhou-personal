import assert from 'node:assert/strict';
import test from 'node:test';
import { references, validateRequiredPages } from './feature-lib.mjs';

const routes = (source) => references('entry/src/main/ets/pages/Test.ets', source).routes;

test('finds routes after interpolated strings (message settings regression)', () => {
  assert.deepEqual(routes("const size = `${value}MB`; go({ url: 'pages/MessageSettingsPage' });"), ['pages/MessageSettingsPage']);
});
test('handles nested templates, expression braces, and multiple substitutions', () => {
  assert.deepEqual(routes('const s = `${foo({ value: `${1}` })}:${2}`; go("pages/Index");'), ['pages/Index']);
});
test('finds literal routes inside interpolation and after a tagged template', () => {
  assert.deepEqual(routes('const s = tag`${go("pages/LoginPage")} done`; go(`pages/Index`);'), ['pages/LoginPage', 'pages/Index']);
});
test('ignores comments and template text that merely contains route examples', () => {
  assert.deepEqual(routes('// go("pages/Fake")\n/* ` */ const s = `example "pages/Fake" ${1}`; go("pages/Index");'), ['pages/Index']);
});
test('keeps relative import discovery and deduplicates routes', () => {
  assert.deepEqual(references('entry/src/main/ets/pages/Test.ets', 'import { x } from "../models/X"; go("pages/Index"); go("pages/Index");'), {
    imports: ['entry/src/main/ets/models/X'], routes: ['pages/Index']
  });
});
test('required-page contract rejects a mine branch even if the scanner finds no routes', () => {
  assert.throws(() => validateRequiredPages('mine', [
    'pages/Index', 'pages/ProfileEditPage', 'pages/SettingsPage', 'pages/MineFeedbackPage', 'pages/MineAboutPage'
  ]), /MessageSettingsPage/);
});
test('accepts framework contract and rejects unknown feature names', () => {
  validateRequiredPages('main', ['pages/Index']);
  assert.throws(() => validateRequiredPages('unknown', ['pages/Index']), /Unknown feature/);
});
