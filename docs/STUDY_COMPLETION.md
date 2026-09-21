# 主动完成进度

普通题详情加载成功只记录浏览历史、分类归属和开始阅读计时。用户在答案下方点击“标记已完成”后，才写入本机完成记录；已完成时可取消标记。该标记是用户自我确认，不是自动判题，也不保证已经掌握知识。

## 数据规则

- 完成记录按用户和普通题 ID 去重，重复标记不增加数量；退出、重新打开仍能读取。
- `studyProgress` Preferences 原来的 `ids:<用户>:<题库>:<分类>` 仅保留题目分类归属。旧版自动阅读数据不会被当成主动完成。
- 新记录放在 `completed:v1:question:<用户>`，分类完成数是该分类题目 ID 与主动完成 ID 的交集，最多为接口返回的总题数。
- 历史仍只保留最近 50 条，淘汰历史记录不会删除已完成记录；阅读时长和上报队列保持独立。
- 从历史/收藏进入时即使没有分类参数，也能按题目 ID 查看或修改完成状态。分类汇总依赖已知归属；首次遇到缺少归属的题，在从分类入口成功加载该题后才计入对应分类。
- 面经仍采用现有的历史、时长与读到底上报规则，不参与普通题主动完成统计。
- 写入失败不更新按钮为成功状态；读取完成状态失败提供重试入口。旧历史和时长不删除，旧“看过即完成”的数字不会迁移为新完成数。

## 实现位置

- `QuestionDetailPage.ets`：成功加载时读状态、显示标记按钮、切题/账号变化时刷新状态。
- `StudyProgressStore.ets`：区分分类归属和主动完成，负责去重、取消、持久化与分类聚合。
- `StudyTimeService.ets` 与 `StudyTimePage.ets`：汇总并解释手动完成进度。
- `StudyProgressStore.test.ets`：覆盖旧记录、重复操作、撤销、账号隔离、入口缺参、历史淘汰和存储失败。

## 复述

历史记录代表看过什么，完成进度代表用户主动确认完成了哪些题。仅打开题目不会增加完成数，重复标记也不会重复累计。完成记录独立保存，所以即使历史只剩最近 50 条，累计完成的题目仍然保留。

## 验证记录

2026-09-20 使用本机 HarmonyOS API 24 工具链验证：

- `hvigorw test --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon --no-incremental`：75 项通过，失败和错误均为 0；其中本次新增 7 项完成进度测试。
- 同样参数执行 `assembleHap`：Debug HAP 构建及签名成功。
- `node tools/check-feature.mjs`：125 个源码/测试文件、20 个路由页面的引用检查通过。
- 本地用例使用可注入的存储适配器验证业务规则和失败分支，不等同于实际设备上的 Preferences 持久化验收。本次没有连接模拟器或真机，未执行按钮点击、重启恢复和设备布局验收。

本机日志：`branch-verification/study-completion/test.log` 和 `debug-build.log`。

## 官方文档核对与实习讲解

2026-09-20 在线核对华为官方文档，并检查本机 HarmonyOS SDK `6.1.1(24)` 的 Preferences 类型声明。本次范围为主动完成链路，不代表全项目所有 Kit 均已审查。

| 官方依据 | 当前实现与结论 |
| --- | --- |
| [Preferences API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-preferences)，包括 `getPreferencesSync`、`putSync`、`flushSync` | `putSync` 修改缓存，`flushSync` 将数据写入持久化文件；`flushSync` 从 API 14 支持，当前 API 24 可用。存储适配器将异常交由 Store 转成失败结果，页面只在成功后修改按钮。 |
| [@Watch：状态变量更改通知](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-watch) | 首次初始化不会触发 Watch，回调应保持轻量。详情页监听 `user` 变化，同时在题目加载完成后主动读取完成状态；回调不修改被监听的 `user`。 |
| [页面路由与生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-routing#生命周期) | 返回已有页面不会再次执行 `aboutToAppear`；`onPageShow` 在页面显示时执行。详情页在 `onPageShow` 重新读取完成状态，覆盖返回和应用回到前台的场景。 |

保留当前 V1 状态管理和“页面 → 业务 Store → Preferences 适配器”的结构。已有接口足以替换测试存储和解释业务规则，本次不额外引入框架或迁移 V2。同步存储适合当前低频、轻量的演示数据；若题量或写入频率明显增加，应先测量耗时，再考虑异步串行写入或 RDB。官方也明确 Preferences 不支持多进程并发使用，不能将当前实现描述为跨进程事务或云端同步。

面试时按下面的顺序讲解：

1. **业务问题**：打开题目只能证明看过，不能证明完成，所以增加用户主动标记。
2. **数据设计**：分类归属、浏览历史、完成记录和阅读时长分别保存；完成记录按用户和普通题 ID 去重，可以撤销。
3. **界面与异常**：切题先清空旧状态；存储读取失败显示重试，写入失败不显示成功；账号变化重新读取。
4. **测试与边界**：内存适配器验证重复标记、撤销、旧数据兼容、账号隔离与失败分支；实际 Preferences 重启恢复仍需设备验证。缓存回退只是失败保护，不应声称具备磁盘事务保证。

### 本次提交前复验

执行 `tools/verify-feature.ps1 -BuildMode debug`：13 项工具测试通过，125 个源码/测试文件与 20 个路由页面检查通过，Debug HAP 构建及签名成功，应用测试结果为 `Tests run: 75, Failure: 0, Error: 0, Pass: 75, Ignore: 0`。构建仍有 API 异常处理、权限等警告，不能表述为零警告。

本次复验日志位于 `branch-verification/full/debug-build.log`、`test.log` 和 `test_result.txt`。`hdc list targets` 返回空列表，因此本次未做设备按钮点击、重启恢复、Release 或云端同步验收。

## 2026-09-21 模拟器验收补充

已在 API 24 模拟器 `127.0.0.1:15556` 上安装个人版应用和 ohosTest 包，执行 `StudyCompletionRunner` 的 `save`、`read` 两阶段。两阶段之间执行 `aa force-stop com.mine.myapplication`，没有卸载或清空应用数据。两阶段最终结果均为 `TestFinished-ResultCode: 0`。

- 浏览详情不增加完成数，旧阅读记录不自动转换为完成记录。
- 实际点击按钮可以标记完成；同一题重复设置完成只统计一次。
- 强制结束进程后重新启动，Preferences 中的完成记录和按钮状态均恢复。
- 实际点击取消后，完成数回到 0，按钮恢复为“标记已完成”。
- 切换合成测试账号后不会显示前一个账号的完成状态；切回原测试账号恢复。
- 不带分类参数重新进入详情页，仍能读取已有完成状态。
- 检查了竖屏和横屏的标记按钮截图，按钮可见可操作；未覆盖折叠屏、大字体和完整读屏。

测试使用独立合成账号和题目响应，运行真实详情页面和原生 Preferences，未调用真实登录接口或向教学后端提交测试记录。运行前保存用户状态和阅读队列，结束后恢复，并清理该测试范围内的数据。初次调试的夹具结构、驱动初始化和截图路径问题已修正，不计入通过结果。

### 重跑方式

分别构建 `entry@default` 主应用和 `entry@ohosTest` 测试模块的 Debug HAP，确认两个安装包都已安装后，依次执行：

```text
hdc -t <device> shell aa test -b com.mine.myapplication -m entry_test -s unittest StudyCompletionRunner -s stage save -s timeout 90000
hdc -t <device> shell aa force-stop com.mine.myapplication
hdc -t <device> shell aa test -b com.mine.myapplication -m entry_test -s unittest StudyCompletionRunner -s stage read -s timeout 90000
```

`CompletionUiDriver.ets` 延迟加载 UiTest 驱动，避免在 AbilityDelegator 就绪前初始化。测试源码保留在 `entry/src/ohosTest/ets/testrunner/`，不属于可清理的临时文件。

本次验证后的构建产物、截图和日志与旧缓存一并移出项目，恢复目录及清单记录在 `D:/Backup/tihaifangzhou-personal-cleanup-20260921/`。依赖、后端数据、签名配置、源码和文档保留。设备验证补齐了上节的按钮与重启恢复缺口，但不代表真实后端联调、断电恢复或全部存储失败路径已通过。
