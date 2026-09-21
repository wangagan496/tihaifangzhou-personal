# 首页分类非数组响应崩溃修复

## 根因

2026-09-21 20:29:14 的日志对应完成进度设备测试首次运行。测试夹具错误地向 `/hm/question/type` 返回题目详情对象。`HomeCategoryComp` 将响应直接写入 `questionTypeList`，ArkUI 的 `ForEach` 收到非数组后抛出 `TypeError: undefined is not callable`。请求泛型只提供编译期类型信息，没有执行运行时 JSON 校验。

测试夹具已按接口返回正确结构；生产首页同时新增 `parseQuestionCategories` 校验，阻止相同错误数据进入渲染状态。校验覆盖数组结构、分类的数字 ID、非空名称和重复 ID。合法空数组显示空状态，非法响应或请求失败显示重新加载入口。重试和离页使用请求序号防止旧回调覆盖当前状态。

## 验证

- 修复前运行 `CategoryResponseRunner`，注入分类非数组响应，得到 `App died`；新崩溃日志仍定位到 `HomeCategoryComp.ets:81` 的 `ForEach`，与用户贴出的日志一致。
- 修复后同一 API 24 模拟器返回 `MALFORMED_CATEGORY_NO_CRASH=PASS`、`CATEGORY_RETRY_RECOVERS=PASS` 和 `TestFinished-ResultCode: 0`。实际点击重试后正常渲染分类，失败与恢复截图已检查。
- 本地单元测试 78 项通过，失败和错误均为 0；新增 3 项分类数据校验测试。
- `entry@default` Debug HAP、`entry@ohosTest` HAP 分别构建及签名通过；源码/路由引用检查通过（130 个源码与测试文件、20 个路由页面）。

构建和设备命令应分开执行，避免将本地单元测试与 ohosTest 的编译中间目录混用：

```text
hvigorw test --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
hvigorw assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
hvigorw assembleHap --mode module -p module=entry@ohosTest -p product=default -p buildMode=debug --no-daemon
hdc -t <device> shell aa test -b com.mine.myapplication -m entry_test -s unittest CategoryResponseRunner -s timeout 60000
```

两个安装包均安装到模拟器后再运行最后一条。测试使用合成接口响应，不依赖真实后端；不代表真实后端所有返回结构或实体机均已验证。日志与截图位于本机忽略目录 `branch-verification/category-response/`，不提交生成物。
