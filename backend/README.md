# 题海方舟 AI 评分后端

TypeScript + Fastify，Node.js 24 LTS。独立、无状态的文字评分服务，不替换现有题库、账号或录音数据库。

## 技术选择

TypeScript 与客户端 ArkTS 的语法、异步思路接近，便于一个人维护两端；服务端可以使用完整的 Node.js 生态。Fastify 提供 JSON Schema 输入校验和注入测试。当前主要等待模型 HTTP 请求，不涉及训练和复杂音频推理，暂不需要引入 Python。以后重点做本地模型/音频流水线，可增加独立 Python 服务；如果主要目标是 Java 后端求职，再考虑 Spring Boot。

官方依据：[Node.js 发布状态](https://nodejs.org/en/about/previous-releases)、[Fastify TypeScript](https://fastify.dev/docs/latest/Reference/TypeScript/)、[输入校验](https://fastify.dev/docs/latest/Reference/Validation-and-Serialization/)、[测试](https://fastify.dev/docs/latest/Guides/Testing/)。

## 本机启动

PowerShell，使用 Node.js 24，不改动 DevEco/Hvigor 使用的 Node.js：

```powershell
Set-Location D:\tihaifangzhou-personal\backend
npm.cmd ci
if (!(Test-Path .env)) { Copy-Item .env.example .env }
npm.cmd run check
npm.cmd run dev
```

没有模型配置也能启动，默认只监听 `127.0.0.1:3000`。检查：

```powershell
Invoke-RestMethod http://127.0.0.1:3000/healthz
```

预期 `status=ok`、`scoringReady=false`；`GET /readyz` 返回 503。代表进程正常但不能实际评分，不会生成模拟结果。编译运行：`npm.cmd run build` 后 `npm.cmd start`。

## 配置真实模型

### 当前选定的学生预算方案：千问 Flash

`.env.example` 已预设 `LLM_PROVIDER=qwen`、`LLM_MODEL=qwen3.7-flash` 和北京地域接口。首次复制后只需在本机填入 `LLM_API_KEY`（百炼通用 API Key）和 `API_ACCESS_TOKEN`（本服务独立访问码）。文件里没有任何真实密钥，也不会在启动时调用模型。

千问适配会在 HTTP JSON 顶层明确发送 `enable_thinking: false`，不使用 SDK 的 `extra_body` 包装。采用 `json_schema` 严格输出，默认 `max_completion_tokens=1280`；提示词要求短总结和各最多三条亮点/建议。通用适配模式仍保持原行为，不向其他厂商发送千问专属参数。

官方当前推荐业务空间专属域名；模板采用文档确认仍可使用的北京公共域名 `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`。也可把 `LLM_API_URL` 替换成控制台提供的北京业务空间完整地址。不要使用其他地域的 Key 配北京接口。[百炼兼容接口文档](https://help.aliyun.com/zh/model-studio/qwen-api-via-openai-chat-completions)、[千问 JSON Schema 支持](https://help.aliyun.com/zh/model-studio/qwen-structured-output)

**调用前先在百炼控制台为当前模型开启“免费额度用完即停”，等待设置生效。** 这属于云平台账号设置，本项目不会替你开启，也不能证明你的账号还有免费额度。关闭思考、限制输出、每分钟限流只能减少消耗，不是免费保证或月度费用硬上限。免费额度到期/耗尽且未开启保护时，可能转为按量付费。[官方免费额度规则](https://help.aliyun.com/zh/model-studio/new-free-quota)

缺少任一访问凭据时 `/healthz` 为 200 且 `scoringReady=false`，`/readyz` 和评分接口返回 503。配置齐全只代表就绪检查通过，不代表真实模型质量、网络、额度已经验收。第一次真实调用请仅提交一道不含个人信息的测试题。

编辑 `.env`（已被 Git 忽略）：

| 配置 | 含义 |
| --- | --- |
| `API_ACCESS_TOKEN` | 自己评分服务的访问码，32–256 位字母/数字/下划线/连字符；不是模型密钥 |
| `LLM_PROVIDER` | `qwen` 使用千问非思考适配；`openai-compatible` 保留通用协议行为 |
| `LLM_API_URL` | 提供方的完整 Chat Completions URL，不是仅域名；远端必须 HTTPS |
| `LLM_API_KEY` | 模型提供方密钥，只放后端，绝不能填到客户端 |
| `LLM_MODEL` | 千问预设 `qwen3.7-flash`；可以显式选择该提供方支持的模型，不自动升级或切换模型 |
| `LLM_JSON_MODE` | 默认 `json_schema`；不支持严格结构化输出时显式选 `json_object` |
| `LLM_TOKEN_FIELD` | 默认 `max_completion_tokens`；兼容旧提供方可显式选 `max_tokens` |

在自己的终端生成访问码后自行写入 `.env`，不要提交或分享：

```powershell
node -e "process.stdout.write(require('node:crypto').randomBytes(32).toString('hex'))"
```

模型适配参考 [OpenAI Docs：结构化输出](https://developers.openai.com/api/docs/guides/structured-outputs)。使用 Chat Completions 是为提供方兼容，不代表所有模型支持相同参数。选择提供方后仍需实调验收。实现和测试没有调用付费模型。

## 鸿蒙客户端连接

`entry/build-profile.json5` 对应构建模式的 `arkOptions.buildProfileFields`：

```json
{
  "AI_SCORING_URL": "https://你的评分服务域名/v1/scores",
  "AI_SCORING_ALLOW_LOCAL": false
}
```

以上是示意地址，不是实际部署。默认 URL 仍为空。模拟器本地调试可将 **Debug** URL 设置为 `http://127.0.0.1:3000/v1/scores`，同时把 `AI_SCORING_ALLOW_LOCAL` 设为 `true`，通过 HDC 反向端口映射连接宿主机：

```powershell
& 'C:\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' -t 127.0.0.1:5555 rport tcp:3000 tcp:3000
```

首次进入「我的 → 设置 → 评分服务配置」输入独立服务访问码并保存。客户端使用鸿蒙 Asset Store 的 SECRET 加密存储，按当前账号与服务地址隔离，仅设备解锁时读取，不同步到云端、不写入 Preferences/RDB/BuildProfile。评分页自动读取，不再显示访问码输入框；设置页支持更新和清除，且不回显已保存的值。保存成功只表示本机配置已存储，不代表远端认证已验证。课堂 token 不会发送到评分后端。HTTP 例外只接受 `127.0.0.1`，拒绝局域网明文地址；Release 使用 HTTPS、`AI_SCORING_ALLOW_LOCAL=false`。

## 接口

- `GET /healthz`：进程健康、配置是否齐全。
- `GET /readyz`：配置齐全为 200，否则 503；不探测真实模型连通性/额度。
- `POST /v1/scores`：`Authorization: Bearer <独立服务访问码>`。

```json
{
  "question": "如何避免旧请求覆盖新页面？",
  "answer": "为请求分配序号，只接受最新响应。",
  "referenceAnswer": ""
}
```

成功沿用客户端契约 `{code:10000, success:true, message, data:{score,summary,strengths,improvements}}`。失败为 `{code, success:false, data:null, message}`，HTTP 状态：400 输入错误、401 访问码错误、403 浏览器跨站调用、413 请求体过大、429 限流/并发已满、502 模型错误/结构无效、503 配置缺失/关闭中、504 超时。

## 边界

- 题目最多 2000、回答/参考答案各 20000 个 UTF-16 单元，与 ArkTS 一致。拒绝额外字段、类型转换、纯空白回答及超大请求体。
- 严格校验模型结果：0–100 有限分数；拒绝缺字段、越界、错误数组、拒答、截断和非法 JSON，不自动修补评分。
- 默认每 IP 每分钟 10 次请求、最多 2 个评分并发、45 秒超时。客户端断开和服务关闭向模型传播取消；不自动重试计费请求。
- 模型 URL 只从后端配置读取，不接受用户输入。禁止重定向、URL 内嵌凭据和查询参数；模型响应最多读取 256 KiB。
- 评分准则由服务端固定，用户文字作为单独 JSON 消息。提示词隔离降低提示注入风险，不能保证模型不受诱导。不提供工具、命令执行或链接访问能力。
- 不保存录音、答案和评分，不打印请求体、访问码、模型密钥或原始错误。提供方的数据保留规则需按实际模型确认。
- **当前共享访问码适用于个人/受控演示，不是多用户账号体系。** 公网正式服务仍需 TLS、独立用户认证/授权和用户配额；多实例需共享限流存储。内存限流重启会重置，默认不信任 `X-Forwarded-For`。

## 调用链与测试

```text
server.ts 启动/关闭 → config.ts 配置校验 → app.ts 认证/输入/限流/并发/取消
→ model-provider.ts 模型 HTTP → score-contract.ts 结果校验
→ 鸿蒙 AiScoring.ets → AiScorePage.ets
```

`npm.cmd run check` 执行严格类型检查、23 项测试和生产代码编译。测试包含实际本机 HTTP 模拟上游、客户端断开、超时、并发、限流、错误脱敏、拒绝重定向、上游传输中断，以及千问预设、顶层关闭思考、输出限制、缺密钥阻断。测试结果不代表真实评分质量，也不会访问真实模型服务。

`test/native-fixture-server.ts` 与设备 `BackendIntegrationRunner` 用于回环 HTTP 联调，返回值明确标为“测试夹具”，不编译进 `dist`，正式入口不加载它。不要拿测试夹具冒充产品 AI 评分。
