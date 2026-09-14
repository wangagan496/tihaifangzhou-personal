import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'
import {
  addMineQuestion,
  MineQuestionRecord,
  setMineQuestionFlag
} from './MineQuestionPolicy'
import { recordsClient } from './RecordsClient'

export type MineQuestionKind = 'history' | 'collect' | 'like'

class MineQuestionStore {
  private key(kind: MineQuestionKind, userId: string): string {
    return `mine_${kind}_${userId}`
  }

  private read(kind: MineQuestionKind, userId: string): MineQuestionRecord[] {
    const context = contextManager.getCtx()
    if (!context || !userId) {
      return []
    }
    try {
      const file = preferences.getPreferencesSync(context, { name: 'mineQuestions' })
      return file.getSync(this.key(kind, userId), []) as MineQuestionRecord[]
    } catch (_) {
      return []
    }
  }

  private write(kind: MineQuestionKind, userId: string, list: MineQuestionRecord[]): void {
    const context = contextManager.getCtx()
    if (!context || !userId) {
      return
    }
    try {
      const file = preferences.getPreferencesSync(context, { name: 'mineQuestions' })
      file.putSync(this.key(kind, userId), list)
      file.flushSync()
    } catch (_) {
      // 本地记录失败不影响题目主流程。
    }
  }

  list(kind: MineQuestionKind, userId: string): MineQuestionRecord[] {
    return this.read(kind, userId)
  }

  recordHistory(userId: string, item: MineQuestionRecord): void {
    this.write('history', userId, addMineQuestion(this.read('history', userId), item))
    recordsClient.put('history', userId, item).then((): void => {}, (): void => {})
  }

  setFlag(kind: 'collect' | 'like', userId: string, item: MineQuestionRecord, enabled: boolean): void {
    this.write(kind, userId, setMineQuestionFlag(this.read(kind, userId), item, enabled))
    if (enabled) {
      recordsClient.put(kind, userId, item).then((): void => {}, (): void => {})
    } else {
      recordsClient.remove(kind, userId, item).then((): void => {}, (): void => {})
    }
  }

  pull(userId: string): Promise<void> {
    if (!userId) { return Promise.resolve() }
    const kinds: MineQuestionKind[] = ['history', 'collect', 'like']
    return Promise.all(kinds.map((kind: MineQuestionKind) => recordsClient.pull(kind, userId).then((list) => {
      if (list) { this.write(kind, userId, list) }
    }, (): void => {}))).then((): void => {}, (): void => {})
  }
}

export const mineQuestionStore = new MineQuestionStore()
