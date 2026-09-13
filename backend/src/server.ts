import { buildApp } from './app.js';
import { loadConfig, configured } from './config.js';

try {
  const config = loadConfig();
  const app = await buildApp(config);
  await app.listen({ host: config.host, port: config.port });
  console.log(`Scoring backend listening on ${config.host}:${config.port}; scoringReady=${configured(config)}`);
  const shutdown = async () => {
    const timer = setTimeout(() => process.exit(1), 10000).unref();
    await app.close();
    clearTimeout(timer);
    process.exit(0);
  };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
} catch {
  // Configuration or provider errors can contain credentials; do not log raw objects.
  console.error('Backend startup failed. Check environment configuration and port availability.');
  process.exitCode = 1;
}
