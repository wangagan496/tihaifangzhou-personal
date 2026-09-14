export type RecordKind = 'history' | 'collect' | 'like';

export interface QuestionRecord {
  id: string;
  stem: string;
  difficulty: number;
  likeCount: number;
  views: number;
  readFlag: 0 | 1;
  contentType?: 0 | 1;
  questionNo?: string;
}

const KINDS: RecordKind[] = ['history', 'collect', 'like'];

export function isRecordKind(value: string): value is RecordKind {
  return (KINDS as string[]).includes(value);
}

function sameContent(left: QuestionRecord, right: QuestionRecord): boolean {
  return left.id === right.id && (left.contentType || 0) === (right.contentType || 0);
}

export function addRecord(list: QuestionRecord[], item: QuestionRecord, limit = 50): QuestionRecord[] {
  return [item, ...list.filter(record => !sameContent(record, item))].slice(0, limit);
}

export function setRecordFlag(list: QuestionRecord[], item: QuestionRecord, enabled: boolean, limit = 50): QuestionRecord[] {
  if (enabled) return addRecord(list, item, limit);
  return list.filter(record => !sameContent(record, item));
}

export function parseOwnerId(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const id = value.trim();
  if (!id || id.length > 128) return undefined;
  return id;
}

export function parseQuestionRecord(value: unknown): QuestionRecord | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  const row = value as Record<string, unknown>;
  if (typeof row.id !== 'string' || !row.id.trim()) return undefined;
  if (typeof row.stem !== 'string' || !row.stem.trim() || row.stem.length > 2000) return undefined;
  if (typeof row.difficulty !== 'number' || !Number.isFinite(row.difficulty)) return undefined;
  if (typeof row.likeCount !== 'number' || !Number.isFinite(row.likeCount)) return undefined;
  if (typeof row.views !== 'number' || !Number.isFinite(row.views)) return undefined;
  if (row.readFlag !== 0 && row.readFlag !== 1) return undefined;
  const item: QuestionRecord = {
    id: row.id.trim(),
    stem: row.stem,
    difficulty: row.difficulty,
    likeCount: row.likeCount,
    views: row.views,
    readFlag: row.readFlag
  };
  if (row.contentType === 0 || row.contentType === 1) item.contentType = row.contentType;
  if (typeof row.questionNo === 'string' && row.questionNo.length <= 64) item.questionNo = row.questionNo;
  return item;
}
