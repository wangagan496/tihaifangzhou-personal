import assert from 'node:assert/strict';
import test from 'node:test';
import { relevantFaults, assertNoNewFaults, visibleAppPage, isLocked, unlockGesture } from './emulator-smoke.mjs';

const bundle = 'com.mine.myapplication';
const originalAppFault = 'appfreeze-com.mine.myapplication-20020064-20260913112244699.log';
const originalRenderFault = 'sysfreeze-render_service-1003-20260913112239513.log';
const app = { attributes: { bundleName: bundle, pagePath: 'pages/Index', visible: 'true', bounds: '[0,0][1320,2856]' } };

test('detects the supplied native renderer and application freeze reports', () => {
  const result = relevantFaults([originalAppFault, originalRenderFault, 'appfreeze-com.other.app-1-1.log'], bundle);
  assert.deepEqual(result, [originalAppFault, originalRenderFault]);
  assert.throws(() => assertNoNewFaults([], result), /New freeze\/crash reports/);
});
test('preserves historical reports without mistaking them for a new failure', () => {
  assertNoNewFaults([originalAppFault, originalRenderFault], [originalAppFault, originalRenderFault]);
});
test('a successful start command is insufficient without a visible target page', () => {
  assert.equal(visibleAppPage({ attributes: {}, children: [] }, bundle), undefined);
  assert.equal(visibleAppPage(app, bundle), 'pages/Index');
  assert.equal(visibleAppPage(app, 'com.other.app'), undefined);
});
test('ignores hidden and zero-area application surfaces', () => {
  assert.equal(visibleAppPage({ attributes: { visible: 'false' }, children: [app] }, bundle), undefined);
  assert.equal(visibleAppPage({ attributes: { ...app.attributes, bounds: '[0,0][0,0]' } }, bundle), undefined);
});
test('recognizes the observed emulator lock screen', () => {
  assert.equal(isLocked({ children: [{ attributes: { id: 'sl_clock' } }] }), true);
  assert.equal(isLocked(app), false);
});
test('uses observed screen bounds for unlocking and refuses unknown geometry', () => {
  assert.deepEqual(unlockGesture({ attributes: { bounds: '[0,0][1000,2000]' } }), ['500', '1800', '500', '500']);
  assert.throws(() => unlockGesture({ attributes: {} }), /unlock manually/);
});
