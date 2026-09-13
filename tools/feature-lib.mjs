import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const deveco = process.env.DEVECO_HOME || 'C:/Huawei/DevEco Studio';
export const ts = require(path.join(deveco, 'tools/hvigor/hvigor/node_modules/typescript'));
export const json5 = require(path.join(deveco, 'tools/hvigor/hvigor-ohos-plugin/node_modules/json5'));
export const sourceRoot = 'entry/src/main/ets/';

export function validateRequiredPages(feature, pages) {
  // This contract is deliberately independent of the dependency scanner.
  const contracts = JSON.parse(fs.readFileSync(new URL('./feature-required-pages.json', import.meta.url), 'utf8'));
  if (!Object.hasOwn(contracts, feature)) throw new Error(`Unknown feature: ${feature}`);
  for (const required of ['pages/Index', ...contracts[feature]]) {
    if (!pages.includes(required)) throw new Error(`Required page missing for ${feature}: ${required}`);
  }
}

export function references(file, source) {
  const imports = ts.preProcessFile(source, true, true).importedFiles
    .map((item) => item.fileName).filter((name) => name.startsWith('.'))
    .map((name) => path.posix.normalize(path.posix.join(path.posix.dirname(file), name)));
  const routes = [];
  const templates = [];
  let braceDepth = 0;
  const scanner = ts.createScanner(ts.ScriptTarget.Latest, true, ts.LanguageVariant.Standard, source);
  for (let token = scanner.scan(); token !== ts.SyntaxKind.EndOfFileToken; token = scanner.scan()) {
    // A template's closing } must be rescanned as TemplateMiddle/TemplateTail.
    // Otherwise scan() treats its final backtick as a NEW template and swallows later code.
    if (token === ts.SyntaxKind.CloseBraceToken && templates.at(-1) === braceDepth) {
      token = scanner.reScanTemplateToken(false);
      if (token === ts.SyntaxKind.TemplateTail) templates.pop();
    } else if (token === ts.SyntaxKind.TemplateHead) {
      templates.push(braceDepth);
    } else if (token === ts.SyntaxKind.OpenBraceToken) {
      braceDepth++;
    } else if (token === ts.SyntaxKind.CloseBraceToken) {
      braceDepth--;
    }
    if ((token === ts.SyntaxKind.StringLiteral || token === ts.SyntaxKind.NoSubstitutionTemplateLiteral) &&
        /^pages\/[A-Za-z0-9_]+$/.test(scanner.getTokenValue())) {
      routes.push(scanner.getTokenValue());
    }
  }
  if (templates.length) throw new Error(`Unterminated template in ${file}`);
  return { imports, routes: [...new Set(routes)] };
}

export function resolveImport(name, available) {
  const result = [name, `${name}.ets`, `${name}.ts`, `${name}/index.ets`].find((candidate) => available.has(candidate));
  if (!result) throw new Error(`Unresolved relative import: ${name}`);
  return result;
}

export function safePath(root, relative) {
  const absolute = path.resolve(root, relative);
  if (!absolute.startsWith(path.resolve(root) + path.sep)) throw new Error(`Path outside workspace: ${relative}`);
  return absolute;
}

export function write(root, relative, content) {
  const absolute = safePath(root, relative);
  fs.mkdirSync(path.dirname(absolute), { recursive: true });
  fs.writeFileSync(absolute, content);
}
