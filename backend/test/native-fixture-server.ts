// Test-only upstream injection. Never imported by src/server.ts or included in dist.
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';

const app = await buildApp(loadConfig({
  HOST: '127.0.0.1', PORT: '3001', API_ACCESS_TOKEN: 'test-only-native-integration-access-code',
  LLM_API_URL: 'http://127.0.0.1:9999/unused', LLM_MODEL: 'test-fixture', RATE_LIMIT_PER_MINUTE: '100'
}), { score: async () => ({ score: 73, summary: '测试夹具：验证传输，不是真实模型评分', strengths: [], improvements: ['仅用于集成测试'] }) });

// Local-only credentials and in-memory events for the HarmonyOS client/server integration test.
const testUsername = 'tracking-test'
const testPassword = 'tracking-test-pass'
const testToken = 'local-interview-tracking-test-token'
const testUser = {
  id: 'local-interview-tracking-test-user', username: testUsername, token: testToken,
  refreshToken: '', nickName: '本地埋点测试用户', clockinNumbers: 0, shareInfo: '', totalTime: 0
}
const interviewEvents: Array<{ ownerId: string; questionNo: string; stayTime: number; exp: boolean }> = []

app.post<{ Body: { username?: string; password?: string } }>('/hm/login', async (request, reply) => {
  if (request.body?.username !== testUsername || request.body?.password !== testPassword) {
    return reply.send({ code: 40001, success: false, data: null, message: '测试账号或密码错误' })
  }
  return reply.send({ code: 10000, success: true, data: testUser, message: '本地测试登录成功' })
})

app.post<{ Body: { questionNo?: string; stayTime?: number; exp?: boolean } }>(
  '/hm/interview/tracking', async (request, reply) => {
    if (request.headers.authorization !== `Bearer ${testToken}`) {
      return reply.code(401).send({ code: 401, success: false, data: null, message: '本地测试令牌无效' })
    }
    const body = request.body
    const stayTime = body?.stayTime
    if (typeof body?.questionNo !== 'string' || typeof stayTime !== 'number' || !Number.isSafeInteger(stayTime) ||
      stayTime <= 0 || typeof body.exp !== 'boolean') {
      return reply.send({ code: 40001, success: false, data: null, message: '面经事件格式无效' })
    }
    interviewEvents.push({ ownerId: testUser.id, questionNo: body.questionNo, stayTime, exp: body.exp })
    return reply.send({ code: 10000, success: true, data: null, message: '本地测试服务已接收面经事件' })
  })

app.get('/__test/interview-tracking', async (_request, reply) => {
  return reply.send({ code: 10000, success: true, data: interviewEvents, message: '本地测试接收记录' })
})

await app.listen({ host: '127.0.0.1', port: 3001 });
console.log('NATIVE_TEST_FIXTURE_READY (test login and in-memory interview tracking; no model calls)');
process.once('SIGINT', async () => { await app.close(); process.exit(0); });
process.once('SIGTERM', async () => { await app.close(); process.exit(0); });
