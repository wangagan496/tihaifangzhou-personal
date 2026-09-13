# 题海方舟（HarmonyOS NEXT）

题海方舟是一款面向求职与技能提升场景的 HarmonyOS NEXT 学习应用。应用以题库练习为核心，提供题目筛选与详情浏览、历史记录、收藏、点赞、打卡、学习时长统计、面经、项目资料、个人资料维护、英语单词和面试录音等功能。

> 当前工程为单 `entry` 模块的 Stage 模型应用，主要面向手机设备。应用版本为 `8.3.0`，构建目标为 HarmonyOS SDK `6.0.2(22)`。

## 功能概览

| 模块 | 已实现能力 |
| --- | --- |
| 首页题库 | 题目分类、难度筛选、下拉刷新、分页加载、搜索入口和题目详情跳转 |
| 题目详情 | 富文本答案展示、上一题/下一题、点赞、收藏、分享，以及阅读时长追踪 |
| 学习打卡 | 当日打卡、连续打卡和累计打卡日历展示 |
| 项目与面经 | 项目学习内容及面经浏览入口 |
| 个人中心 | 登录状态、历史记录、我的收藏、我的点赞、学习时长、资料编辑、设置、单词学习、面试录音、推荐分享、意见反馈和关于我们 |
| 单词学习 | 单词浏览及英文发音播放 |
| 面试录音 | 麦克风录音、播放、重命名、删除；录音元数据保存在本地数据库 |
| 外观与隐私 | 浅色/深色/跟随系统主题，用户协议与隐私政策入口 |

## 技术栈

- HarmonyOS NEXT Stage 模型与 ArkTS
- ArkUI 声明式 UI、`UIAbility` 与 `Navigation` / Router
- Hvigor + ohpm 构建与依赖管理
- `@ohos/axios`：网络请求与请求/响应拦截
- `@ohmos/calendar`：打卡日历
- `dayjs`：日期处理
- `relationalStore`：录音列表本地 RDB 存储
- `preferences`：题目阅读时长离线队列、按用户隔离的历史/收藏/点赞记录和本地反馈
- `@kit.ShareKit`：调用系统文本分享面板
- `@ohos/hypium`：单元与设备测试基础设施

## 应用结构

```text
AppScope/                              # 应用级配置、图标和资源
entry/
├─ src/main/
│  ├─ ets/
│  │  ├─ entryability/                 # EntryAbility 生命周期与首页加载
│  │  ├─ pages/                        # 可路由页面
│  │  ├─ views/                        # 首页、项目、面经、个人中心等业务视图
│  │  ├─ common/components/            # 通用 UI 组件和弹窗
│  │  ├─ common/utils/                 # 网络、鉴权、主题、权限、存储等工具
│  │  └─ models/                       # 接口与领域数据模型
│  ├─ resources/                       # 字符串、颜色、图片、rawfile、路由配置
│  └─ module.json5                     # entry 模块、Ability、权限声明
├─ src/test/                           # 本地单元测试
└─ src/ohosTest/                       # 真机/模拟器测试
build-profile.json5                    # entry 模块构建与发布混淆配置
oh-package.json5                       # 模块依赖声明
build-profile.json5                    # 工程 SDK、签名和产品构建配置
```

## 页面与导航

应用启动后由 `EntryAbility` 加载 `pages/Index`。`Index` 作为底部导航容器，包含以下四个一级视图：

1. 首页：题库、分类和筛选。
2. 项目：项目学习内容。
3. 面经：面试经验内容。
4. 我的：用户信息与学习工具。

路由表定义在 [`entry/src/main/resources/base/profile/main_pages.json`](entry/src/main/resources/base/profile/main_pages.json)，主要二级页面包括登录、打卡、题目详情、搜索、资料编辑、学习时长、单词、录音、设置、隐私、历史/收藏/点赞列表、意见反馈和关于我们页面。

## 环境要求

请使用与工程目标 SDK 兼容的 DevEco Studio、HarmonyOS SDK 和 Node.js 环境。工程当前配置为：

| 项目项 | 当前值 |
| --- | --- |
| 应用模型 | Stage model |
| 语言 | ArkTS / `.ets` |
| 目标 SDK | `6.0.2(22)` |
| 兼容 SDK | `6.0.2(22)` |
| 设备类型 | `phone` |
| 包管理器 | ohpm |

推荐直接通过 DevEco Studio 打开工程根目录，确认已安装 `6.0.2(22)` 对应 SDK，再连接真机或启动模拟器运行。录音、相册保存等功能应在真机或具有相应能力的模拟器上验证。

## 快速开始

### 使用 DevEco Studio

1. 启动 DevEco Studio，选择“Open”，打开本仓库根目录。
2. 在 SDK Manager 中安装与 `build-profile.json5` 匹配的 HarmonyOS SDK。
3. 等待 IDE 使用 `oh-package.json5` 同步依赖；如未自动同步，可在终端执行 `ohpm install`。
4. 选择 `entry` 模块和目标设备，运行应用。
5. 需要生成安装包时，使用 IDE 的 Build 菜单构建 HAP；release 构建会应用 `entry/obfuscation-rules.txt` 中配置的混淆规则。

### 命令行（已安装 HarmonyOS 命令行工具时）

```bash
ohpm install
hvigorw assembleHap
```

`hvigorw` 由 DevEco Studio / HarmonyOS 命令行工具提供；若当前工作目录没有该包装脚本，请优先通过 DevEco Studio 构建，或按本机 SDK 的命令行工具说明初始化包装脚本。

## 服务端与数据说明

网络层位于 [`entry/src/main/ets/common/utils/request.ets`](entry/src/main/ets/common/utils/request.ets)，当前默认服务地址为：

```text
https://api-harmony-teach.itheima.net
```

请求会在存在登录态时自动附加 `Authorization: Bearer <token>`；服务端返回 401 时会清除本地登录态并跳转到登录页。已使用的主要接口包括：

| 业务 | 接口 |
| --- | --- |
| 登录 | `POST /hm/login` |
| 题目分类、列表与详情 | `/hm/question/type`、`/hm/question/list`、`/hm/question/{id}` |
| 题目点赞/收藏 | `/hm/question/opt`、`/hm/question/unOpt` |
| 打卡 | `/hm/clockinInfo`、`POST /hm/clockin` |
| 学习信息与时长上报 | `/hm/studyInfo`、`POST /hm/time/tracking` |
| 用户资料 | `/hm/userInfo`、`/hm/userInfo/profile`、`/hm/userInfo/avatar` |

为便于离线使用，应用还保存以下本地数据：

- 登录用户与主题偏好：`PersistentStorage` / `AppStorage`。
- 面试录音元数据：RDB 数据库 `interview_audio.db`，按用户和创建时间索引。
- 题目阅读时长：`preferences` 中的 `trackFile`；每累计 5 条记录后尝试批量上报，失败时保留待下次重试。
- 我的题目记录：`common/utils/MineQuestionStore.ets` 使用 `preferences` 的 `mineQuestions` 文件，按用户 ID 保存历史记录、收藏和点赞列表。
- 意见反馈：`pages/MineFeedbackPage.ets` 使用 `preferences` 的 `feedback` 文件保存最近一次反馈；当前没有对应的服务端反馈接口。

题目详情中的点赞和收藏仍通过服务端接口更新；“我的收藏”和“我的点赞”列表是客户端按用户隔离的本地镜像。推荐分享调用系统分享面板，不依赖项目自建分享接口。

如果要切换到自有后端，请仅修改网络层的 `baseURL`，并确保接口响应保持 `{ code, data, message, success }` 结构；当前成功业务码为 `10000`。

## 权限与隐私

模块权限声明位于 [`entry/src/main/module.json5`](entry/src/main/module.json5)。

| 权限 | 用途 | 授权方式 |
| --- | --- | --- |
| `ohos.permission.INTERNET` | 请求题库、账号和学习数据服务 | 声明权限 |
| `ohos.permission.MICROPHONE` | 面试录音 | 页面进入时运行时申请 |
| `ohos.permission.WRITE_IMAGEVIDEO` | 保存题目分享图片 | 按实际功能申请 |

请勿在源码、文档或版本库中提交真实账号、访问令牌、生产签名材料、密钥或密码。发布前应复核权限用途、隐私政策文案及签名配置。

## 测试

工程已包含两类测试目录：

- [`entry/src/test`](entry/src/test)：本地单元测试。
- [`entry/src/ohosTest/ets/test`](entry/src/ohosTest/ets/test)：在真机或模拟器中执行的设备测试。

建议在提交前至少完成：依赖同步、ArkTS 编译检查、首页/登录/题目详情回归、麦克风权限拒绝与授权流程验证，以及浅色和深色主题检查。

## 发布注意事项

- 使用 release 构建前检查 `build-profile.json5` 中的签名配置，生产环境应使用独立且受保护的发布证书。
- `entry/build-profile.json5` 已为 release 构建启用 ArkTS 混淆规则；若采用反射、动态字段、序列化字段或动态路由，请同步维护 `obfuscation-rules.txt` 白名单。
- 当前 `AppScope/app.json5` 中的包名、厂商等元数据仍应在发布前替换为实际信息。

## 许可证

本仓库尚未声明开源许可证。若计划公开发布，请补充 `LICENSE` 文件并明确第三方依赖与素材的使用许可。

## 从零学习路线

如果你是第一次接触这个项目，建议不要一开始就逐个阅读所有 `.ets` 文件，而是按照“能运行 → 看懂页面 → 看懂数据 → 独立修改”的顺序学习。

### 第一阶段：准备基础知识

开始之前，至少需要了解以下概念：

- ArkTS 基础：类型、接口、类、异步 `Promise`、模块导入导出。
- ArkUI 基础：`@Component`、`@Entry`、`build()`、`Column`、`Row`、`List`、`Tabs` 和事件回调。
- 状态管理：`@State`、`@Prop`、`@Link`、`@StorageProp`、`@StorageLink`。
- Stage 模型：`UIAbility`、窗口生命周期、页面加载和路由。
- HarmonyOS 工程：`module.json5`、资源限定目录、权限声明、ohpm 和 Hvigor。

学习时可以先阅读 [`entry/src/main/ets/pages/RichTextPage.ets`](entry/src/main/ets/pages/RichTextPage.ets)，它包含状态装饰器和 ArkUI 示例，适合作为第一个练习页面。

### 第二阶段：理解应用是如何启动的

应用启动链路如下：

```text
系统启动应用
    ↓
EntryAbility.onCreate()
    ├─ 保存 Context 到 AppStorage
    └─ 输出生命周期日志
    ↓
EntryAbility.onWindowStageCreate()
    ├─ 初始化主题
    └─ 加载 pages/Index
    ↓
Index.aboutToAppear()
    ├─ 保存 UIContext
    ├─ 初始化用户信息
    └─ 开启沉浸式窗口
    ↓
Index.build()
    └─ 渲染首页、项目、面经、我的四个底部 Tab
```

重点文件：

| 文件 | 学习重点 |
| --- | --- |
| `entry/src/main/ets/entryability/EntryAbility.ets` | UIAbility 生命周期和首页加载 |
| `entry/src/main/ets/pages/Index.ets` | `Tabs`、底部导航和子视图切换 |
| `entry/src/main/ets/common/utils/ContextManager.ets` | 在工具类中使用页面 Context / UIContext |
| `entry/src/main/ets/common/utils/WindowManager.ets` | 全屏、状态栏和安全区域处理 |
| `entry/src/main/ets/common/utils/Theme.ets` | 浅色、深色和跟随系统主题 |

建议第一次运行时，在 `EntryAbility` 和 `Index` 的生命周期函数中添加日志，然后观察启动顺序。这样比直接阅读所有界面代码更容易建立整体认识。

### 第三阶段：理解页面和组件的关系

项目采用“页面 + 业务视图 + 通用组件”的分层方式：

```text
pages/Index
├─ views/home/Home
│  ├─ HomeCategoryComp
│  ├─ QuestionFilterComp
│  ├─ QuestionListComp
│  └─ QuestionItemComp
├─ views/project/Project
├─ views/interview/Interview
└─ views/mine/Mine
   ├─ WordPage
   ├─ AudioPage
   ├─ StudyTimePage
   └─ SettingsPage
```

阅读一个页面时，按下面的顺序查看：

1. 先看 `@State`、`@StorageProp` 等状态字段，确认页面有哪些数据。
2. 再看 `aboutToAppear()`，确认页面进入时加载了什么。
3. 然后看事件函数，例如 `onClick`、`onChange`、`onRefreshing`。
4. 最后看 `build()`，把状态和 UI 的对应关系画出来。

例如 `QuestionListComp.ets` 中，题目列表由本地状态保存，进入页面后请求接口，刷新和分页事件会重新加载数据，点击题目后把题目 ID 传给 `QuestionDetailPage`。

### 第四阶段：掌握网络请求和登录鉴权

所有业务请求都通过 `tgRequest()` 封装，调用关系如下：

```text
页面或组件
    ↓
tgRequest()
    ↓
axios instance
    ↓ request interceptor
读取 auth.getUser().token
    ↓
Authorization: Bearer <token>
    ↓
服务端
    ↓ response interceptor
检查 code === 10000
    ├─ 成功：返回 res.data.data
    └─ 失败：Toast 提示
```

登录流程位于 [`entry/src/main/ets/pages/LoginPage.ets`](entry/src/main/ets/pages/LoginPage.ets)：

1. 用户输入账号和密码。
2. 勾选用户协议和隐私政策。
3. 调用 `POST /hm/login`。
4. 登录成功后通过 `auth.setUser()` 保存用户信息。
5. 使用 `replaceUrl()` 返回登录前页面，避免返回键重新进入登录页。

需要登录的功能通过 `auth.checkAuth()` 进入。未登录时，目标页面会被放入登录页参数；登录成功后再跳回原页面。

### 第五阶段：跟读一个完整业务——题目详情

题目详情是最适合学习的完整业务，因为它同时包含路由传参、网络请求、加载状态、用户操作和数据上报：

```text
QuestionListComp 点击题目
    ↓ 传入 { id }
QuestionDetailPage.aboutToAppear()
    ↓
读取路由参数 id
    ↓
显示骨架屏和加载弹窗
    ↓
GET /hm/question/{id}
    ↓
保存题目数据并开始 tracking.start(id)
    ↓
显示题干、答案和标签
    ├─ 点赞：POST /hm/question/opt
    ├─ 收藏：POST /hm/question/opt
    ├─ 分享：打开 QuestionShareDialog
    └─ 离开页面：tracking.save()
```

重点阅读：

- `QuestionDetailPage.ets`：页面状态、请求和上一题/下一题逻辑。
- `TgLoadingDialog.ets`：请求期间的加载提示。
- `IvSkeleton.ets`：骨架屏。
- `QuestionShareDialog.ets`：分享图片与保存逻辑。
- `Tracking.ets`：阅读时长的本地缓存和批量上报。

### 第六阶段：理解本地数据和权限

项目中的本地数据不是全部使用同一种存储方式：

| 场景 | 实现 | 适合学习的文件 |
| --- | --- | --- |
| 登录用户、主题 | `PersistentStorage` + `AppStorage` | `Auth.ets`、`Theme.ets` |
| 题目阅读记录 | `preferences` | `Tracking.ets` |
| 录音元数据 | `relationalStore` | `AudioDB.ets` |
| 录音文件 | 文件描述符和应用沙箱 | `AudioRecordComp.ets` |

麦克风权限需要“声明 + 运行时申请”两步：

1. 在 `entry/src/main/module.json5` 声明 `ohos.permission.MICROPHONE`。
2. 进入 `AudioPage` 时调用 `permission.requestPermissions()`。
3. 用户拒绝后，通过 `requestPermissionOnSetting()` 引导前往系统设置。
4. 授权失败时返回上一页，避免录音组件在没有权限的情况下继续工作。

### 第七阶段：调试方法

遇到问题时，先判断问题属于哪一层：

| 现象 | 优先检查位置 |
| --- | --- |
| 应用无法编译 | SDK 版本、ohpm 依赖、ArkTS 类型错误、`module.json5` |
| 页面空白 | `main_pages.json`、`loadContent`、页面 `build()` 根容器 |
| 点击后没有跳转 | 路由名称、页面是否加入 `main_pages.json`、参数结构 |
| 接口全部失败 | 网络权限、服务端地址、返回 `code`、登录 token |
| 登录后又回到登录页 | `Auth.ets` 的用户持久化、401 响应、token 是否有效 |
| 录音不可用 | 麦克风权限、真机能力、录音文件描述符和生命周期 |
| 深色模式显示异常 | `Theme.ets`、`resources/dark`、`isDark` 状态 |

日志统一使用 `hilog` 或项目的 `Logger` 工具。排查网络问题时，不要打印完整 token、密码或其他敏感信息。

### 第八阶段：建议练习任务

按照从易到难的顺序完成下面的练习，可以逐步确认是否真正理解项目：

#### 练习 1：修改静态 UI

- 修改登录页标题和副标题。
- 修改首页 Tab 文案和图标颜色。
- 在个人中心新增一个静态菜单项。

#### 练习 2：新增页面和路由

- 新建 `pages/AboutPage.ets`。
- 在 `main_pages.json` 注册页面。
- 从设置页通过 `pushUrl()` 打开它。
- 使用 `router.getParams()` 接收一个字符串参数。

#### 练习 3：增加本地状态

- 在设置页增加“是否显示答案”的开关。
- 使用 `@State` 控制题目答案区域显示或隐藏。
- 将开关值保存到 `PersistentStorage`，重启应用后仍然生效。

#### 练习 4：调用接口

- 参照 `QuestionListComp.ets` 发起一个 GET 请求。
- 定义对应的接口模型。
- 增加加载中、空数据和请求失败三种 UI 状态。

#### 练习 5：扩展录音列表

- 在 `AudioDB.ets` 增加按名称搜索。
- 在 `AudioView.ets` 增加空状态和加载状态。
- 验证切换用户后不会读取其他用户的录音。

### 学习完成标准

达到下面的标准，基本可以独立维护这个项目：

- 能解释应用从 `EntryAbility` 到首页 Tab 的启动过程。
- 能独立新增一个页面、注册路由并完成参数传递。
- 能使用 `tgRequest()` 调用接口并处理成功、空数据和失败状态。
- 能说明 `AppStorage`、`PersistentStorage`、`preferences` 和 RDB 各自的用途。
- 能正确声明和申请运行时权限。
- 能通过日志定位页面、网络、权限和存储问题。
- 能在不破坏混淆和路由的前提下完成 release 构建。

## 本地签名配置

`build-profile.json5` 仅用于本机签名，已被 Git 忽略，不能提交证书路径、口令、`.p12`、`.cer` 或 `.p7b` 材料。首次克隆后，复制 `build-profile.example.json5` 为 `build-profile.json5`，再通过 DevEco Studio 创建或选择自己的调试签名。

如果仓库历史中曾出现过签名材料或口令，请在本机重新生成签名材料；普通提交不能从既有 Git 历史中抹除已上传的值。
