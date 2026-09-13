import { relationalStore, ValuesBucket } from '@kit.ArkData'
import { canSaveTranscript } from './TranscriptionPolicy'

export interface InterviewAudioItem extends ValuesBucket {
  id: number | null
  user_id: string
  name: string
  path: string
  duration: number
  size: number
  create_time: number
}

export class AudioDB {
  private store?: relationalStore.RdbStore
  private readonly tableName: string = 'interview_audio'
  private initialized: boolean = false

  // 录音文件保留在沙箱；文字稿使用独立表，不改变已有录音表结构。
  initStore(): Promise<boolean> {
    if (this.initialized && this.store) {
      return Promise.resolve(true)
    }
    const context = AppStorage.get<Context>('context')
    if (!context) {
      return Promise.resolve(false)
    }
    try {
      return relationalStore.getRdbStore(context, {
        name: 'interview_audio.db',
        securityLevel: relationalStore.SecurityLevel.S1
      }).then((store): Promise<boolean> => {
        return store.executeSql(`
          CREATE TABLE IF NOT EXISTS ${this.tableName} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            duration INTEGER NOT NULL,
            size INTEGER NOT NULL,
            create_time INTEGER NOT NULL
          )
        `).then((): Promise<void> => {
          return store.executeSql(`CREATE INDEX IF NOT EXISTS idx_${this.tableName}_user_time ON ${this.tableName} (user_id, create_time DESC)`)
        }).then((): Promise<void> => {
          return store.executeSql(`CREATE TABLE IF NOT EXISTS interview_audio_transcript (
            audio_id INTEGER PRIMARY KEY, user_id TEXT NOT NULL, transcript TEXT NOT NULL, updated_time INTEGER NOT NULL
          )`)
        }).then((): Promise<void> => {
          return store.executeSql(`CREATE TRIGGER IF NOT EXISTS delete_audio_transcript
            AFTER DELETE ON ${this.tableName} BEGIN
              DELETE FROM interview_audio_transcript WHERE audio_id = OLD.id;
            END`)
        }).then((): boolean => {
          this.store = store
          this.initialized = true
          return true
        })
      }, (): boolean => {
        this.store = undefined
        this.initialized = false
        return false
      }).then((result): boolean => result, (): boolean => {
        this.store = undefined
        this.initialized = false
        return false
      })
    } catch (_) {
      this.store = undefined
      this.initialized = false
      return Promise.resolve(false)
    }
  }

  insert(item: InterviewAudioItem): Promise<boolean> {
    if (!this.store) {
      return Promise.resolve(false)
    }
    try {
      return this.store.insert(this.tableName, item).then((id): boolean => id !== -1, (): boolean => false)
    } catch (_) {
      return Promise.resolve(false)
    }
  }

  async find(id: number, userId: string): Promise<InterviewAudioItem | undefined> {
    if (!this.store || !Number.isSafeInteger(id) || id <= 0 || !userId) { return undefined }
    const predicates = new relationalStore.RdbPredicates(this.tableName)
    predicates.equalTo('id', id).equalTo('user_id', userId)
    const result = await this.store.query(predicates)
    try {
      if (!result.goToFirstRow()) { return undefined }
      return {
        id: result.getLong(result.getColumnIndex('id')),
        user_id: result.getString(result.getColumnIndex('user_id')),
        name: result.getString(result.getColumnIndex('name')),
        path: result.getString(result.getColumnIndex('path')),
        duration: result.getLong(result.getColumnIndex('duration')),
        size: result.getLong(result.getColumnIndex('size')),
        create_time: result.getLong(result.getColumnIndex('create_time'))
      }
    } finally { result.close() }
  }

  async getTranscript(id: number, userId: string): Promise<string> {
    if (!this.store || !Number.isSafeInteger(id) || id <= 0 || !userId) { return '' }
    const predicates = new relationalStore.RdbPredicates('interview_audio_transcript')
    predicates.equalTo('audio_id', id).equalTo('user_id', userId)
    try {
      const result = await this.store.query(predicates, ['transcript'])
      try { return result.goToFirstRow() ? result.getString(0) : '' } finally { result.close() }
    } catch (_) { throw new Error('TRANSCRIPT_READ') }
  }

  async saveTranscript(id: number, userId: string, text: string): Promise<boolean> {
    if (!this.store || !canSaveTranscript(id, userId, text)) { return false }
    const value = text.trim()
    try {
      // Conditional insert prevents late recognition results from recreating a deleted/foreign recording.
      await this.store.executeSql(`INSERT INTO interview_audio_transcript (audio_id, user_id, transcript, updated_time)
        SELECT id, user_id, ?, ? FROM ${this.tableName} WHERE id = ? AND user_id = ?
        ON CONFLICT(audio_id) DO UPDATE SET transcript = excluded.transcript, updated_time = excluded.updated_time`,
        [value, Date.now(), id, userId])
      return await this.getTranscript(id, userId) === value
    } catch (_) { return false }
  }

  delete(id: number): Promise<boolean> {
    if (!this.store) {
      return Promise.resolve(false)
    }
    const predicates = new relationalStore.RdbPredicates(this.tableName)
    predicates.equalTo('id', id)
    try {
      return this.store.delete(predicates).then((count): boolean => count > 0, (): boolean => false)
    } catch (_) {
      return Promise.resolve(false)
    }
  }

  update(item: InterviewAudioItem): Promise<boolean> {
    if (!this.store || item.id === null) {
      return Promise.resolve(false)
    }
    const predicates = new relationalStore.RdbPredicates(this.tableName)
    predicates.equalTo('id', item.id)
    try {
      return this.store.update(item, predicates).then((count): boolean => count > 0, (): boolean => false)
    } catch (_) {
      return Promise.resolve(false)
    }
  }

  // 查询始终带 user_id 条件，避免切换账号后读取到别人的录音。
  query(userId: string): Promise<InterviewAudioItem[]> {
    if (!this.store || !userId) {
      return Promise.resolve([])
    }
    const predicates = new relationalStore.RdbPredicates(this.tableName)
    predicates.equalTo('user_id', userId).orderByDesc('create_time')
    try {
      return this.store.query(predicates).then((resultSet): InterviewAudioItem[] => {
        const list: InterviewAudioItem[] = []
        while (resultSet.goToNextRow()) {
          list.push({
            id: resultSet.getLong(resultSet.getColumnIndex('id')),
            user_id: resultSet.getString(resultSet.getColumnIndex('user_id')),
            name: resultSet.getString(resultSet.getColumnIndex('name')),
            path: resultSet.getString(resultSet.getColumnIndex('path')),
            duration: resultSet.getLong(resultSet.getColumnIndex('duration')),
            size: resultSet.getLong(resultSet.getColumnIndex('size')),
            create_time: resultSet.getLong(resultSet.getColumnIndex('create_time'))
          })
        }
        resultSet.close()
        return list
      }, (): InterviewAudioItem[] => [])
    } catch (_) {
      return Promise.resolve([])
    }
  }
}

export const audioDB = new AudioDB()
