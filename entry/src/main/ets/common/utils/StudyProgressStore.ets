import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'

const STORE_NAME = 'studyProgress'

export interface StudyProgressStorage {
  readIds(key: string): string[]
  writeIds(key: string, ids: string[]): void
}

class PreferencesStudyProgressStorage implements StudyProgressStorage {
  private readonly file: preferences.Preferences

  constructor(file: preferences.Preferences) { this.file = file }

  readIds(key: string): string[] {
    const value = this.file.getSync(key, []) as string[]
    if (!Array.isArray(value) || !value.every((id: string) => typeof id === 'string')) {
      throw new Error('Invalid study progress data')
    }
    return value.slice()
  }

  writeIds(key: string, ids: string[]): void {
    const previous = this.readIds(key)
    this.file.putSync(key, ids)
    try {
      this.file.flushSync()
    } catch (_) {
      // Do not leave a failed write visible as a confirmed change in the cache.
      this.file.putSync(key, previous)
      throw new Error('Study progress persistence failed')
    }
  }
}

export class StudyProgressStore {
  private readonly storage: StudyProgressStorage | undefined

  constructor(storage?: StudyProgressStorage) { this.storage = storage }

  private getStorage(): StudyProgressStorage | undefined {
    if (this.storage) { return this.storage }
    const context = contextManager.getCtx()
    if (!context) {
      return undefined
    }
    try {
      return new PreferencesStudyProgressStorage(preferences.getPreferencesSync(context, { name: STORE_NAME }))
    } catch (_) {
      return undefined
    }
  }

  private key(userId: string, typeId: number, questionBankType: number): string {
    return `ids:${userId}:${questionBankType}:${typeId}`
  }

  private completedKey(userId: string): string {
    // Legacy ids:* contain visits, never evidence of explicit completion.
    // Completion belongs to an ordinary question, regardless of its entry route.
    return `completed:v1:question:${userId}`
  }

  // Retain category membership for aggregation, without marking a question complete.
  rememberQuestion(userId: string | undefined, typeId: number | undefined, questionBankType: number,
    questionId: string): boolean {
    if (!userId || !typeId || !Number.isSafeInteger(typeId) || typeId <= 0 ||
      !Number.isSafeInteger(questionBankType) || questionBankType <= 0 || !questionId) { return false }
    try {
      const storage = this.getStorage()
      if (!storage) { return false }
      const key = this.key(userId, typeId, questionBankType)
      const ids = storage.readIds(key)
      if (ids.indexOf(questionId) >= 0) { return true }
      storage.writeIds(key, ids.concat([questionId]))
      return true
    } catch (_) { return false }
  }

  // undefined means storage could not be read; the UI must offer retry, not assume incomplete.
  isCompleted(userId: string | undefined, questionId: string): boolean | undefined {
    if (!userId || !questionId) { return false }
    try {
      const storage = this.getStorage()
      if (!storage) { return undefined }
      return storage.readIds(this.completedKey(userId)).indexOf(questionId) >= 0
    } catch (_) { return undefined }
  }

  setCompleted(userId: string | undefined, questionId: string, completed: boolean): boolean {
    if (!userId || !questionId) { return false }
    try {
      const storage = this.getStorage()
      if (!storage) { return false }
      const key = this.completedKey(userId)
      const ids = storage.readIds(key)
      const exists = ids.indexOf(questionId) >= 0
      if (exists === completed) { return true }
      const next = completed ? ids.concat([questionId]) : ids.filter((id: string) => id !== questionId)
      storage.writeIds(key, next)
      return true
    } catch (_) { return false }
  }

  getDone(userId: string | undefined, typeId: string, questionBankType: number, total: number): number {
    const numericTypeId = Number(typeId)
    if (!userId || !Number.isSafeInteger(numericTypeId) || numericTypeId <= 0 ||
      !Number.isSafeInteger(questionBankType) || questionBankType <= 0 || !Number.isFinite(total) || total <= 0) {
      return 0
    }
    try {
      const storage = this.getStorage()
      if (!storage) { return 0 }
      const ids = new Set<string>(storage.readIds(this.key(userId, numericTypeId, questionBankType)))
      const completed = new Set<string>(storage.readIds(this.completedKey(userId)))
      let done = 0
      ids.forEach((id: string) => { if (completed.has(id)) { done++ } })
      return Math.min(Math.floor(total), done)
    } catch (_) {
      return 0
    }
  }
}

export const studyProgressStore = new StudyProgressStore()
