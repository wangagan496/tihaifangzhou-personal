import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { references, resolveImport, sourceRoot, json5, safePath, write } from './feature-lib.mjs';

const git = (...args) => execFileSync('git', args, { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }).trim();
const feature = process.argv[2];
const sourceRef = process.argv[3] === '--source-ref' ? process.argv[4] : undefined;
const definitions = {
  main: { title: '题海方舟 · 基础框架', links: [] },
  login: { title: '登录与鉴权', links: [['登录', 'LoginPage', false], ['账号与退出登录', 'AccountSettingsPage']] },
  questions: { title: '题库练习', view: ['HomeCategoryComp', 'home/HomeCategoryComp', true], links: [] },
  search: { title: '题目搜索', links: [['搜索题目', 'SearchPage']] },
  project: { title: '项目题库', view: ['Project', 'project/Project'], links: [] },
  interview: { title: '面经', view: ['Interview', 'interview/Interview'], links: [] },
  records: { title: '学习记录', view: ['HomeCategoryComp', 'home/HomeCategoryComp', true], links: [
    ['历史记录', 'MineQuestionsPage', true, 'history'],
    ['我的收藏', 'MineQuestionsPage', true, 'collect'],
    ['我的点赞', 'MineQuestionsPage', true, 'like']
  ] },
  study: { title: '学习统计', view: ['HomeCategoryComp', 'home/HomeCategoryComp', true], links: [
    ['学习时长', 'StudyTimePage'], ['学习打卡', 'ClockPage']
  ] },
  mine: { title: '个人中心', view: ['Mine', 'mine/Mine'], links: [] },
  word: { title: '单词学习', links: [['开始学习单词', 'WordPage']] },
  audio: { title: '面试录音', links: [['进入录音列表', 'AudioPage']] }
};
if (!definitions[feature] || !sourceRef) throw new Error('Usage: node tools/materialize-feature.mjs <feature> --source-ref <full-commit>');
if (git('branch', '--show-current') !== feature) throw new Error('Current branch must match feature name');
if (git('status', '--porcelain')) throw new Error('Worktree must be clean before materializing a feature');
const sourceCommit = git('rev-parse', '--verify', `${sourceRef}^{commit}`);
const root = git('rev-parse', '--show-toplevel');
const sourceFiles = git('ls-tree', '-r', '--name-only', sourceCommit).split('\n');
const sourceSet = new Set(sourceFiles);
const cache = new Map();
const read = (file) => {
  if (!cache.has(file)) cache.set(file, execFileSync('git', ['show', `${sourceCommit}:${file}`], { encoding: 'utf8' }));
  return cache.get(file);
};
const overrides = new Map();
const definition = definitions[feature];
const hasAuth = feature !== 'main';
const importView = definition.view
  ? `import ${definition.view[2] ? `{ ${definition.view[0]} }` : definition.view[0]} from '../views/${definition.view[1]}'\n` : '';
const buttons = definition.links.map(([label, page, protectedRoute = true, mode]) => `
          Button('${label}')
            .height(44)
            .width('100%')
            .fontSize(16)
            .onClick(() => {
              ${protectedRoute ? 'auth.checkAuth' : 'this.getUIContext().getRouter().pushUrl'}({ url: 'pages/${page}'${mode ? `, params: { mode: '${mode}' }` : ''} })
            })`).join('\n');
const index = `import { contextManager } from '../common/utils/ContextManager'
import { windowManager } from '../common/utils/WindowManager'
${hasAuth ? "import { auth } from '../common/utils/Auth'\n" : ''}${importView}
${hasAuth ? 'auth.initUser()\n' : ''}
@Entry
@Component
struct Index {
  @StorageProp('topHeight') topHeight: number = 0
  @StorageProp('bottomHeight') bottomHeight: number = 0

  aboutToAppear(): void {
    contextManager.ctx = this.getUIContext().getHostContext()!
    contextManager.UiCtx = this.getUIContext()
    windowManager.enableFullScreen()
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Text('${definition.title}')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.black'))
          .layoutWeight(1)
${hasAuth ? `        Button('账号')
          .height(40)
          .width(72)
          .onClick(() => auth.checkAuth({ url: 'pages/AccountSettingsPage' }))
` : ''}      }
      .width('100%')
      .padding({ left: 16, right: 16 })
${buttons ? `      ${definition.view ? 'Column' : 'Scroll'}() {
        Column({ space: 8 }) {${buttons}
        }.width('100%').padding({ left: 16, right: 16 })
      }${definition.view ? '' : ".layoutWeight(1).align(Alignment.Top)"}
` : ''}${definition.view ? `      ${definition.view[0]}().layoutWeight(1)
` : ''}${feature === 'main' ? `      Column({ space: 16 }) {
        Text('框架已启动')
          .fontSize(20)
          .fontColor($r('app.color.black'))
        Text('已保留启动生命周期、主题、安全区与通用组件。切换功能分支开始学习，切换 full 查看完整应用。')
          .fontSize(16)
          .fontColor($r('app.color.common_gray_03'))
          .lineHeight(26)
      }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
      Blank()
` : ''}    }
    .padding({ top: this.topHeight + 12, bottom: this.bottomHeight + 12 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.white'))
  }
}
`;
overrides.set(`${sourceRoot}pages/Index.ets`, index);

if (feature === 'mine') {
  overrides.set(`${sourceRoot}views/mine/Mine.ets`, `import { MineProfileHeader } from './MineProfileHeader'
import { MineToolsList } from './MineToolsList'
import { ILoginDta } from '../../models/AccountModel'

@Component
export default struct Mine {
  @StorageProp('user') user: ILoginDta = {} as ILoginDta

  build() {
    Scroll() {
      Column({ space: 16 }) {
        MineProfileHeader({ user: this.user })
        MineToolsList()
      }
      .padding($r('app.float.common_gutter'))
      .width('100%')
    }.height('100%').width('100%')
    .backgroundColor($r('app.color.common_gray_bg'))
  }
}
`);
  const headerPath = `${sourceRoot}views/mine/MineProfileHeader.ets`;
  overrides.set(headerPath, read(headerPath).replace(/^import \{ TgClockIn \}[^\n]*\r?\n/m, '').replace(/^      TgClockIn\(\)\r?\n/m, ''));
  const toolsPath = `${sourceRoot}views/mine/MineToolsList.ets`;
  let toolsSource = read(toolsPath);
  for (const [method, icon] of [['openWords', 'ic_mine_notes'], ['openAudio', 'ic_mine_ai']]) {
    const methodPattern = new RegExp(`  private ${method}\\(\\): void \\{[\\s\\S]*?\\r?\\n  \\}\\r?\\n`);
    const buttonPattern = new RegExp(`      this\\.toolBuilder\\(\\{\\r?\\n        icon: \\$r\\('app\\.media\\.${icon}'\\)[^\\n]*\\r?\\n      \\}\\)\\r?\\n`);
    if (!methodPattern.test(toolsSource) || !buttonPattern.test(toolsSource)) throw new Error(`Cannot isolate mine menu: ${method}`);
    toolsSource = toolsSource.replace(methodPattern, '').replace(buttonPattern, '');
  }
  overrides.set(toolsPath, toolsSource);
}
if (definition.view && ['project', 'interview'].includes(feature)) {
  const viewPath = `${sourceRoot}views/${definition.view[1]}.ets`;
  const insetBinding = "@StorageProp('topHeight') topHeight: number = 0";
  if (!read(viewPath).includes(insetBinding)) throw new Error(`Missing inset binding in ${viewPath}`);
  // Index already applies the system inset; embedded views retain only their own spacing.
  overrides.set(viewPath, read(viewPath).replace(insetBinding, '@Prop topHeight: number = 0'));
}

const kept = new Set();
const queue = [
  `${sourceRoot}pages/Index.ets`,
  ...sourceFiles.filter((file) => file.startsWith(`${sourceRoot}entryability/`) || file.startsWith(`${sourceRoot}entrybackupability/`)),
  ...['AuthPolicy', 'Logger', 'Permission'].map((name) => `${sourceRoot}common/utils/${name}.ets`),
  ...['IvSkeleton', 'TgLoadingDialog', 'FilterButton'].map((name) => `${sourceRoot}common/components/${name}.ets`)
];
while (queue.length) {
  const file = queue.pop();
  if (kept.has(file)) continue;
  if (!sourceSet.has(file) && !overrides.has(file)) throw new Error(`Missing source ${file}`);
  kept.add(file);
  const { imports, routes } = references(file, overrides.get(file) ?? read(file));
  queue.push(...imports.map((name) => resolveImport(name, sourceSet)));
  queue.push(...routes.map((route) => `${sourceRoot}${route}.ets`));
}
const tests = [];
for (const directory of ['entry/src/test/', 'entry/src/ohosTest/ets/test/']) {
  const selected = sourceFiles.filter((file) => file.startsWith(directory) && file.endsWith('.test.ets') && !file.endsWith('/List.test.ets'))
    .filter((file) => {
      if (feature === 'main' && file.endsWith('/AuthServer.test.ets')) return false;
      return references(file, read(file)).imports.every((name) => kept.has(resolveImport(name, sourceSet)));
    });
  for (const file of selected) kept.add(file);
  const suiteNames = selected.map((file, index) => ({ file, name: `suite${index}` }));
  const aggregator = suiteNames.map(({ file, name }) => `import ${name} from './${file.split('/').at(-1).replace('.ets', '')}'`).join('\n')
    + '\n\nexport default function testsuite() {\n'
    + suiteNames.map(({ name }) => `  ${name}()`).join('\n') + '\n}\n';
  const listFile = `${directory}List.test.ets`;
  kept.add(listFile);
  overrides.set(listFile, aggregator);
  if (directory === 'entry/src/test/') tests.push(...selected);
}

// Delete only tracked source/test files, after resolving and checking every absolute target.
const managed = (file) => file.startsWith(sourceRoot) || file.startsWith('entry/src/test/') || file.startsWith('entry/src/ohosTest/ets/test/');
for (const file of git('ls-files').split('\n').filter(managed)) {
  if (!kept.has(file) && fs.existsSync(safePath(root, file))) fs.unlinkSync(safePath(root, file));
}
for (const file of kept) {
  const original = sourceSet.has(file) ? read(file) : '';
  const existing = fs.existsSync(safePath(root, file)) ? fs.readFileSync(safePath(root, file), 'utf8') : original;
  const newline = existing.includes('\r\n') ? '\r\n' : '\n';
  const content = (overrides.get(file) ?? original).replace(/\r?\n/g, newline);
  write(root, file, content);
}
const pages = [...kept].filter((file) => file.startsWith(`${sourceRoot}pages/`) && file.endsWith('.ets'))
  .map((file) => file.slice(sourceRoot.length, -4)).sort();
pages.splice(pages.indexOf('pages/Index'), 1);
pages.unshift('pages/Index');
write(root, 'entry/src/main/resources/base/profile/main_pages.json', JSON.stringify({ src: pages }, null, 2) + '\n');
const moduleFile = 'entry/src/main/module.json5';
const moduleConfig = json5.parse(read(moduleFile));
if (feature !== 'audio') moduleConfig.module.requestPermissions = moduleConfig.module.requestPermissions.filter((item) => item.name !== 'ohos.permission.MICROPHONE');
write(root, moduleFile, JSON.stringify(moduleConfig, null, 2) + '\n');
const sources = [...kept].filter((file) => file.startsWith(sourceRoot)).sort();
write(root, 'feature.json', JSON.stringify({ feature, title: definition.title, sourceCommit, sources, pages, tests }, null, 2) + '\n');
write(root, 'README.md', `# 题海方舟 · ${definition.title}\n\n当前分支：\`${feature}\`。${feature === 'main' ? '这里只包含可运行的基础框架，不包含业务页面。' : '这是可独立构建的功能参考分支，保留真实业务和必要依赖，供按功能学习及重写。'}\n\n完整应用在 \`full\`，分支职责、依赖边界、构建命令和学习顺序见 [分支说明](docs/BRANCHES.md)。\n\n## 阅读入口\n\n- 启动：\`entry/src/main/ets/entryability/EntryAbility.ets\`\n- 功能入口：\`entry/src/main/ets/pages/Index.ets\`\n- ${definition.view ? `主要视图：\`entry/src/main/ets/views/${definition.view[1]}.ets\`` : '页面注册：`entry/src/main/resources/base/profile/main_pages.json`'}\n- 实际源码、路由、测试清单：[feature.json](feature.json)\n\n## 当前页面\n\n${pages.map((page) => `- \`${page}\``).join('\n')}\n\n## 验证\n\n运行 \`node tools/check-feature.mjs\` 检查导入与路由，再通过 DevEco / Hvigor 构建和测试。本机配置与演示信息不入库。功能分支保留公共资源，不隔离服务器数据或设备沙箱；请使用自己的测试账号。\n`);
console.log(`Materialized ${feature} from ${sourceCommit}: ${sources.length} sources, ${pages.length} pages, ${tests.length} local suites`);
