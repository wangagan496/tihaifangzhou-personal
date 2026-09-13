import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'

export interface StudyTimeRecord {
  userId: string
  questionId: string
  startedAt: number
  endedAt: number
  duration: number
}

const STORE_NAME = 'studyTime'
const RECORDS_KEY = 'records'
const MAX_RECORDS = 2000

class StudyTimeStore {
  private getPreferences(): preferences.Preferences | undefined {
    const context = contextManager.getCtx()
    return context ? preferences.getPreferencesSync(context, { name: STORE_NAME }) : undefined
  }

  record(userId: string | undefined, questionId: string, startedAt: number, endedAt: number): void {
    if (!userId || !questionId || startedAt <= 0 || endedAt <= startedAt) {
      return
    }
    const duration = Math.min(Math.floor((endedAt - startedAt) / 1000), 2 * 60 * 60)
    if (duration <= 0) {
      return
    }
    const file = this.getPreferences()
    if (!file) {
      return
    }
    const records = file.getSync(RECORDS_KEY, []) as StudyTimeRecord[]
    records.push({ userId, questionId, startedAt, endedAt, duration })
    file.putSync(RECORDS_KEY, records.slice(-MAX_RECORDS))
    file.flushSync()
  }

  getTotalTime(userId: string | undefined): number {
    if (!userId) {
      return 0
    }
    const file = this.getPreferences()
    if (!file) {
      return 0
    }
    const records = file.getSync(RECORDS_KEY, []) as StudyTimeRecord[]
    return records
      .filter((record: StudyTimeRecord) => record.userId === userId)
      .reduce((total: number, record: StudyTimeRecord) => total + record.duration, 0)
  }
}

export const studyTimeStore = new StudyTimeStore()
