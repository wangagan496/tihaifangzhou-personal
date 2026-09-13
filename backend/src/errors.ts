export class ServiceError extends Error {
  constructor(readonly status: number, readonly code: number, message: string) {
    super(message);
    this.name = 'ServiceError';
  }
}

export const unavailable = () => new ServiceError(503, 50301, 'AI 评分服务尚未配置完成');
export const badModelOutput = () => new ServiceError(502, 50202, '模型返回格式无效，未生成评分');
