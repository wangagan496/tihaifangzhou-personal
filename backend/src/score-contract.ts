import { badModelOutput } from './errors.js';

export interface ScoreInput { question: string; answer: string; referenceAnswer: string }
export interface ScoreResult { score: number; summary: string; strengths: string[]; improvements: string[] }

export const inputSchema = {
  type: 'object', additionalProperties: false,
  required: ['question', 'answer', 'referenceAnswer'],
  properties: {
    question: { type: 'string', minLength: 1, maxLength: 2000, pattern: '\\S' },
    answer: { type: 'string', minLength: 1, maxLength: 20000, pattern: '\\S' },
    referenceAnswer: { type: 'string', maxLength: 20000 }
  }
} as const;

export const outputSchema = {
  type: 'object', additionalProperties: false,
  required: ['score', 'summary', 'strengths', 'improvements'],
  properties: {
    score: { type: 'number', minimum: 0, maximum: 100 },
    summary: { type: 'string', minLength: 1, maxLength: 4000 },
    strengths: { type: 'array', maxItems: 10, items: { type: 'string', minLength: 1, maxLength: 2000 } },
    improvements: { type: 'array', maxItems: 10, items: { type: 'string', minLength: 1, maxLength: 2000 } }
  }
} as const;

export function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function text(value: unknown, max: number): value is string {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= max;
}

function feedback(value: unknown): value is string[] {
  return Array.isArray(value) && value.length <= 10 && value.every(item => text(item, 2000));
}

export function parseScore(value: unknown): ScoreResult {
  if (!record(value) || Object.keys(value).length !== 4 || typeof value.score !== 'number' ||
    !Number.isFinite(value.score) || value.score < 0 || value.score > 100 || !text(value.summary, 4000) ||
    !feedback(value.strengths) || !feedback(value.improvements)) throw badModelOutput();
  return { score: value.score, summary: value.summary, strengths: value.strengths, improvements: value.improvements };
}
