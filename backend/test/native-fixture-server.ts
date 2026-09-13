// Test-only upstream injection. Never imported by src/server.ts or included in dist.
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';

const app = await buildApp(loadConfig({
  HOST: '127.0.0.1', PORT: '3001', API_ACCESS_TOKEN: 'test-only-native-integration-access-code',
  LLM_API_URL: 'http://127.0.0.1:9999/unused', LLM_MODEL: 'test-fixture', RATE_LIMIT_PER_MINUTE: '100'
}), { score: async () => ({ score: 73, summary: '测试夹具：验证传输，不是真实模型评分', strengths: [], improvements: ['仅用于集成测试'] }) });
await app.listen({ host: '127.0.0.1', port: 3001 });
console.log('NATIVE_TEST_FIXTURE_READY (no model calls)');
process.once('SIGINT', async () => { await app.close(); process.exit(0); });
process.once('SIGTERM', async () => { await app.close(); process.exit(0); });
