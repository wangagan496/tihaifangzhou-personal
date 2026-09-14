import { createHash, timingSafeEqual } from 'node:crypto';
import Fastify from 'fastify';
import rateLimit from '@fastify/rate-limit';
import type { Config } from './config.js';
import { configured } from './config.js';
import { ServiceError, unavailable } from './errors.js';
import { ChatCompletionsProvider } from './model-provider.js';
import type { ScoreProvider } from './model-provider.js';
import { inputSchema, parseScore, record } from './score-contract.js';
import type { ScoreInput } from './score-contract.js';
import { defaultFeedbackFile, FileFeedbackStore, feedbackSchema, parseFeedbackContent } from './feedback.js';
import type { FeedbackStore } from './feedback.js';
import { defaultRecordsFile, FileRecordsStore } from './records.js';
import type { RecordsStore } from './records.js';
import { isRecordKind, parseOwnerId, parseQuestionRecord } from './records-policy.js';

function matchesToken(header: string | undefined, token: string): boolean {
  if (!header?.startsWith('Bearer ') || header.length > 300) return false;
  const digest = (value: string) => createHash('sha256').update(value).digest();
  return timingSafeEqual(digest(header.slice(7)), digest(token));
}

function authorize(origin: unknown, authorization: unknown, config: Config): void {
  if (typeof origin === 'string' && origin.length > 0) throw new ServiceError(403, 40301, '不接受浏览器跨站请求');
  const header = typeof authorization === 'string' ? authorization : undefined;
  if (config.accessToken && !matchesToken(header, config.accessToken)) {
    throw new ServiceError(401, 40101, '服务访问码无效');
  }
}

export async function buildApp(config: Config, provider: ScoreProvider = new ChatCompletionsProvider(config),
  feedbackStore: FeedbackStore = new FileFeedbackStore(defaultFeedbackFile()),
  recordsStore: RecordsStore = new FileRecordsStore(defaultRecordsFile())) {
  const app = Fastify({
    logger: false, bodyLimit: 160000, requestTimeout: 10000, connectionTimeout: 65000,
    trustProxy: false,
    ajv: { customOptions: { coerceTypes: false, removeAdditional: false } }
  });
  const active = new Set<AbortController>();
  await app.register(rateLimit, {
    global: true, max: config.rateLimit, timeWindow: '1 minute',
    errorResponseBuilder: () => new ServiceError(429, 42901, '请求过于频繁，请稍后重试')
  });
  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ServiceError) {
      return reply.code(error.status).send({ code: error.code, success: false, data: null, message: error.message });
    }
    const statusCode = record(error) ? error.statusCode : undefined;
    const validation = record(error) ? error.validation : undefined;
    const status = statusCode === 413 ? 413 : statusCode === 415 ? 415 : validation || statusCode === 400 ? 400 : 500;
    return reply.code(status).send({ code: status * 100, success: false, data: null,
      message: status === 500 ? '服务内部错误，请稍后重试' : '请求格式或长度不符合要求' });
  });
  app.setNotFoundHandler((request, reply) => reply.code(404).send({
    code: 40400, success: false, data: null, message: '接口不存在'
  }));
  app.get('/healthz', { config: { rateLimit: false } }, async () => ({ status: 'ok', scoringReady: configured(config) }));
  app.get('/readyz', { config: { rateLimit: false } }, async (request, reply) => {
    if (!configured(config)) return reply.code(503).send({ status: 'not_ready' });
    return { status: 'ready' };
  });
  app.post<{ Body: ScoreInput }>('/v1/scores', {
    schema: { body: inputSchema },
    onRequest: async request => {
      authorize(request.headers.origin, request.headers.authorization, config);
      if (!configured(config)) throw unavailable();
    }
  }, async (request, reply) => {
    const input: ScoreInput = {
      question: request.body.question.trim(), answer: request.body.answer.trim(), referenceAnswer: request.body.referenceAnswer.trim()
    };
    // Match the ArkTS UTF-16 length limits, in addition to JSON Schema code-point limits.
    if (input.question.length > 2000 || input.answer.length > 20000 || input.referenceAnswer.length > 20000) {
      throw new ServiceError(400, 40001, '题目或回答超出长度限制');
    }
    if (active.size >= config.maxConcurrent) throw new ServiceError(429, 42902, '评分任务已满，请稍后重试');
    const controller = new AbortController();
    active.add(controller);
    const cancel = () => {
      if (!reply.raw.writableEnded) controller.abort(new ServiceError(499, 49901, '客户端已断开'));
    };
    reply.raw.once('close', cancel);
    const timer = setTimeout(() => controller.abort(new ServiceError(504, 50401, '评分超时，请稍后重试')), config.timeoutMs);
    let rejectAbort: (() => void) | undefined;
    const aborted = new Promise<never>((resolve, reject) => {
      rejectAbort = () => reject(controller.signal.reason);
      controller.signal.addEventListener('abort', rejectAbort, { once: true });
    });
    try {
      const result = parseScore(await Promise.race([provider.score(input, controller.signal), aborted]));
      return { code: 10000, success: true, data: result, message: '评分完成，仅供练习参考' };
    } finally {
      clearTimeout(timer);
      reply.raw.removeListener('close', cancel);
      if (rejectAbort) controller.signal.removeEventListener('abort', rejectAbort);
      active.delete(controller);
    }
  });
  app.post<{ Body: { content: string } }>('/v1/feedback', {
    schema: { body: feedbackSchema },
    onRequest: async request => { authorize(request.headers.origin, request.headers.authorization, config); }
  }, async (request) => {
    const content = parseFeedbackContent(request.body.content);
    if (!content) throw new ServiceError(400, 40001, '反馈内容不符合要求');
    const saved = await feedbackStore.append(content);
    return { code: 10000, success: true, data: { id: saved.id }, message: '反馈已送达' };
  });
  const recordItemSchema = {
    type: 'object', additionalProperties: false,
    required: ['id', 'stem', 'difficulty', 'likeCount', 'views', 'readFlag'],
    properties: {
      id: { type: 'string', minLength: 1, maxLength: 128 },
      stem: { type: 'string', minLength: 1, maxLength: 2000 },
      difficulty: { type: 'number' },
      likeCount: { type: 'number' },
      views: { type: 'number' },
      readFlag: { type: 'number', enum: [0, 1] },
      contentType: { type: 'number', enum: [0, 1] },
      questionNo: { type: 'string', maxLength: 64 }
    }
  } as const;
  const recordKeySchema = {
    type: 'object', additionalProperties: false,
    required: ['id'],
    properties: {
      id: { type: 'string', minLength: 1, maxLength: 128 },
      contentType: { type: 'number', enum: [0, 1] }
    }
  } as const;
  app.get<{ Params: { kind: string } }>('/v1/records/:kind', {
    onRequest: async request => { authorize(request.headers.origin, request.headers.authorization, config); }
  }, async (request) => {
    if (!isRecordKind(request.params.kind)) throw new ServiceError(400, 40001, '记录类型无效');
    const ownerId = parseOwnerId(request.headers['x-owner-id']);
    if (!ownerId) throw new ServiceError(400, 40001, '缺少账号标识');
    const list = await recordsStore.list(ownerId, request.params.kind);
    return { code: 10000, success: true, data: list, message: 'ok' };
  });
  app.put<{ Params: { kind: string }; Body: unknown }>('/v1/records/:kind', {
    schema: { body: recordItemSchema },
    onRequest: async request => { authorize(request.headers.origin, request.headers.authorization, config); }
  }, async (request) => {
    if (!isRecordKind(request.params.kind)) throw new ServiceError(400, 40001, '记录类型无效');
    const ownerId = parseOwnerId(request.headers['x-owner-id']);
    const item = parseQuestionRecord(request.body);
    if (!ownerId || !item) throw new ServiceError(400, 40001, '记录内容不符合要求');
    const list = await recordsStore.put(ownerId, request.params.kind, item);
    return { code: 10000, success: true, data: list, message: 'ok' };
  });
  app.delete<{ Params: { kind: string }; Body: { id: string; contentType?: 0 | 1 } }>('/v1/records/:kind', {
    schema: { body: recordKeySchema },
    onRequest: async request => { authorize(request.headers.origin, request.headers.authorization, config); }
  }, async (request) => {
    if (!isRecordKind(request.params.kind)) throw new ServiceError(400, 40001, '记录类型无效');
    const ownerId = parseOwnerId(request.headers['x-owner-id']);
    const stub = parseQuestionRecord({
      id: request.body?.id, stem: 'x', difficulty: 0, likeCount: 0, views: 0, readFlag: 0,
      contentType: request.body?.contentType
    });
    if (!ownerId || !stub) throw new ServiceError(400, 40001, '记录内容不符合要求');
    const list = await recordsStore.remove(ownerId, request.params.kind, stub);
    return { code: 10000, success: true, data: list, message: 'ok' };
  });
  app.addHook('preClose', async () => {
    for (const controller of active) controller.abort(new ServiceError(503, 50302, '服务正在关闭'));
  });
  return app;
}
