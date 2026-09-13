import { relationalStore, ValuesBucket } from '@kit.ArkData'

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

  // RDB 只保存录音元数据；实际 m4a 文件保留在应用沙箱。
  initStore(): Promise<boolean> {
    if (this.initialized && this.store) {
      return Promise.resolve(true)
    }
    const context = AppStorage.get<Context>('context')
    if (!context) {
      return Promise.resolve(false)
    }
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
  }

  insert(item: InterviewAudioItem): Promise<boolean> {
    if (!this.store) {
      return Promise.resolve(false)
    }
    return this.store.insert(this.tableName, item).then((id): boolean => id !== -1, (): boolean => false)
  }

  delete(id: number): Promise<boolean> {
    if (!this.store) {
      return Promise.resolve(false)
    }
    const predicates = new relationalStore.RdbPredicates(this.tableName)
    predicates.equalTo('id', id)
    return this.store.delete(predicates).then((count): boolean => count > 0, (): boolean => false)
  }

  update(item: InterviewAudioItem): Promise<boolean> {
    if (!this.store || item.id === null) {
      return Promise.resolve(false)
    }
    const predicates = new relationalStore.RdbPredicates(this.tableName)
    predicates.equalTo('id', item.id)
    return this.store.update(item, predicates).then((count): boolean => count > 0, (): boolean => false)
  }

  // 查询始终带 user_id 条件，避免切换账号后读取到别人的录音。
  query(userId: string): Promise<InterviewAudioItem[]> {
    if (!this.store || !userId) {
      return Promise.resolve([])
    }
    const predicates = new relationalStore.RdbPredicates(this.tableName)
    predicates.equalTo('user_id', userId).orderByDesc('create_time')
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
  }
}

export const audioDB = new AudioDB()
