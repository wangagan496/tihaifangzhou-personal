import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { FileRecordsStore, MemoryRecordsStore } from '../src/records.js';
import type { QuestionRecord } from '../src/records-policy.js';

const token = 'test-only-service-code-not-for-production';
const config = () => loadConfig({
  API_ACCESS_TOKEN: token,
  LLM_API_URL: 'http://127.0.0.1:9999/v1/chat/completions',
  LLM_MODEL: 'test-only'
});
const item = (id: string, contentType: 0 | 1 = 0): QuestionRecord => ({
  id, stem: `question-${id}`, difficulty: 1, likeCount: 0, views: 0, readFlag: 0, contentType
});
const headers = (owner: string) => ({ authorization: `Bearer ${token}`, 'x-owner-id': owner });
const noopScore = { score: async () => ({ score: 0, summary: 'unused', strengths: [], improvements: ['x'] }) };
const noopFeedback = { append: async (content: string) => ({ id: 'f', content, createdAt: '2026-09-14T00:00:00.000Z' }) };

test('records isolate accounts and restore after empty local store', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'records-'));
  const file = join(dir, 'records.json');
  const first = new FileRecordsStore(file);
  await first.put('user-a', 'collect', item('1'));
  await first.put('user-a', 'like', item('2'));
  await first.put('user-a', 'history', item('3'));
  await first.put('user-b', 'collect', item('9'));
  assert.equal((await first.list('user-b', 'collect')).length, 1);
  const firstCollect = await first.list('user-a', 'collect');
  const firstCollectItem = firstCollect[0];
  assert.ok(firstCollectItem);
  assert.equal(firstCollectItem.id, '1');
  const restored = new FileRecordsStore(file);
  const collect = await restored.list('user-a', 'collect');
  assert.equal(collect.length, 1);
  const restoredCollectItem = collect[0];
  assert.ok(restoredCollectItem);
  assert.equal(restoredCollectItem.id, '1');
  const like = await restored.list('user-a', 'like');
  const likeItem = like[0];
  assert.ok(likeItem);
  assert.equal(likeItem.id, '2');
  const history = await restored.list('user-a', 'history');
  const historyItem = history[0];
  assert.ok(historyItem);
  assert.equal(historyItem.id, '3');
  assert.equal((await restored.list('user-b', 'history')).length, 0);
  const raw = JSON.parse(await readFile(file, 'utf8')) as { 'user-a': { collect: QuestionRecord[] } };
  const rawCollectItem = raw['user-a'].collect[0];
  assert.ok(rawCollectItem);
  assert.equal(rawCollectItem.stem, 'question-1');
});

test('records HTTP list put and delete stay on the owned user', async t => {
  const store = new MemoryRecordsStore();
  const app = await buildApp(config(), noopScore, noopFeedback, store);
  t.after(() => app.close());
  const put = await app.inject({
    method: 'PUT', url: '/v1/records/collect', headers: headers('alice'), payload: item('q1')
  });
  assert.equal(put.statusCode, 200);
  assert.equal(put.json().data[0].id, 'q1');
  assert.equal((await app.inject({ method: 'GET', url: '/v1/records/collect', headers: headers('bob') })).json().data.length, 0);
  const got = await app.inject({ method: 'GET', url: '/v1/records/collect', headers: headers('alice') });
  assert.equal(got.json().data.length, 1);
  const removed = await app.inject({
    method: 'DELETE', url: '/v1/records/collect', headers: headers('alice'), payload: { id: 'q1', contentType: 0 }
  });
  assert.equal(removed.json().data.length, 0);
  assert.equal((await app.inject({ method: 'GET', url: '/v1/records/collect', headers: { authorization: `Bearer ${token}` } })).statusCode, 400);
  assert.equal((await app.inject({ method: 'GET', url: '/v1/records/cart', headers: headers('alice') })).statusCode, 400);
});
