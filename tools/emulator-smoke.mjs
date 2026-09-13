import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

export function flattenLayout(tree) {
  return [tree.attributes || {}, ...(tree.children || []).flatMap(flattenLayout)];
}

export function isLocked(tree) {
  return flattenLayout(tree).some(node => node.id === 'sl_clock');
}

export function unlockGesture(tree) {
  const bounds = (tree.attributes?.bounds || '').match(/-?\d+/g)?.map(Number) || [];
  if (bounds.length !== 4 || bounds[2] <= bounds[0] || bounds[3] <= bounds[1]) {
    throw new Error('Cannot determine emulator screen bounds; please unlock manually');
  }
  const [left, top, right, bottom] = bounds;
  const x = String(Math.round((left + right) / 2));
  return [x, String(Math.round(top + (bottom - top) * 0.9)), x, String(Math.round(top + (bottom - top) * 0.25))];
}

export function visibleAppPage(tree, bundle, parentVisible = true) {
  const node = tree.attributes || {};
  const visible = parentVisible && node.visible !== 'false' &&
    (node.opacity === undefined || node.opacity === '' || Number(node.opacity) > 0);
  if (!visible) return undefined;
  const bounds = (node.bounds || '').match(/-?\d+/g)?.map(Number) || [];
  if (node.bundleName === bundle && node.pagePath && bounds.length === 4 &&
      bounds[2] > bounds[0] && bounds[3] > bounds[1]) return node.pagePath;
  for (const child of tree.children || []) {
    const page = visibleAppPage(child, bundle, visible);
    if (page) return page;
  }
  return undefined;
}

export function relevantFaults(names, bundle) {
  return names.filter(name => /^[A-Za-z0-9_.-]+\.log$/.test(name) && (
    name.startsWith(`appfreeze-${bundle}-`) || name.startsWith(`jscrash-${bundle}-`) ||
    name.startsWith('sysfreeze-render_service-') || name.startsWith('appfreeze-com.ohos.sceneboard-')
  ));
}

export function assertNoNewFaults(before, after) {
  const baseline = new Set(before);
  const added = after.filter(name => !baseline.has(name));
  if (added.length) throw new Error(`New freeze/crash reports: ${added.join(', ')}`);
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

export async function checkStartup({ device = '127.0.0.1:5555', bundle = 'com.mine.myapplication',
  ability = 'EntryAbility', repeat = 3, observeMs = 12000, hap, outputDir = 'branch-verification/startup' } = {}) {
  if (!/^[A-Za-z0-9_.:-]+$/.test(device) || !/^[A-Za-z0-9_.]+$/.test(bundle) || !/^[A-Za-z0-9_.]+$/.test(ability)) {
    throw new Error('Invalid device, bundle or ability identifier');
  }
  if (!Number.isInteger(repeat) || repeat < 1 || repeat > 10 || !Number.isInteger(observeMs) || observeMs < 8000 || observeMs > 60000) {
    throw new Error('repeat must be 1..10; observeMs must be 8000..60000');
  }
  const hdc = process.env.HDC_PATH || path.join(process.env.DEVECO_HOME || 'C:/Huawei/DevEco Studio',
    'sdk/default/openharmony/toolchains/hdc.exe');
  const remotePrefix = `/data/local/tmp/thfz-startup-${process.pid}-${Date.now()}`;
  const remoteLayout = `${remotePrefix}.json`;
  const remoteCapture = `${remotePrefix}.png`;
  const run = (args, timeout = 10000) => {
    const result = execFileSync(hdc, ['-t', device, ...args], { encoding: 'utf8', timeout, windowsHide: true, maxBuffer: 4 * 1024 * 1024 });
    if (/^\[Fail\]/m.test(result)) throw new Error(`HDC failed: ${args.slice(0, 3).join(' ')}`);
    return result.trim();
  };
  const getLayout = () => {
    const output = run(['shell', 'uitest', 'dumpLayout', '-p', remoteLayout]);
    if (!output.includes('DumpLayout saved')) throw new Error('UI layout probe failed');
    try { return JSON.parse(run(['shell', 'cat', remoteLayout])); }
    catch (_) { throw new Error('Cannot parse UI layout probe'); }
  };
  const getFaults = () => {
    const output = run(['shell', 'ls', '-1', '/data/log/faultlog/faultlogger']);
    const names = output.split(/\r?\n/).filter(Boolean);
    if (names.some(name => !/^[A-Za-z0-9_.-]+$/.test(name))) throw new Error('Cannot enumerate diagnostic reports');
    return relevantFaults(names, bundle);
  };
  const renderPid = () => {
    const pid = run(['shell', 'pidof', 'render_service']);
    if (!/^\d+$/.test(pid)) throw new Error('RenderService is not ready');
    return pid;
  };
  const prepareScreen = async () => {
    const powerBefore = run(['shell', 'hidumper', '-s', 'PowerManagerService', '-a', '-s'])
      .match(/Current State:\s+(\w+)/)?.[1] || 'UNKNOWN';
    run(['shell', 'power-shell', 'wakeup']);
    run(['shell', 'power-shell', 'timeout', '-o', '600000']);
    let tree = getLayout();
    const lockedBefore = isLocked(tree);
    if (lockedBefore) {
      // Only dismiss the ordinary emulator lock screen. Never enter a PIN/password.
      run(['shell', 'uitest', 'uiInput', 'swipe', ...unlockGesture(tree), '900']);
      await delay(400);
      tree = getLayout();
      const launcher = flattenLayout(tree).some(node => (node.id || '').startsWith('AppNameLite_text_'));
      if (isLocked(tree) || (!launcher && !visibleAppPage(tree, bundle))) {
        throw new Error('Please manually unlock the emulator and return to its home screen');
      }
    }
    const state = run(['shell', 'hidumper', '-s', 'PowerManagerService', '-a', '-s']);
    if (!/Current State: AWAKE/.test(state)) throw new Error('Emulator screen is not awake');
    return { powerBefore, ordinaryLockDismissed: lockedBefore };
  };
  const renderProbe = () => {
    // screenCap needs a working render path; do not start the app against a stuck RS.
    const output = run(['shell', 'uitest', 'screenCap', '-p', remoteCapture], 5000);
    if (!output.includes('ScreenCap saved')) throw new Error('RenderService capture probe failed');
  };
  const packageInfo = hap ? { path: path.resolve(hap), sha256: createHash('sha256').update(fs.readFileSync(hap)).digest('hex') } : undefined;
  const report = { device, bundle, ability, hap: packageInfo, startedAt: new Date().toISOString(), runs: [], status: 'running' };
  fs.mkdirSync(outputDir, { recursive: true });
  const resultPath = path.resolve(outputDir, `startup-${Date.now()}.json`);
  const save = () => fs.writeFileSync(resultPath, JSON.stringify(report, null, 2) + '\n');
  const restoreTimeout = () => {
    try { run(['shell', 'power-shell', 'timeout', '-r']); report.screenTimeoutRestored = true; }
    catch (_) { report.screenTimeoutRestored = false; }
    // Remove only this run's own temporary UI files, never diagnostic history.
    try { run(['shell', 'rm', '-f', remoteLayout, remoteCapture]); report.temporaryFilesRemoved = true; }
    catch (_) { report.temporaryFilesRemoved = false; }
  };
  const interrupted = (signal, code) => {
    report.status = 'interrupted';
    report.error = signal;
    restoreTimeout();
    report.finishedAt = new Date().toISOString();
    save();
    process.exit(code);
  };
  const onInterrupt = () => interrupted('SIGINT', 130);
  const onTerminate = () => interrupted('SIGTERM', 143);
  process.once('SIGINT', onInterrupt);
  process.once('SIGTERM', onTerminate);
  save();
  try {
    for (let attempt = 1; attempt <= repeat; attempt++) {
      const faultsBefore = getFaults();
      const preparation = await prepareScreen();
      run(['shell', 'aa', 'force-stop', bundle]);
      for (let poll = 0; poll < 20 && run(['shell', 'pidof', bundle]); poll++) await delay(150);
      if (run(['shell', 'pidof', bundle])) throw new Error('Previous app process did not stop');
      renderProbe();
      if (hap && attempt === 1) {
        const output = run(['install', '-r', path.resolve(hap)], 60000);
        if (!output.includes('install bundle successfully')) throw new Error('HAP install failed');
        renderProbe();
      }
      const rs = renderPid();
      assertNoNewFaults(faultsBefore, getFaults());
      const start = Date.now();
      const accepted = run(['shell', 'aa', 'start', '-b', bundle, '-a', ability]);
      if (!accepted.includes('start ability successfully')) throw new Error('Ability start was rejected');
      let page;
      const deadline = start + 25000;
      while (Date.now() < deadline) {
        assertNoNewFaults(faultsBefore, getFaults());
        if (renderPid() !== rs) throw new Error('RenderService restarted during application startup');
        const tree = getLayout();
        if (!isLocked(tree)) page = visibleAppPage(tree, bundle);
        if (page) break;
        await delay(250);
      }
      if (!page) throw new Error('No visible app page within startup deadline');
      const detectionMs = Date.now() - start;
      await delay(observeMs);
      assertNoNewFaults(faultsBefore, getFaults());
      if (renderPid() !== rs) throw new Error('RenderService restarted during observation');
      const tree = getLayout();
      if (isLocked(tree) || !visibleAppPage(tree, bundle)) throw new Error('App did not remain visible after startup');
      const pid = run(['shell', 'pidof', bundle]);
      if (!/^\d+$/.test(pid)) throw new Error('App process exited after startup');
      const lifecycle = run(['shell', 'hilog', '-x', '-P', pid, '-T', 'EntryAbility'])
        .split(/\r?\n/).filter(line => /Ability onCreate|Ability onWindowStageCreate|Succeeded in loading content/.test(line));
      report.runs.push({ attempt, preparation, pid, renderServicePid: rs, page, detectionMs, observeMs, newFaults: [], lifecycle });
      save();
      console.log(`PASS startup ${attempt}/${repeat}: ${page}; PID=${pid}; layout detected in ${detectionMs}ms (includes probe overhead); no new app/RS freeze`);
    }
    report.status = 'passed';
  } catch (error) {
    report.status = 'failed';
    report.error = error.message;
    throw error;
  } finally {
    process.removeListener('SIGINT', onInterrupt);
    process.removeListener('SIGTERM', onTerminate);
    restoreTimeout();
    report.finishedAt = new Date().toISOString();
    save();
    console.log(`Startup report: ${resultPath}`);
  }
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const options = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    const option = process.argv[i], value = process.argv[i + 1];
    if (!value) throw new Error(`Missing value for ${option}`);
    if (option === '--device') options.device = value;
    else if (option === '--bundle') options.bundle = value;
    else if (option === '--ability') options.ability = value;
    else if (option === '--repeat') options.repeat = Number(value);
    else if (option === '--observe-ms') options.observeMs = Number(value);
    else if (option === '--hap') options.hap = value;
    else if (option === '--output-dir') options.outputDir = value;
    else throw new Error(`Unknown option: ${option}`);
  }
  try { await checkStartup(options); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
