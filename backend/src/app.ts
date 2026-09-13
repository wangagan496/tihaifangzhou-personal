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

function matchesToken(header: string | undefined, token: string): boolean {
  if (!header?.startsWith('Bearer ') || header.length > 300) return false;
  const digest = (value: string) => createHash('sha256').update(value).digest();
  return timingSafeEqual(digest(header.slice(7)), digest(token));
}

export async function buildApp(config: Config, provider: ScoreProvider = new ChatCompletionsProvider(config)) {
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
      // Private native-client API. Cross-origin browser calls are not supported.
      if (request.headers.origin) throw new ServiceError(403, 40301, '不接受浏览器跨站请求');
      if (!configured(config)) throw unavailable();
      if (!matchesToken(request.headers.authorization, config.accessToken)) {
        throw new ServiceError(401, 40101, '服务访问码无效');
      }
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
  app.addHook('preClose', async () => {
    for (const controller of active) controller.abort(new ServiceError(503, 50302, '服务正在关闭'));
  });
  return app;
}
