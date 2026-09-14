import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { flattenLayout, isLocked, unlockGesture, visibleAppPage } from './emulator-smoke.mjs';

const device = '127.0.0.1:5555';
const bundle = 'com.mine.myapplication';
const hdc = 'C:/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const loginPath = fs.existsSync('entry/demo-login.local.json')
  ? 'entry/demo-login.local.json' : 'D:/tihaifangzhou/entry/demo-login.local.json';
const out = 'branch-verification/feedback';
fs.mkdirSync(out, { recursive: true });
const run = (args, timeout = 20000) => {
  const result = execFileSync(hdc, ['-t', device, ...args], { encoding: 'utf8', timeout, windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
  if (/^\[Fail\]/m.test(result) && !args.includes('rport')) throw new Error(result);
  return result.trim();
};
const delay = ms => new Promise(r => setTimeout(r, ms));
const getLayout = () => {
  run(['shell', 'uitest', 'dumpLayout', '-p', '/data/local/tmp/thfz-fb.json']);
  return JSON.parse(run(['shell', 'cat', '/data/local/tmp/thfz-fb.json']));
};
const nodes = tree => flattenLayout(tree).filter(n => n.visible !== 'false');
const pageOf = tree => visibleAppPage(tree, bundle);
const bounds = n => (n.bounds || '').match(/-?\d+/g)?.map(Number) || [];
const center = n => { const b = bounds(n); return [String(Math.round((b[0]+b[2])/2)), String(Math.round((b[1]+b[3])/2))]; };
const click = async n => { run(['shell', 'uitest', 'uiInput', 'click', ...center(n)]); await delay(700); };
const find = (tree, text) => nodes(tree).find(n => n.text === text);
const includes = (tree, text) => nodes(tree).find(n => (n.text || '').includes(text));
const capture = name => {
  const tree = getLayout();
  fs.writeFileSync(`${out}/${name}.json`, JSON.stringify(tree));
  run(['shell', 'snapshot_display', '-f', `/data/local/tmp/${name}.jpeg`]);
  run(['file', 'recv', `/data/local/tmp/${name}.jpeg`, `${out}/${name}.jpeg`]);
  return tree;
};
const waitFor = async (pred, label, retries = 12) => {
  let tree;
  for (let i = 0; i < retries; i++) { tree = getLayout(); if (pred(tree)) return tree; await delay(500); }
  capture('last-failure');
  throw new Error(`timeout ${label} page=${pageOf(tree)}`);
};
const clickText = async text => { const tree = await waitFor(t => find(t, text), text); await click(find(tree, text)); };
const onLogin = t => pageOf(t) === 'pages/LoginPage' || (find(t, '登录') && includes(t, '请输入账号'));
const hideKb = async () => { run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']); await delay(400); };

run(['shell', 'power-shell', 'wakeup']);
let tree = getLayout();
if (isLocked(tree)) {
  run(['shell', 'uitest', 'uiInput', 'swipe', ...unlockGesture(tree), '900']);
  await delay(400);
}
run(['shell', 'aa', 'force-stop', bundle]);
await delay(400);
run(['shell', 'aa', 'start', '-b', bundle, '-a', 'EntryAbility']);
await waitFor(t => pageOf(t) === 'pages/Index', 'index', 20);
await clickText('我的');
tree = await waitFor(t => find(t, '意见反馈') || find(t, '请登录') || onLogin(t), 'mine');
if (find(tree, '请登录') || onLogin(tree)) {
  if (find(tree, '请登录')) await clickText('请登录');
  tree = await waitFor(onLogin, 'login');
  const creds = JSON.parse(fs.readFileSync(loginPath, 'utf8'));
  const fields = nodes(tree).filter(n => n.type === 'TextInput');
  await click(fields[0]);
  run(['shell', 'uitest', 'uiInput', 'inputText', ...center(fields[0]), creds.DEMO_USERNAME]);
  await hideKb();
  tree = getLayout();
  const password = nodes(tree).filter(n => n.type === 'TextInput')[1];
  await click(password);
  run(['shell', 'uitest', 'uiInput', 'inputText', ...center(password), creds.DEMO_PASSWORD]);
  await hideKb();
  tree = await waitFor(t => find(t, '登录'), 'login btn');
  const box = nodes(tree).find(n => n.type === 'Checkbox');
  if (box && box.checked !== 'true') await click(box);
  await clickText('登录');
  await waitFor(t => !onLogin(t), 'left login', 24);
  if (!find(getLayout(), '意见反馈')) await clickText('我的');
}
await clickText('意见反馈');
await waitFor(t => find(t, '提交反馈'), 'feedback page', 16);
capture('feedback-page');
const area = nodes(getLayout()).find(n => n.type === 'TextArea');
if (!area) throw new Error('feedback textarea missing');
await click(area);
run(['shell', 'uitest', 'uiInput', 'inputText', ...center(area), '设备验证：从应用提交的意见反馈。']);
await hideKb();
const before = fs.existsSync('backend/data/feedback.jsonl') ?
  fs.readFileSync('backend/data/feedback.jsonl', 'utf8').trim().split(/\n/).filter(Boolean).length : 0;
await clickText('提交反馈');
await waitFor(t => nodes(t).some(n => (n.text || '').includes('已送达') || (n.text || '').includes('已保存')), 'submit result', 20);
capture('feedback-submitted');
const after = fs.existsSync('backend/data/feedback.jsonl') ?
  fs.readFileSync('backend/data/feedback.jsonl', 'utf8').trim().split(/\n/).filter(Boolean).length : 0;
if (after <= before) throw new Error(`feedback file did not grow: ${before} -> ${after}`);
console.log(`PASS device feedback delivered; records ${before} -> ${after}`);
