import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { flattenLayout, isLocked, unlockGesture, visibleAppPage } from './emulator-smoke.mjs';

const device = process.env.HDC_DEVICE || '127.0.0.1:5555';
const bundle = 'com.mine.myapplication';
const hdc = process.env.HDC_PATH || 'C:/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const out = 'branch-verification/live-score';
const loginPath = fs.existsSync('entry/demo-login.local.json')
  ? 'entry/demo-login.local.json' : 'D:/tihaifangzhou/entry/demo-login.local.json';
const env = Object.fromEntries(fs.readFileSync('backend/.env', 'utf8').split(/\r?\n/)
  .filter(line => line && !line.startsWith('#') && line.includes('='))
  .map(line => { const i = line.indexOf('='); return [line.slice(0, i), line.slice(i + 1)]; }));
const question = 'const 声明的对象属性可以修改吗？';
const answer = '可以。const 只绑定变量本身不能被重新赋值，对象内部的属性仍然可以改。';

fs.mkdirSync(out, { recursive: true });

const run = (args, timeout = 20000) => {
  const result = execFileSync(hdc, ['-t', device, ...args], {
    encoding: 'utf8', timeout, windowsHide: true, maxBuffer: 8 * 1024 * 1024
  });
  if (/^\[Fail\]/m.test(result)) throw new Error(`HDC failed: ${args.slice(0, 4).join(' ')}\n${result}`);
  return result.trim();
};
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const getLayout = () => {
  const remote = '/data/local/tmp/thfz-live.json';
  const output = run(['shell', 'uitest', 'dumpLayout', '-p', remote]);
  if (!output.includes('DumpLayout saved')) throw new Error('dumpLayout failed');
  return JSON.parse(run(['shell', 'cat', remote]));
};
const visible = node => node.visible !== 'false' && (node.opacity === undefined || node.opacity === '' || Number(node.opacity) > 0);
const nodes = tree => flattenLayout(tree).filter(visible);
const pageOf = tree => visibleAppPage(tree, bundle);
const boundsOf = node => (node.bounds || '').match(/-?\d+/g)?.map(Number) || [];
const center = node => {
  const b = boundsOf(node);
  if (b.length !== 4 || b[2] <= b[0] || b[3] <= b[1]) throw new Error(`Bad bounds for ${node.text || node.id || node.type}`);
  return [String(Math.round((b[0] + b[2]) / 2)), String(Math.round((b[1] + b[3]) / 2))];
};
const clickNode = async node => { run(['shell', 'uitest', 'uiInput', 'click', ...center(node)]); await delay(700); };
const findExact = (tree, text) => nodes(tree).find(n => n.text === text);
const findIncludes = (tree, text) => nodes(tree).find(n => (n.text || '').includes(text));
const findId = (tree, id) => nodes(tree).find(n => n.id === id);
const texts = tree => nodes(tree).map(n => n.text).filter(Boolean);
const capture = name => {
  const tree = getLayout();
  fs.writeFileSync(path.join(out, `${name}.json`), JSON.stringify(tree));
  const remote = `/data/local/tmp/${name}.jpeg`;
  run(['shell', 'snapshot_display', '-f', remote]);
  run(['file', 'recv', remote, path.join(out, `${name}.jpeg`)]);
  return tree;
};
const waitFor = async (predicate, label, retries = 12, interval = 500) => {
  let tree;
  for (let i = 0; i < retries; i++) {
    tree = getLayout();
    if (predicate(tree)) return tree;
    await delay(interval);
  }
  capture('last-failure');
  throw new Error(`Timed out waiting for ${label}; page=${pageOf(tree)}`);
};
const clickText = async (text, { includes = false, retries = 10 } = {}) => {
  const tree = await waitFor(t => includes ? findIncludes(t, text) : findExact(t, text), `text ${text}`, retries);
  await clickNode(includes ? findIncludes(tree, text) : findExact(tree, text));
  return getLayout();
};
const back = async () => { run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']); await delay(800); };
const hideKeyboard = async () => { run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']); await delay(400); };
const onLoginPage = tree => pageOf(tree) === 'pages/LoginPage' ||
  (findExact(tree, '登录') && findIncludes(tree, '请输入账号'));

const ensureLoggedIn = async () => {
  let tree = getLayout();
  if (findExact(tree, '请登录') && !onLoginPage(tree)) {
    await clickText('请登录');
    tree = await waitFor(onLoginPage, 'login page', 12);
  }
  if (!onLoginPage(tree)) return tree;
  const creds = JSON.parse(fs.readFileSync(loginPath, 'utf8'));
  const fields = nodes(tree).filter(n => n.type === 'TextInput');
  if (fields.length < 2) throw new Error('Login inputs missing');
  await clickNode(fields[0]);
  run(['shell', 'uitest', 'uiInput', 'inputText', ...center(fields[0]), String(creds.DEMO_USERNAME)]);
  await hideKeyboard();
  tree = getLayout();
  const password = nodes(tree).filter(n => n.type === 'TextInput')[1];
  await clickNode(password);
  run(['shell', 'uitest', 'uiInput', 'inputText', ...center(password), String(creds.DEMO_PASSWORD)]);
  await hideKeyboard();
  const agreed = await waitFor(t => findExact(t, '登录'), 'login button', 12);
  const checkbox = nodes(agreed).find(n => n.type === 'Checkbox');
  if (checkbox && checkbox.checked !== 'true' && checkbox.selected !== 'true') await clickNode(checkbox);
  await clickText('登录');
  return waitFor(t => !onLoginPage(t) && !findIncludes(t, '登录失败'), 'leave login', 24);
};

const typeInto = async (node, value) => {
  await clickNode(node);
  run(['shell', 'uitest', 'uiInput', 'inputText', ...center(node), value]);
  await hideKeyboard();
};

const report = { startedAt: new Date().toISOString(), checks: [] };
const pass = (name, detail) => { report.checks.push({ name, status: 'pass', detail }); console.log(`PASS ${name}: ${detail}`); };

try {
  if (!env.API_ACCESS_TOKEN) throw new Error('API_ACCESS_TOKEN missing from backend/.env');
  run(['shell', 'power-shell', 'wakeup']);
  run(['shell', 'power-shell', 'timeout', '-o', '600000']);
  let tree = getLayout();
  if (isLocked(tree)) {
    run(['shell', 'uitest', 'uiInput', 'swipe', ...unlockGesture(tree), '900']);
    await delay(500);
    if (isLocked(getLayout())) throw new Error('Please unlock the device');
  }
  run(['shell', 'aa', 'force-stop', bundle]);
  await delay(400);
  const started = run(['shell', 'aa', 'start', '-b', bundle, '-a', 'EntryAbility']);
  if (!started.includes('start ability successfully')) throw new Error('Ability start rejected');
  await waitFor(t => pageOf(t) === 'pages/Index', 'Index', 20);
  await clickText('我的');
  await waitFor(t => findExact(t, '设置') || findExact(t, '请登录') || onLoginPage(t), 'mine', 12);
  await ensureLoggedIn();
  if (!findExact(getLayout(), '设置')) await clickText('我的');
  await clickText('设置');
  if (onLoginPage(getLayout())) {
    await ensureLoggedIn();
    if (!findExact(getLayout(), '评分服务配置')) { await clickText('我的'); await clickText('设置'); }
  }
  await waitFor(t => findExact(t, '评分服务配置'), 'settings');
  await clickText('评分服务配置');
  const settings = await waitFor(t => pageOf(t) === 'pages/ScoreSettingsPage' || findId(t, 'scoreSettingsAccessCode'), 'score settings', 16);
  capture('score-settings-before');
  const codeInput = findId(settings, 'scoreSettingsAccessCode') || nodes(settings).find(n => n.type === 'TextInput');
  if (!codeInput) throw new Error('Access code field missing');
  await typeInto(codeInput, env.API_ACCESS_TOKEN);
  await clickText('保存配置');
  const saved = await waitFor(t => texts(t).some(v => v.includes('连接配置已保存') || v.includes('已保存')), 'saved credential', 20);
  capture('score-settings-saved');
  pass('save-access-code', texts(saved).find(v => v.includes('保存')) || 'credential saved');
  await back();
  await back();
  if (!findExact(getLayout(), 'AI 回答评分')) await clickText('我的');
  await clickText('AI 回答评分');
  if (onLoginPage(getLayout())) await ensureLoggedIn();
  const scorePage = await waitFor(t => pageOf(t) === 'pages/AiScorePage' || findId(t, 'submitAiScore') || findExact(t, '提交 AI 评分'), 'score page', 16);
  capture('score-page');
  if (findId(scorePage, 'scoringUnavailable')) throw new Error('Client still treats scoring as unconfigured');
  const questionNode = findId(getLayout(), 'scoreQuestion') || nodes(getLayout()).find(n => n.type === 'TextArea');
  const answerNode = findId(getLayout(), 'scoreAnswer') || nodes(getLayout()).filter(n => n.type === 'TextArea')[1];
  if (!questionNode || !answerNode) throw new Error('Score inputs missing');
  await typeInto(questionNode, question);
  await typeInto(answerNode, answer);
  capture('score-filled');
  const revealSubmit = async () => {
    for (let i = 0; i < 6; i++) {
      const current = getLayout();
      if (findExact(current, '提交 AI 评分') || findId(current, 'submitAiScore')) return current;
      const scroll = nodes(current).find(n => n.type === 'Scroll') || nodes(current).find(n => n.type === 'List');
      const target = scroll || { bounds: '[0,400][1320,2400]' };
      const b = boundsOf(target);
      const x = String(Math.round((b[0] + b[2]) / 2));
      run(['shell', 'uitest', 'uiInput', 'swipe', x, String(Math.round(b[3] - 120)), x, String(Math.round(b[1] + 160)), '900']);
      await delay(600);
    }
    return getLayout();
  };
  await revealSubmit();
  capture('score-submit-visible');
  if (findId(getLayout(), 'submitAiScore')) await clickNode(findId(getLayout(), 'submitAiScore'));
  else await clickText('提交 AI 评分');
  const dialog = await waitFor(t => findExact(t, '同意并评分') || findIncludes(t, '发送文字进行 AI 评分'), 'consent dialog', 16);
  capture('score-consent');
  await clickText('同意并评分');
  const scored = await waitFor(t => findId(t, 'aiScoreValue') || texts(t).some(v => /\/ 100$/.test(v) || v.includes('评分完成')), 'model result', 40, 1500);
  capture('score-result');
  const scoreText = texts(scored).find(v => /\/ 100/.test(v)) || findId(scored, 'aiScoreValue')?.text || '';
  const status = texts(scored).find(v => v.includes('评分完成') || v.includes('评分未完成') || v.includes('模型'));
  if (!scoreText && status && !status.includes('评分完成')) throw new Error(status);
  if (!scoreText) throw new Error(`No score value; texts=${texts(scored).slice(0, 12).join('|')}`);
  pass('device-live-score', `${scoreText}; ${status || 'result rendered'}`);
  report.status = 'passed';
} catch (error) {
  report.status = 'failed';
  report.error = error.message;
  try { capture('error'); } catch (_) {}
  console.error(`FAIL ${error.message}`);
} finally {
  try { run(['shell', 'power-shell', 'timeout', '-r']); } catch (_) {}
  report.finishedAt = new Date().toISOString();
  fs.writeFileSync(path.join(out, 'result.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(`Report: ${path.join(out, 'result.json')}`);
}
if (report.status !== 'passed') process.exit(1);
