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
