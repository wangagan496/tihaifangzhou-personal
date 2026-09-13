# 题海方舟功能分支

当前个人仓库已按本地分支结构重建，但 Git 历史已重写为各分支的源码快照，不包含原始协作提交。

## 分支用途

`full` 保存拆分时的完整应用（包含拆分前未提交的设置页、首页横幅和启动配置修改）。`main` 是可编译启动的框架。功能分支均从框架提交创建，保留功能入口及其实际需要的源码、路由、测试；不是仅修改名称或隐藏完整应用的 Tab。

| 分支 | 学习内容 | 启动入口 |
| --- | --- | --- |
| main | Ability、Context、安全区、主题、基础组件与鉴权纯函数 | 框架首页 |
| full | 完整应用，对照与集成维护 | 原有四个 Tab |
| login | 登录、持久化、鉴权、失效处理、回跳 | 登录 / 受保护的账号设置 |
| questions | 分类、筛选、分页、详情、上下题 | 题库列表 |
| search | 搜索输入、推荐词、历史、结果与详情 | 搜索入口 |
| project | 项目分类、筛选、分页与详情 | 项目视图 |
| interview | 面经搜索、排序、列表与详情 | 面经视图 |
| records | 历史、收藏、点赞及产生记录的阅读入口 | 记录入口 + 题库列表 |
| study | 阅读计时、离线队列、学习时长、打卡 | 统计 / 打卡入口 + 题库列表 |
| mine | 资料、设置、主题、反馈、关于与推荐分享 | 个人中心（移除学习统计、单词、录音和打卡入口） |
| word | 单词浏览与发音 | 单词入口 |
| audio | 权限、录音、播放、文件与数据库 | 面试录音入口 |

## 依赖边界

- 框架只保留无业务页面依赖的基础能力。现有 `request -> Auth -> StudyTimeStore` 有真实依赖，因此网络与完整会话实现随需要它们的功能分支保留，没有为拆分强行重写契约。
- 题库、搜索、项目和面经共享现有列表、筛选和详情；详情同时维护记录与阅读时长，所以相关存储和追踪实现会作为依赖出现。这些文件不代表该分支包含完整的记录/统计页面。
- 业务分支保留登录与协议页面。需登录的入口仍经过真实鉴权，不使用假登录或假接口。
- `records`、`study` 带题库入口，方便产生真实记录。`mine` 不再通过菜单拉入录音、单词或整个题库。
- 保留公共资源与 ohpm 锁文件，避免重复维护资源和变更第三方版本；未做资源体积优化。非录音功能分支移除麦克风权限声明。
- 每个分支的 `feature.json` 列出实际源码、页面和测试。脚本同时检查相对导入和静态路由引用是否闭合。
- 必需入口另由 `tools/feature-required-pages.json` 独立约束；模板字符串相关扫描回归使用 `node --test tools/feature-lib.test.mjs`，避免生成器与验证器共用缺陷而一起漏页。
- 当前面经接口不执行所传排序。客户端完整取回目录后，按最新时间、点赞数或浏览数排序，再每 10 条分页；搜索也针对完整目录。目录在当前列表实例内缓存，下拉刷新重新获取；完整数据获取失败时显示错误，不冒充全局排序。后续数据规模显著增长时应改用真正支持排序和搜索的服务端分页接口。
- 分支使用相同包名、后端与本机配置；切换分支不隔离账号、服务器数据或设备沙箱。测试时不要把不同分支当作独立测试账号。

## 学习与维护

建议顺序：`main -> login -> questions -> search -> project / interview -> records -> study`，然后学习 `mine`、`word`、`audio`。

先读参考实现，再在需要练习时创建自己的重写分支。每次沿“页面 -> 状态 -> 请求或存储 -> 结果 -> 异常处理”完成一条链路。完整应用的集成修复优先落在 `full`，按需同步学习分支；不要直接把删除了其他功能的学习分支合并回完整版。

个人仓库已按同样分支结构重建；各分支为源码快照，不保留原始协作提交。

## 本机配置与构建

1. 首次克隆复制 `build-profile.example.json5` 为 `build-profile.json5`，在 DevEco Studio 配置自己的本地签名；安装工程需要的 SDK 与 ohpm 依赖。
2. `build-profile.json5` 与证书材料不入库。保持各分支使用同一份本机配置。
3. 可选创建 `entry/demo-login.local.json`，包含字符串字段 `DEMO_USERNAME`、`DEMO_PASSWORD`。此文件被 Git 忽略，仅 Debug 构建注入；仓库默认值与 Release 值均为空。Debug 安装包会包含本机演示信息，不应公开分发。
4. 使用 DevEco Studio Build，或在已配置工具链的终端执行：

```powershell
hvigorw assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon --no-incremental
hvigorw test --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon --no-incremental
node tools/check-feature.mjs
```

`tools/materialize-feature.mjs <分支名> --source-ref <完整版本提交>` 是本次拆分用的可复核工具；它只允许在名称匹配且干净的分支上运行，会按完整版本的依赖图裁剪受 Git 管理的源码，不会创建、提交或推送分支。不要对已独立重写的功能分支重新执行。需要 DevEco 附带的 TypeScript / JSON5（默认 Windows 安装路径，或通过 `DEVECO_HOME` 指定）。

构建通过只证明编译与打包；单元测试不等于真机、后端或发布验收。每个分支仍需在自己的设备上验证页面、登录和主要操作。

## 模拟器启动与原生冻屏检查

遇到 `THREAD_BLOCK_6S` 时先核对堆栈及同时间系统日志；若主线程等待 `CreateNodeAndSurface`，并且 RenderService 更早报告 `SERVICE_BLOCK`，不能按业务计算耗时随意修改 ArkTS，也不要禁用看门狗或把旧故障记录删掉当作修复。

可在项目根目录执行以下有限次数的冷启动检查：

```powershell
node tools/emulator-smoke.mjs --device 127.0.0.1:5555 --repeat 3
```

脚本先亮屏、确认普通锁屏已解除、等待旧进程退出并探测渲染服务，再启动应用。只有可见应用页面出现、观察期内没有新增本应用/RenderService 冻屏或崩溃报告，且渲染进程未重启，才算通过。历史故障记录保留，不会混入本轮失败。测试期间临时延长熄屏时间，结束时恢复；密码锁需要手动解锁，不会自动输入密码。

默认检查当前已安装版本，不会自动构建或按 Git 分支切换安装包。`--hap <签名HAP路径>` 可在就绪检查后覆盖安装指定包（保留数据），报告同时记录包路径和 SHA256。`--output-dir <目录>` 指定诊断结果位置，默认在已被 Git 忽略的 `branch-verification/startup`。检测耗时包含 UI 采样开销，不是精确启动性能指标。本工具用于启动复验和识别系统故障，不会修补模拟器底层 RenderService；系统服务持续阻塞时应先保留日志，再冷启动模拟器并复查。
