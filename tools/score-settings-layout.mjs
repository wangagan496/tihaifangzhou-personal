import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';
import { flattenLayout, visibleAppPage } from './emulator-smoke.mjs';

const layout = process.argv[2] || 'portrait';
if (!['portrait', 'landscape'].includes(layout)) throw new Error('Expected portrait or landscape');
const device = process.env.HDC_DEVICE || '127.0.0.1:5555';
const hdc = process.env.HDC_PATH || 'C:/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const dir = 'branch-verification';
fs.mkdirSync(dir, { recursive: true });
const run = args => {
  const result = execFileSync(hdc, ['-t', device, ...args], { encoding: 'utf8', windowsHide: true, timeout: 15000 });
  if (/\[Fail\]/.test(result)) throw new Error('HDC operation failed');
  return result;
};
let log = '';
let exited = false;
const child = spawn(hdc, ['-t', device, 'shell', 'aa', 'test', '-b', 'com.mine.myapplication', '-m', 'entry_test',
  '-s', 'unittest', 'ScoreSettingsRunner', '-s', 'layout', layout, '-w', '90'], { windowsHide: true });
child.stdout.on('data', bytes => { log += bytes.toString(); });
child.stderr.on('data', bytes => { log += bytes.toString(); });
child.on('exit', () => { exited = true; });
child.on('error', () => { exited = true; });
const wait = async marker => {
  const deadline = Date.now() + 60000;
  while (!log.includes(marker)) {
    if (exited || Date.now() > deadline) throw new Error(`Missing test marker ${marker}`);
    await new Promise(resolve => setTimeout(resolve, 200));
  }
};
const capture = (name, expectedPage) => {
  const remote = `/data/local/tmp/${name}`;
  run(['shell', 'uitest', 'dumpLayout', '-p', `${remote}.json`]);
  const tree = JSON.parse(run(['shell', 'cat', `${remote}.json`]));
  if (visibleAppPage(tree, 'com.mine.myapplication') !== expectedPage) throw new Error(`Wrong visible page for ${name}`);
  fs.writeFileSync(path.join(dir, `${name}.json`), JSON.stringify(tree));
  run(['shell', 'snapshot_display', '-f', `${remote}.jpeg`]);
  run(['file', 'recv', `${remote}.jpeg`, path.join(dir, `${name}.jpeg`)]);
  return flattenLayout(tree);
};
try {
  await wait('SCORE_CLEAN_PAGE_READY');
  const first = capture(`score-clean-${layout}`, 'pages/AiScorePage');
  if (first.some(n => n.id === 'scoreSettingsAccessCode' || n.text === '服务访问码')) throw new Error('Credential field leaked into score page');
  if (layout === 'portrait') {
    const answer = first.find(n => n.id === 'scoreAnswer');
    const bounds = answer?.bounds.match(/\d+/g)?.map(Number);
    if (!answer || !bounds || bounds.length !== 4) throw new Error('Missing editable answer field');
    const [left, top, right, bottom] = bounds;
    run(['shell', 'uitest', 'uiInput', 'inputText', String(Math.round((left + right) / 2)),
      String(Math.round((top + bottom) / 2)), 'edited-answer-retained-after-settings']);
    run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
    await new Promise(resolve => setTimeout(resolve, 400));
    const edited = capture('score-edited-portrait', 'pages/AiScorePage').find(n => n.id === 'scoreAnswer');
    if (!edited || !edited.text.includes('edited-answer-retained-after-settings')) throw new Error('Draft edit was not applied');
    answer.text = edited.text;
  }
  await wait('SCORE_SETTINGS_PAGE_READY');
  const settings = capture(`score-settings-${layout}`, 'pages/ScoreSettingsPage');
  if (layout === 'landscape') {
    const scroll = settings.find(n => n.type === 'Scroll');
    const bounds = scroll?.bounds.match(/\d+/g)?.map(Number);
    if (!bounds || bounds.length !== 4) throw new Error('Missing settings scroll bounds');
    const [left, top, right, bottom] = bounds;
    const x = Math.round((left + right) / 2);
    run(['shell', 'uitest', 'uiInput', 'swipe', String(x), String(Math.round(bottom - 100)), String(x), String(Math.round(top + 80)), '1500']);
    await new Promise(resolve => setTimeout(resolve, 700));
    const bottomNodes = capture('score-settings-landscape-bottom', 'pages/ScoreSettingsPage');
    if (!bottomNodes.some(n => n.id === 'saveScoreSettings' && n.visible !== 'false')) throw new Error('Save button unreachable');
  }
  await wait('SCORE_RETURN_DRAFT_READY');
  const returned = capture(`score-return-${layout}`, 'pages/AiScorePage');
  for (const id of ['scoreQuestion', 'scoreAnswer']) {
    const before = first.find(n => n.id === id);
    const after = returned.find(n => n.id === id);
    // Offscreen fields may be omitted in landscape. Portrait verifies both fields.
    if (layout === 'portrait' && (!before || !after || !before.text)) throw new Error(`Missing required field ${id}`);
    if (before && (!after || before.text !== after.text)) throw new Error(`Draft changed: ${id}`);
  }
  await wait('TestFinished-ResultCode: 0');
  console.log(`PASS ${layout}: score page has no credential field; correct pages rendered; visible draft fields retained`);
} finally {
  fs.writeFileSync(path.join(dir, `score-settings-ui-${layout}.log`), log);
}
