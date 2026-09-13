import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'
import {
  addStudyTimeDuration,
  buildStudyTimeKeys,
  normalizeStoredStudyTime,
  resolveStudyTimeTotal
} from './StudyTimePolicy'

const STORE_NAME = 'studyTime'
const RESET_VERSION = 'legacyTotalResetV1'

class StudyTimeStore {
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

  record(userId: string | undefined, username: string | undefined, questionId: string,
    startedAt: number, endedAt: number): void {
    const keys = buildStudyTimeKeys(userId, username)
    if (keys.length === 0 || !questionId || startedAt <= 0 || endedAt <= startedAt) {
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
    try {
      const total = addStudyTimeDuration(this.getTotalTime(userId, username), duration)
      this.persistTotal(file, keys, total)
      file.flushSync()
    } catch (_) {
      return
    }
  }

  getTotalTime(userId: string | undefined, username: string | undefined): number {
    const keys = buildStudyTimeKeys(userId, username)
    if (keys.length === 0) {
      return 0
    }
    const file = this.getPreferences()
    if (!file) {
      return 0
    }
    try {
      // 旧版本曾把接口累计值写入本地；首次访问时清空，后续只保留本地新记录。
      const resetKey = `${RESET_VERSION}:${keys[0]}`
      if (file.getSync(resetKey, false) !== true) {
        this.persistTotal(file, keys, 0)
        file.putSync(resetKey, true)
        file.flushSync()
        return 0
      }
      const totals: number[] = [0]
      keys.forEach((key: string) => {
        const value = file.getSync(key, 0)
        if (typeof value === 'number') {
          const migrated = normalizeStoredStudyTime(value)
          if (migrated !== value) {
            file.putSync(key, migrated)
          }
          totals.push(migrated)
        }
      })
      const total = resolveStudyTimeTotal(totals)
      this.persistTotal(file, keys, total)
      file.flushSync()
      return total
    } catch (_) {
      return 0
    }
  }

  private persistTotal(file: preferences.Preferences, keys: string[], total: number): void {
    keys.forEach((key: string) => {
      file.putSync(key, total)
    })
  }
}

export const studyTimeStore = new StudyTimeStore()
