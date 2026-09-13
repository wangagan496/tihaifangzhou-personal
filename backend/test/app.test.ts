import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { ScoreProvider } from '../src/model-provider.js';
import { ServiceError } from '../src/errors.js';
import type { ScoreResult } from '../src/score-contract.js';

const token = 'test-only-service-code-not-for-production';
const config = () => loadConfig({ API_ACCESS_TOKEN: token, LLM_API_URL: 'http://127.0.0.1:9999/v1/chat/completions', LLM_MODEL: 'test-only' });
const input = { question: '如何防止旧响应覆盖新页面？', answer: '使用请求序号，并在离页时取消。', referenceAnswer: '' };
const score: ScoreResult = { score: 0, summary: '测试夹具，不是真实 AI 评分', strengths: [], improvements: ['补充说明'] };
const headers = { authorization: `Bearer ${token}` };
const provider: ScoreProvider = { score: async () => score };

test('unconfigured server starts but never calls a provider', async t => {
  let called = false;
  const app = await buildApp(loadConfig({}), { score: async () => { called = true; return score; } });
  t.after(() => app.close());
  assert.deepEqual((await app.inject('/healthz')).json(), { status: 'ok', scoringReady: false });
  assert.equal((await app.inject('/readyz')).statusCode, 503);
  const res = await app.inject({ method: 'POST', url: '/v1/scores', payload: input });
  assert.equal(res.statusCode, 503);
  assert.equal(res.json().success, false);
  assert.equal(called, false);
});

test('qwen without a model key returns 503 and never contacts the upstream', async t => {
  let calls = 0;
  const app = await buildApp(loadConfig({ LLM_PROVIDER: 'qwen', API_ACCESS_TOKEN: token }), {
    score: async () => { calls++; return score; }
  });
  t.after(() => app.close());
  assert.equal((await app.inject('/healthz')).json().scoringReady, false);
  assert.equal((await app.inject('/readyz')).statusCode, 503);
  assert.equal((await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input })).statusCode, 503);
  assert.equal(calls, 0);
});

test('requires independent access code and rejects browser origins', async t => {
  let calls = 0;
  const app = await buildApp(config(), { score: async () => { calls++; return score; } });
  t.after(() => app.close());
  for (const authorization of ['', 'Bearer classroom-token', `Basic ${token}`]) {
    assert.equal((await app.inject({ method: 'POST', url: '/v1/scores', headers: { authorization }, payload: input })).statusCode, 401);
  }
  assert.equal((await app.inject({ method: 'POST', url: '/v1/scores', headers: { ...headers, origin: 'https://untrusted.example' }, payload: input })).statusCode, 403);
  assert.equal(calls, 0);
});

test('preserves existing success envelope and accepts zero scores', async t => {
  const app = await buildApp(config(), provider);
  t.after(() => app.close());
  const response = await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json().code, 10000);
  assert.equal(response.json().success, true);
  assert.deepEqual(response.json().data, score);
});

test('rejects wrong types, whitespace, extra fields and excessive length without coercion', async t => {
  const app = await buildApp({ ...config(), rateLimit: 100 }, { score: async () => { throw new Error('Provider must not be reached'); } });
  t.after(() => app.close());
  for (const payload of [
    { ...input, question: 42 }, { ...input, answer: ' \n ' }, { ...input, question: '' },
    { ...input, ownerId: 'forged-user' }, { ...input, answer: '字'.repeat(20001) },
    { ...input, question: '😀'.repeat(1001) }, { ...input, referenceAnswer: null }
  ]) {
    const response = await app.inject({ method: 'POST', url: '/v1/scores', headers, payload });
    assert.equal(response.statusCode, 400);
    assert.equal(response.json().data, null);
  }
});

test('bounds raw body size and does not expose parser errors', async t => {
  const app = await buildApp(config(), provider);
  t.after(() => app.close());
  const large = await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: { ...input, answer: 'x'.repeat(170000) } });
  assert.equal(large.statusCode, 413);
  const invalid = await app.inject({ method: 'POST', url: '/v1/scores', headers: { ...headers, 'content-type': 'application/json' }, payload: '{private-user-input' });
  assert.equal(invalid.statusCode, 400);
  assert.equal(invalid.body.includes('private-user-input'), false);
});

test('timeouts abort upstream and release the concurrency slot', async t => {
  let calls = 0;
  let aborted = false;
  const app = await buildApp({ ...config(), timeoutMs: 100, maxConcurrent: 1 }, {
    score: async (body, signal) => {
      calls++;
      if (calls > 1) return score;
      return new Promise((resolve, reject) => signal.addEventListener('abort', () => {
        aborted = true; reject(signal.reason);
      }, { once: true }));
    }
  });
  t.after(() => app.close());
  const timedOut = await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input });
  assert.equal(timedOut.statusCode, 504);
  assert.equal(aborted, true);
  assert.equal((await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input })).statusCode, 200);
});

test('concurrent work is bounded and rejects excess work before provider invocation', async t => {
  let finish!: (result: ScoreResult) => void;
  let entered!: () => void;
  const ready = new Promise<void>(resolve => { entered = resolve; });
  const app = await buildApp({ ...config(), maxConcurrent: 1 }, { score: async () => {
    entered(); return new Promise<ScoreResult>(resolve => { finish = resolve; });
  } });
  t.after(() => app.close());
  const first = app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input }).then(res => res);
  await ready;
  const second = await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input });
  assert.equal(second.statusCode, 429);
  assert.equal(second.json().code, 42902);
  finish(score);
  assert.equal((await first).statusCode, 200);
});

test('rate limits per IP without trusting forged forwarded headers', async t => {
  const app = await buildApp({ ...config(), rateLimit: 1 }, provider);
  t.after(() => app.close());
  assert.equal((await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input })).statusCode, 200);
  const second = await app.inject({ method: 'POST', url: '/v1/scores', headers: { ...headers, 'x-forwarded-for': '203.0.113.8' }, payload: input });
  assert.equal(second.statusCode, 429);
  assert.equal(second.json().success, false);
});

test('invalid provider results and unexpected errors do not leak data', async t => {
  const app = await buildApp(config(), { score: async () => ({ ...score, score: 101 }) });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input })).statusCode, 502);
  const broken = await buildApp(config(), { score: async () => { throw new Error('secret-key private-answer'); } });
  t.after(() => broken.close());
  const res = await broken.inject({ method: 'POST', url: '/v1/scores', headers, payload: input });
  assert.equal(res.statusCode, 500);
  assert.equal(res.body.includes('secret-key'), false);
  assert.equal(res.body.includes('private-answer'), false);
});

test('disconnecting a real HTTP client aborts the provider', async t => {
  let started!: () => void;
  let aborted!: () => void;
  const ready = new Promise<void>(resolve => { started = resolve; });
  const cancelled = new Promise<void>(resolve => { aborted = resolve; });
  const app = await buildApp(config(), { score: async (body, signal) => {
    started();
    return new Promise((resolve, reject) => signal.addEventListener('abort', () => { aborted(); reject(signal.reason); }));
  } });
  t.after(() => app.close());
  const address = await app.listen({ host: '127.0.0.1', port: 0 });
  const controller = new AbortController();
  const request = fetch(`${address}/v1/scores`, { method: 'POST', headers: { ...headers, 'content-type': 'application/json' }, body: JSON.stringify(input), signal: controller.signal }).catch(() => {});
  await ready;
  controller.abort();
  await request;
  await Promise.race([cancelled, new Promise((resolve, reject) => setTimeout(() => reject(new Error('Disconnect not propagated')), 2000).unref())]);
});

test('server shutdown cancels pending scoring', async () => {
  let started!: () => void;
  const ready = new Promise<void>(resolve => { started = resolve; });
  const app = await buildApp(config(), { score: async (body, signal) => {
    started(); return new Promise((resolve, reject) => signal.addEventListener('abort', () => reject(signal.reason)));
  } });
  const request = app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input }).then(res => res);
  await ready;
  await app.close();
  assert.equal((await request).statusCode, 503);
});

test('business errors use a bounded public message', async t => {
  const app = await buildApp(config(), { score: async () => { throw new ServiceError(502, 50201, '模型暂不可用'); } });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: 'POST', url: '/v1/scores', headers, payload: input })).json().message, '模型暂不可用');
});
