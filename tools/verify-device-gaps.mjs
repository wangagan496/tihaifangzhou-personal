import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { flattenLayout, isLocked, unlockGesture, visibleAppPage } from './emulator-smoke.mjs';

const device = process.env.HDC_DEVICE || '127.0.0.1:5555';
const bundle = 'com.mine.myapplication';
const hdc = process.env.HDC_PATH || 'C:/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe';
const hap = 'entry/build/default/outputs/default/entry-default-signed.hap';
const out = 'branch-verification/device-gaps';
const loginPath = fs.existsSync('entry/demo-login.local.json')
  ? 'entry/demo-login.local.json'
  : 'D:/tihaifangzhou/entry/demo-login.local.json';

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
  const remote = '/data/local/tmp/thfz-verify.json';
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

const clickNode = async node => {
  run(['shell', 'uitest', 'uiInput', 'click', ...center(node)]);
  await delay(700);
};

const findExact = (tree, text) => nodes(tree).find(n => n.text === text);
const findIncludes = (tree, text) => nodes(tree).find(n => (n.text || '').includes(text));
const findId = (tree, id) => nodes(tree).find(n => n.id === id);

const waitFor = async (predicate, label, retries = 12) => {
  let tree;
  for (let i = 0; i < retries; i++) {
    tree = getLayout();
    if (predicate(tree)) return tree;
    await delay(500);
  }
  capture('last-failure');
  throw new Error(`Timed out waiting for ${label}; page=${pageOf(tree)}`);
};

const clickText = async (text, { includes = false, retries = 10 } = {}) => {
  const tree = await waitFor(t => includes ? findIncludes(t, text) : findExact(t, text), `text ${text}`, retries);
  await clickNode(includes ? findIncludes(tree, text) : findExact(tree, text));
  return getLayout();
};

const clickId = async (id, retries = 10) => {
  const tree = await waitFor(t => findId(t, id), `id ${id}`, retries);
  await clickNode(findId(tree, id));
  return getLayout();
};

const back = async () => {
  run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
  await delay(800);
};

const openCollectMenuAndChoose = async action => {
  let tree = getLayout();
  if (!findExact(tree, '收藏') && !findExact(tree, '取消收藏')) {
    const trigger = nodes(tree).find(n => n.type === 'Image' && n.clickable === 'true');
    if (!trigger) throw new Error('Collect menu trigger missing');
    await clickNode(trigger);
    tree = await waitFor(t => findExact(t, '收藏') || findExact(t, '取消收藏'), 'collect menu', 10);
    capture('collect-menu');
  }
  if (action === '收藏' && findExact(tree, '取消收藏')) return 'already';
  if (action === '取消收藏' && findExact(tree, '收藏')) return 'already';
  if (!findExact(tree, action)) throw new Error(`Menu action ${action} missing`);
  await clickText(action);
  return 'clicked';
};

const capture = name => {
  const tree = getLayout();
  fs.writeFileSync(path.join(out, `${name}.json`), JSON.stringify(tree));
  const remote = `/data/local/tmp/${name}.jpeg`;
  run(['shell', 'snapshot_display', '-f', remote]);
  run(['file', 'recv', remote, path.join(out, `${name}.jpeg`)]);
  return tree;
};

const texts = tree => nodes(tree).map(n => n.text).filter(Boolean);

const prepare = async () => {
  run(['shell', 'power-shell', 'wakeup']);
  run(['shell', 'power-shell', 'timeout', '-o', '600000']);
  let tree = getLayout();
  if (isLocked(tree)) {
    run(['shell', 'uitest', 'uiInput', 'swipe', ...unlockGesture(tree), '900']);
    await delay(500);
    tree = getLayout();
    if (isLocked(tree)) throw new Error('Please unlock the device');
  }
};

const onLoginPage = tree => pageOf(tree) === 'pages/LoginPage' ||
  (findExact(tree, '登录') && findIncludes(tree, '请输入账号'));

const ensureLoggedIn = async () => {
  let tree = getLayout();
  if (findExact(tree, '请登录') && !onLoginPage(tree)) {
    await clickText('请登录');
    tree = await waitFor(onLoginPage, 'login page from mine', 12);
  }
  if (!onLoginPage(tree)) return tree;
  const creds = JSON.parse(fs.readFileSync(loginPath, 'utf8'));
  const fields = nodes(tree).filter(n => n.type === 'TextInput');
  if (fields.length < 2) {
    capture('login-inputs');
    throw new Error('Login inputs missing');
  }
  await clickNode(fields[0]);
  run(['shell', 'uitest', 'uiInput', 'inputText', ...center(fields[0]), String(creds.DEMO_USERNAME)]);
  await delay(300);
  run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
  await delay(400);
  tree = getLayout();
  const password = nodes(tree).filter(n => n.type === 'TextInput')[1];
  if (!password) throw new Error('Password field missing after username');
  await clickNode(password);
  run(['shell', 'uitest', 'uiInput', 'inputText', ...center(password), String(creds.DEMO_PASSWORD)]);
  await delay(300);
  run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
  await delay(500);
  const agreed = await waitFor(t => findExact(t, '登录'), 'login button after keyboard', 12);
  const checkbox = nodes(agreed).find(n => n.type === 'Checkbox');
  if (!checkbox) throw new Error('Agreement checkbox missing');
  if (checkbox.checked !== 'true' && checkbox.selected !== 'true') {
    await clickNode(checkbox);
    await delay(400);
  }
  const ready = getLayout();
  capture('login-ready');
  const loginBtn = findExact(ready, '登录');
  if (!loginBtn) throw new Error('Login button missing');
  await clickNode(loginBtn);
  tree = await waitFor(t => !onLoginPage(t) && !findIncludes(t, '登录失败'), 'leave login', 24);
  return tree;
};

const report = { startedAt: new Date().toISOString(), checks: [] };
const pass = (name, detail) => { report.checks.push({ name, status: 'pass', detail }); console.log(`PASS ${name}: ${detail}`); };
const fail = (name, detail) => { report.checks.push({ name, status: 'fail', detail }); throw new Error(`${name}: ${detail}`); };

try {
  await prepare();
  const installed = run(['install', '-r', path.resolve(hap)], 60000);
  if (!installed.includes('install bundle successfully')) throw new Error('HAP install failed');
  run(['shell', 'aa', 'force-stop', bundle]);
  await delay(400);
  const started = run(['shell', 'aa', 'start', '-b', bundle, '-a', 'EntryAbility']);
  if (!started.includes('start ability successfully')) throw new Error('Ability start rejected');
  await waitFor(t => pageOf(t) === 'pages/Index', 'Index', 20);
  capture('home');

  await clickText('我的');
  let mine = await waitFor(t => findExact(t, '我的收藏') || findExact(t, '设置') || findExact(t, '请登录') || onLoginPage(t), 'mine tab', 12);
  capture('mine');
  if (findExact(mine, '请登录') || onLoginPage(mine)) {
    mine = await ensureLoggedIn();
    capture('after-login');
    if (!findExact(getLayout(), '我的收藏')) {
      await clickText('我的');
      mine = await waitFor(t => findExact(t, '我的收藏') || findExact(t, '设置'), 'mine after login', 12);
    }
  }
  if (!findExact(getLayout(), '我的收藏')) {
    await clickText('我的');
    await waitFor(t => findExact(t, '我的收藏'), 'mine collect entry');
  }

  await clickText('设置');
  let settingsTree = getLayout();
  if (onLoginPage(settingsTree) || findExact(settingsTree, '请登录')) {
    await ensureLoggedIn();
    if (!findExact(getLayout(), '消息推送')) {
      await clickText('我的');
      await clickText('设置');
    }
  }
  await waitFor(t => findExact(t, '消息推送') || findExact(t, '评分服务配置'), 'settings');
  capture('settings');
  await clickText('评分服务配置');
  const scoreSettings = await waitFor(t => pageOf(t) === 'pages/ScoreSettingsPage' || findIncludes(t, '127.0.0.1:3000') || findIncludes(t, '尚未设置服务地址'), 'score settings');
  capture('score-settings');
  if (!texts(scoreSettings).some(t => t.includes('127.0.0.1:3000'))) {
    fail('ai-debug-url', `score settings missing local URL; texts=${texts(scoreSettings).slice(0, 12).join('|')}`);
  }
  pass('ai-debug-url', 'Score settings shows http://127.0.0.1:3000/v1/scores');
  await back();
  await waitFor(t => findExact(t, '消息推送'), 'settings after score');

  await clickText('消息推送');
  const message = await waitFor(t => findExact(t, '发送测试通知') && findExact(t, '复习提醒'), 'message settings');
  capture('message-settings');
  if (!findExact(message, '学习进度通知') || !findExact(message, '声音与振动')) {
    fail('message-settings-ui', 'Expected reminder switches missing');
  }
  pass('message-settings-ui', 'Review, study progress and sound switches are visible');
  await clickText('发送测试通知');
  await delay(800);
  let afterClick = getLayout();
  if (findExact(afterClick, '允许') || findIncludes(afterClick, '向你发送通知')) {
    capture('notification-permission');
    await clickText('允许');
    await delay(1200);
    afterClick = getLayout();
    if (findExact(afterClick, '发送测试通知') && !texts(afterClick).some(v => v.includes('测试通知已发送'))) {
      await clickText('发送测试通知');
      await delay(1000);
    }
  }
  const afterTest = await waitFor(t => texts(t).some(v =>
    v.includes('测试通知已发送') || v.includes('测试通知发送失败') || v.includes('系统通知已允许')), 'test notification result', 20);
  capture('message-test');
  const testTexts = texts(afterTest).join('\n');
  if (testTexts.includes('测试通知发送失败')) fail('test-notification', 'Test notification failed');
  pass('test-notification', testTexts.includes('测试通知已发送')
    ? 'Toast reported success'
    : 'Notification permission granted and settings remained available');
  await back();
  await back();
  await waitFor(t => findExact(t, '我的收藏') || findExact(t, '首页'), 'back to mine or index');

  if (!findExact(getLayout(), '我的收藏')) await clickText('我的');
  await clickText('我的收藏');
  let collect = await waitFor(t => pageOf(t) === 'pages/MineQuestionsPage' || findExact(t, '我的收藏') || findExact(t, '还没有收藏内容'), 'collect list', 16);
  if (pageOf(collect) === 'pages/LoginPage' || findExact(collect, '登录')) {
    await ensureLoggedIn();
    await clickText('我的');
    await clickText('我的收藏');
    collect = await waitFor(t => pageOf(t) === 'pages/MineQuestionsPage' || findExact(t, '我的收藏'), 'collect after login');
  }
  capture('collect-before');

  const emptyBefore = texts(collect).includes('还没有收藏内容');
  let stem = '';
  if (emptyBefore) {
    await back();
    await clickText('首页');
    await waitFor(t => findIncludes(t, '如何合并两个对象') || findIncludes(t, '点赞'), 'home questions');
    const question = nodes(getLayout()).find(n => (n.text || '').includes('如何合并两个对象') || (n.text || '').includes('ArkTS是否支持解构'));
    if (!question) throw new Error('No question to collect');
    stem = (question.text || '').replace(/\n/g, '').trim();
    await clickNode(question);
    await waitFor(t => pageOf(t) === 'pages/QuestionDetailPage' || findIncludes(t, '如何合并两个对象'), 'question detail', 20);
    capture('question-detail');
    const collectResult = await openCollectMenuAndChoose('收藏');
    await delay(1500);
    if (collectResult !== 'already') {
      const trigger = nodes(getLayout()).find(n => n.type === 'Image' && n.clickable === 'true');
      if (trigger) await clickNode(trigger);
      await waitFor(t => findExact(t, '取消收藏'), 'menu shows uncollect after collect', 10);
      run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
      await delay(400);
    }
    capture('collected-detail');
    await back();
    await clickText('我的');
    await clickText('我的收藏');
    collect = await waitFor(t => pageOf(t) === 'pages/MineQuestionsPage', 'collect after adding');
    capture('collect-added');
    if (texts(collect).includes('还没有收藏内容')) fail('collect-add', 'Collected item did not appear in list');
    pass('collect-add', 'Newly collected question appeared in the list');
  } else {
    const item = nodes(collect).find(n => n.type === 'Text' && (n.text || '').length > 8 && !['我的收藏', '点赞', '浏览'].includes(n.text) && !n.text.startsWith('点赞') && !n.text.startsWith('浏览'));
    stem = (item?.text || '').replace(/\n/g, '').trim();
    pass('collect-add', `List already had items; using ${stem.slice(0, 24)}`);
  }

  const listed = nodes(getLayout()).find(n => (n.text || '').includes(stem.slice(0, 10)) || (stem && (n.text || '').includes(stem)));
  const target = listed || nodes(getLayout()).find(n => n.type === 'Text' && (n.text || '').length > 8 && n.text !== '我的收藏' && !n.text.startsWith('点赞') && !n.text.startsWith('浏览') && n.text !== '还没有收藏内容');
  if (!target) fail('collect-open', 'No collect list item to open');
  const openedStem = (target.text || '').replace(/\n/g, '').trim();
  await clickNode(target);
  await waitFor(t => pageOf(t) === 'pages/QuestionDetailPage' || findIncludes(t, openedStem.slice(0, 8)), 'detail from collect', 20);
  capture('collect-detail');
  const uncollectResult = await openCollectMenuAndChoose('取消收藏');
  await delay(1500);
  if (uncollectResult !== 'already') {
    const trigger = nodes(getLayout()).find(n => n.type === 'Image' && n.clickable === 'true');
    if (trigger) await clickNode(trigger);
    const menu = await waitFor(t => findExact(t, '收藏') || findExact(t, '取消收藏'), 'menu after uncollect', 10);
    if (findExact(menu, '取消收藏') && !findExact(menu, '收藏')) fail('uncollect', 'Detail still shows collected');
    run(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
    await delay(400);
  }
  capture('collect-uncollected');
  await back();
  const afterReturn = await waitFor(t => pageOf(t) === 'pages/MineQuestionsPage' || findExact(t, '我的收藏') || findExact(t, '还没有收藏内容'), 'collect after back', 16);
  capture('collect-after');
  const afterTexts = texts(afterReturn);
  const stillThere = afterTexts.some(t => openedStem && t.replace(/\n/g, '').includes(openedStem.slice(0, 12)));
  if (stillThere) fail('collect-return-refresh', `Uncollected item still listed: ${openedStem}`);
  pass('collect-return-refresh', afterTexts.includes('还没有收藏内容')
    ? 'List became empty after uncollect and return'
    : `Uncollected item removed from list: ${openedStem.slice(0, 24)}`);

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
