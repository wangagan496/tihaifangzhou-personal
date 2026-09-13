import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'

const STORE_NAME = 'studyProgress'

class StudyProgressStore {
  private getPreferences(): preferences.Preferences | undefined {
    const context = contextManager.getCtx()
    if (!context) {
      return undefined
    }
    try {
      return preferences.getPreferencesSync(context, { name: STORE_NAME })
    } catch (_) {
      return undefined
    }
  }

  private key(userId: string, typeId: number, questionBankType: number): string {
    return `ids:${userId}:${questionBankType}:${typeId}`
  }

  record(userId: string | undefined, typeId: number | undefined, questionBankType: number,
    questionId: string): void {
    if (!userId || !typeId || !questionId) {
      return
    }
    const file = this.getPreferences()
    if (!file) {
      return
    }
    try {
      const key = this.key(userId, typeId, questionBankType)
      const ids = file.getSync(key, []) as string[]
      if (ids.indexOf(questionId) >= 0) {
        return
      }
      ids.push(questionId)
      file.putSync(key, ids)
      file.flushSync()
    } catch (_) {
      return
    }
  }

  getDone(userId: string | undefined, typeId: string, questionBankType: number, total: number): number {
    if (!userId || !typeId || total <= 0) {
      return 0
    }
    const file = this.getPreferences()
    if (!file) {
      return 0
    }
    try {
      const numericTypeId = Number(typeId)
      const ids = file.getSync(this.key(userId, numericTypeId, questionBankType), []) as string[]
      return Math.min(total, ids.length)
    } catch (_) {
      return 0
    }
  }
}

export const studyProgressStore = new StudyProgressStore()
