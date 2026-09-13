export interface Config {
  provider: 'openai-compatible' | 'qwen';
  host: string;
  port: number;
  accessToken: string;
  modelUrl: string;
  modelKey: string;
  model: string;
  jsonMode: 'json_schema' | 'json_object';
  tokenField: 'max_completion_tokens' | 'max_tokens';
  maxOutputTokens: number;
  timeoutMs: number;
  rateLimit: number;
  maxConcurrent: number;
}

function integer(env: NodeJS.ProcessEnv, key: string, fallback: number, min: number, max: number): number {
  const raw = env[key];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < min || value > max) throw new Error(`Invalid ${key}`);
  return value;
}

export function isLoopback(host: string): boolean {
  return host === '127.0.0.1' || host === 'localhost' || host === '::1' || host === '[::1]';
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const provider = env.LLM_PROVIDER?.trim() || 'openai-compatible';
  if (provider !== 'openai-compatible' && provider !== 'qwen') throw new Error('Invalid LLM_PROVIDER');
  const host = env.HOST?.trim() || '127.0.0.1';
  const accessToken = env.API_ACCESS_TOKEN || '';
  if (accessToken && (!/^[A-Za-z0-9_-]{32,256}$/.test(accessToken))) throw new Error('Invalid API_ACCESS_TOKEN');
  if (!isLoopback(host) && !accessToken) throw new Error('Non-loopback binding requires API_ACCESS_TOKEN');
  const modelUrl = env.LLM_API_URL?.trim() || (provider === 'qwen' ?
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions' : '');
  const modelKey = env.LLM_API_KEY?.trim() || '';
  if (modelUrl) {
    let url: URL;
    try { url = new URL(modelUrl); } catch { throw new Error('Invalid LLM_API_URL'); }
    if (url.username || url.password || url.hash || url.search ||
      (url.protocol !== 'https:' && !(url.protocol === 'http:' && isLoopback(url.hostname)))) {
      throw new Error('LLM_API_URL must use HTTPS or loopback HTTP, without embedded credentials or query');
    }
  }
  const jsonMode = env.LLM_JSON_MODE || 'json_schema';
  const tokenField = env.LLM_TOKEN_FIELD || 'max_completion_tokens';
  if (jsonMode !== 'json_schema' && jsonMode !== 'json_object') throw new Error('Invalid LLM_JSON_MODE');
  if (tokenField !== 'max_completion_tokens' && tokenField !== 'max_tokens') throw new Error('Invalid LLM_TOKEN_FIELD');
  return {
    provider,
    host, port: integer(env, 'PORT', 3000, 1, 65535), accessToken, modelUrl, modelKey,
    model: env.LLM_MODEL?.trim() || (provider === 'qwen' ? 'qwen3.7-flash' : ''), jsonMode, tokenField,
    maxOutputTokens: integer(env, 'LLM_MAX_OUTPUT_TOKENS', provider === 'qwen' ? 1280 : 2048, 128, 8192),
    timeoutMs: integer(env, 'SCORE_TIMEOUT_MS', 45000, 100, 50000),
    rateLimit: integer(env, 'RATE_LIMIT_PER_MINUTE', 10, 1, 1000),
    maxConcurrent: integer(env, 'MAX_CONCURRENT_SCORES', 2, 1, 20)
  };
}

export function configured(config: Config): boolean {
  if (!config.accessToken || !config.modelUrl || !config.model) return false;
  return Boolean(config.modelKey || isLoopback(new URL(config.modelUrl).hostname));
}
