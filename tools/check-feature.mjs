import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { references, resolveImport, sourceRoot, json5, validateRequiredPages } from './feature-lib.mjs';

const files = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8' }).split('\0').filter(Boolean);
const tracked = new Set(files.filter((file) => fs.existsSync(file)));
// Include newly materialized files before they are staged.
function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = `${dir}/${item.name}`;
    if (item.isDirectory()) walk(file); else tracked.add(file);
  }
}
walk('entry/src');
const pages = JSON.parse(fs.readFileSync('entry/src/main/resources/base/profile/main_pages.json', 'utf8')).src;
if (new Set(pages).size !== pages.length || !pages.includes('pages/Index')) throw new Error('Invalid page registry');
for (const page of pages) if (!tracked.has(`${sourceRoot}${page}.ets`)) throw new Error(`Missing registered page ${page}`);
const sources = [...tracked].filter((file) => /\.(ets|ts)$/.test(file) && file.startsWith('entry/src/'));
for (const file of sources) {
  const { imports, routes } = references(file, fs.readFileSync(file, 'utf8'));
  for (const name of imports) resolveImport(name, tracked);
  if (file.startsWith(sourceRoot)) {
    for (const route of routes) if (!pages.includes(route)) throw new Error(`Unregistered route ${route} in ${file}`);
  }
}
const profile = json5.parse(fs.readFileSync('entry/build-profile.json5', 'utf8'));
for (const option of profile.buildOptionSet || []) {
  const fields = option.arkOptions?.buildProfileFields || {};
  for (const name of ['DEMO_USERNAME', 'DEMO_PASSWORD']) {
    if (fields[name]) throw new Error(`Nonempty tracked demo field in ${option.name}`);
  }
}
if (fs.existsSync('feature.json')) {
  const manifest = JSON.parse(fs.readFileSync('feature.json', 'utf8'));
  validateRequiredPages(manifest.feature, pages);
  const actual = sources.filter((file) => file.startsWith(sourceRoot)).sort();
  if (JSON.stringify(actual) !== JSON.stringify(manifest.sources)) throw new Error('Source set differs from feature manifest');
  if (JSON.stringify(pages) !== JSON.stringify(manifest.pages)) throw new Error('Page registry differs from feature manifest');
  const actualTests = sources.filter((file) => file.startsWith('entry/src/test/') && file.endsWith('.test.ets') && !file.endsWith('/List.test.ets')).sort();
  if (JSON.stringify(actualTests) !== JSON.stringify([...manifest.tests].sort())) throw new Error('Test set differs from feature manifest');
  const microphone = json5.parse(fs.readFileSync('entry/src/main/module.json5', 'utf8')).module.requestPermissions
    .some((permission) => permission.name === 'ohos.permission.MICROPHONE');
  if (microphone !== (manifest.feature === 'audio')) throw new Error('Unexpected microphone permission');
  console.log(`PASS ${manifest.feature}: ${actual.length} source files, ${pages.length} pages, ${manifest.tests.length} local test suites`);
} else {
  console.log(`PASS full: ${sources.length} source/test files, ${pages.length} pages; demo defaults empty`);
}
