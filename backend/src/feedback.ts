import { mkdir, appendFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { randomBytes } from 'node:crypto';

export interface FeedbackRecord {
  id: string;
  content: string;
  createdAt: string;
}

export interface FeedbackStore {
  append(content: string): Promise<FeedbackRecord>;
}

export const feedbackSchema = {
  type: 'object', additionalProperties: false,
  required: ['content'],
  properties: {
    content: { type: 'string', minLength: 1, maxLength: 4000, pattern: '\\S' }
  }
} as const;

export function parseFeedbackContent(value: string): string | undefined {
  const content = value.trim();
  if (!content || content.length > 4000) return undefined;
  return content;
}

export class FileFeedbackStore implements FeedbackStore {
  constructor(private readonly file: string) {}

  async append(content: string): Promise<FeedbackRecord> {
    const record: FeedbackRecord = {
      id: randomBytes(16).toString('hex'),
      content,
      createdAt: new Date().toISOString()
    };
    await mkdir(dirname(this.file), { recursive: true });
    await appendFile(this.file, `${JSON.stringify(record)}\n`, 'utf8');
    return record;
  }
}

export function defaultFeedbackFile(): string {
  return join(process.cwd(), 'data', 'feedback.jsonl');
}
