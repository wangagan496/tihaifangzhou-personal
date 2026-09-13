import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { visibleAppPage } from './emulator-smoke.mjs';

// Read-only account checks: never logs in or changes stored user data.
const device = process.env.HDC_DEVICE || '127.0.0.1:5555';
const hdc = process.env.HDC_PATH || path.join(process.env.DEVECO_HOME || 'C:/Huawei/DevEco Studio',
  'sdk/default/openharmony/toolchains/hdc.exe');
const bundle = 'com.mine.myapplication';
const remote = `/data/local/tmp/study-card-smoke-${process.pid}.json`;
const run = args => {
  const output = execFileSync(hdc, ['-t', device, ...args], {
    encoding: 'utf8', timeout: 15000, windowsHide: true, maxBuffer: 4 * 1024 * 1024
  });
  if (/^\[Fail\]/m.test(output)) throw new Error('HDC operation failed');
  return output;
};
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const cases = [
  ['cold', 'favorites', ['pages/MineQuestionsPage', 'pages/LoginPage']],
  ['warm', 'questions', ['pages/Index']],
  ['warm', 'audio', ['pages/AudioPage', 'pages/LoginPage']],
  ['cold', 'audio', ['pages/AudioPage', 'pages/LoginPage']],
  ['warm', 'favorites', ['pages/MineQuestionsPage', 'pages/LoginPage']],
  ['cold', 'questions', ['pages/Index']]
];
const results = [];
for (const [mode, action, expected] of cases) {
  if (mode === 'cold') run(['shell', 'aa', 'force-stop', bundle]);
  run(['shell', 'aa', 'start', '-b', bundle, '-a', 'EntryAbility', '--ps', 'studyCardAction', action]);
  let page = '';
  for (let attempt = 0; attempt < 12; attempt++) {
    await delay(500);
    run(['shell', 'uitest', 'dumpLayout', '-p', remote]);
    const tree = JSON.parse(run(['shell', 'cat', remote]));
    page = visibleAppPage(tree, bundle) || '';
    if (expected.includes(page)) break;
  }
  if (!expected.includes(page)) throw new Error(`${mode} ${action}: expected ${expected.join(' or ')}, got ${page}`);
  results.push({ mode, action, page });
  console.log(`PASS ${mode} ${action}: ${page}`);
}
fs.mkdirSync('branch-verification', { recursive: true });
fs.writeFileSync('branch-verification/study-card-routes.json', JSON.stringify({
  checkedAt: new Date().toISOString(), results,
  boundary: 'Want routing regression; account data is neither printed nor modified; actual launcher rendering checked separately'
}, null, 2));
