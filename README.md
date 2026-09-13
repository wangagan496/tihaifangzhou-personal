# 题海方舟 · 题海方舟 · 基础框架

当前仓库由源码快照重新初始化，不包含早期协作阶段的 Git 提交历史。原始协作仓库为 [wangagan496/tihaifangzhou](https://github.com/wangagan496/tihaifangzhou)。


当前分支：`当前仓库由源码快照重新初始化，不包含早期协作阶段的 Git 提交历史。原始协作仓库为 [wangagan496/tihaifangzhou](https://github.com/wangagan496/tihaifangzhou)。

main`。这里只包含可运行的基础框架，不包含业务页面。

完整应用在 `full`，分支职责、依赖边界、构建命令和学习顺序见 [分支说明](docs/BRANCHES.md)。

## 阅读入口

- 启动：`entry/src/main/ets/entryability/EntryAbility.ets`
- 功能入口：`entry/src/main/ets/pages/Index.ets`
- 页面注册：`entry/src/main/resources/base/profile/main_pages.json`
- 实际源码、路由、测试清单：[feature.json](feature.json)

## 当前页面

- `pages/Index`

## 验证

运行 `node tools/check-feature.mjs` 检查导入与路由，再通过 DevEco / Hvigor 构建和测试。本机配置与演示信息不入库。功能分支保留公共资源，不隔离服务器数据或设备沙箱；请使用自己的测试账号。
