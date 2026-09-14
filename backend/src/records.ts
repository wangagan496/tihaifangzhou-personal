import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { addRecord, setRecordFlag } from './records-policy.js';
import type { QuestionRecord, RecordKind } from './records-policy.js';

export interface OwnerRecords {
  history: QuestionRecord[];
  collect: QuestionRecord[];
  like: QuestionRecord[];
}

export interface RecordsStore {
  list(ownerId: string, kind: RecordKind): Promise<QuestionRecord[]>;
  put(ownerId: string, kind: RecordKind, item: QuestionRecord): Promise<QuestionRecord[]>;
  remove(ownerId: string, kind: RecordKind, item: QuestionRecord): Promise<QuestionRecord[]>;
}

type FileShape = Record<string, OwnerRecords>;

function empty(): OwnerRecords {
  return { history: [], collect: [], like: [] };
}

export class MemoryRecordsStore implements RecordsStore {
  private readonly data: FileShape = {};

  async list(ownerId: string, kind: RecordKind): Promise<QuestionRecord[]> {
    return [...(this.data[ownerId] || empty())[kind]];
  }

  async put(ownerId: string, kind: RecordKind, item: QuestionRecord): Promise<QuestionRecord[]> {
    const bucket = this.data[ownerId] || empty();
    bucket[kind] = kind === 'history' ? addRecord(bucket[kind], item) : setRecordFlag(bucket[kind], item, true);
    this.data[ownerId] = bucket;
    return [...bucket[kind]];
  }

  async remove(ownerId: string, kind: RecordKind, item: QuestionRecord): Promise<QuestionRecord[]> {
    const bucket = this.data[ownerId] || empty();
    bucket[kind] = setRecordFlag(bucket[kind], item, false);
    this.data[ownerId] = bucket;
    return [...bucket[kind]];
  }
}

export class FileRecordsStore implements RecordsStore {
  constructor(private readonly file: string) {}

  async list(ownerId: string, kind: RecordKind): Promise<QuestionRecord[]> {
    const all = await this.read();
    return [...(all[ownerId] || empty())[kind]];
  }

  async put(ownerId: string, kind: RecordKind, item: QuestionRecord): Promise<QuestionRecord[]> {
    const all = await this.read();
    const bucket = all[ownerId] || empty();
    bucket[kind] = kind === 'history' ? addRecord(bucket[kind], item) : setRecordFlag(bucket[kind], item, true);
    all[ownerId] = bucket;
    await this.write(all);
    return [...bucket[kind]];
  }

  async remove(ownerId: string, kind: RecordKind, item: QuestionRecord): Promise<QuestionRecord[]> {
    const all = await this.read();
    const bucket = all[ownerId] || empty();
    bucket[kind] = setRecordFlag(bucket[kind], item, false);
    all[ownerId] = bucket;
    await this.write(all);
    return [...bucket[kind]];
  }

  private async read(): Promise<FileShape> {
    try {
      const raw = await readFile(this.file, 'utf8');
      const parsed = JSON.parse(raw) as FileShape;
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch {
      return {};
    }
  }

  private async write(data: FileShape): Promise<void> {
    await mkdir(dirname(this.file), { recursive: true });
    await writeFile(this.file, `${JSON.stringify(data)}\n`, 'utf8');
  }
}

export function defaultRecordsFile(): string {
  return join(process.cwd(), 'data', 'records.json');
}
