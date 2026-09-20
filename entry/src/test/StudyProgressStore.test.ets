import { describe, expect, it } from '@ohos/hypium'
import { StudyProgressStorage, StudyProgressStore } from '../main/ets/common/utils/StudyProgressStore'
import { addMineQuestion, MineQuestionRecord } from '../main/ets/common/utils/MineQuestionPolicy'

class MemoryProgressStorage implements StudyProgressStorage {
  values: Map<string, string[]> = new Map<string, string[]>()
  failReads: boolean = false
  failWrites: boolean = false

  readIds(key: string): string[] {
    if (this.failReads) { throw new Error('Read failed') }
    return (this.values.get(key) || []).slice()
  }

  writeIds(key: string, ids: string[]): void {
    if (this.failWrites) { throw new Error('Write failed') }
    this.values.set(key, ids.slice())
  }
}

export default function studyProgressStoreTest() {
  describe('StudyProgressStoreTest', () => {
    it('keepsLegacyVisitsButDoesNotCountThemAsCompleted', 0, () => {
      const storage = new MemoryProgressStorage()
      storage.values.set('ids:alice:10:42', ['old-question'])
      const store = new StudyProgressStore(storage)
      expect(store.rememberQuestion('alice', 42, 10, 'new-question')).assertTrue()
      expect(store.getDone('alice', '42', 10, 100)).assertEqual(0)
      expect(store.isCompleted('alice', 'old-question')).assertFalse()
      expect(storage.readIds('ids:alice:10:42').length).assertEqual(2)
    })

    it('countsOnlyExplicitCompletionAndSupportsIdempotentMarkAndUndo', 0, () => {
      const store = new StudyProgressStore(new MemoryProgressStorage())
      store.rememberQuestion('alice', 42, 10, 'q1')
      store.rememberQuestion('alice', 42, 10, 'q2')
      expect(store.setCompleted('alice', 'q1', true)).assertTrue()
      expect(store.setCompleted('alice', 'q1', true)).assertTrue()
      expect(store.getDone('alice', '42', 10, 100)).assertEqual(1)
      expect(store.isCompleted('alice', 'q2')).assertFalse()
      expect(store.setCompleted('alice', 'q1', false)).assertTrue()
      expect(store.setCompleted('alice', 'q1', false)).assertTrue()
      expect(store.getDone('alice', '42', 10, 100)).assertEqual(0)
    })

    it('isolatesUsersAndAggregatesOnlyMatchingCategoryAndBank', 0, () => {
      const store = new StudyProgressStore(new MemoryProgressStorage())
      store.rememberQuestion('alice', 42, 10, 'q1')
      store.rememberQuestion('bob', 42, 10, 'q1')
      store.rememberQuestion('alice', 43, 10, 'q2')
      store.rememberQuestion('alice', 42, 20, 'q3')
      store.setCompleted('alice', 'q1', true)
      expect(store.getDone('alice', '42', 10, 100)).assertEqual(1)
      expect(store.getDone('bob', '42', 10, 100)).assertEqual(0)
      expect(store.getDone('alice', '43', 10, 100)).assertEqual(0)
      expect(store.getDone('alice', '42', 20, 100)).assertEqual(0)
      expect(store.isCompleted('bob', 'q1')).assertFalse()
    })

    it('restoresCompletionWithoutCategoryParamsAndAggregatesWhenCategoryIsKnown', 0, () => {
      const storage = new MemoryProgressStorage()
      const first = new StudyProgressStore(storage)
      expect(first.setCompleted('alice', 'history-question', true)).assertTrue()
      const reopened = new StudyProgressStore(storage)
      expect(reopened.isCompleted('alice', 'history-question')).assertTrue()
      expect(reopened.getDone('alice', '42', 10, 100)).assertEqual(0)
      reopened.rememberQuestion('alice', 42, 10, 'history-question')
      expect(reopened.getDone('alice', '42', 10, 100)).assertEqual(1)
      expect(reopened.setCompleted('alice', 'history-question', false)).assertTrue()
      expect(first.isCompleted('alice', 'history-question')).assertFalse()
    })

    it('doesNotLoseCompletionsWhenHistoryTrimsOlderItems', 0, () => {
      const store = new StudyProgressStore(new MemoryProgressStorage())
      let history: MineQuestionRecord[] = []
      for (let index = 0; index < 60; index++) {
        const id = `question-${index}`
        const item: MineQuestionRecord = {
          id, stem: id, difficulty: 1, likeCount: 0, views: 0, readFlag: 1, contentType: 0
        }
        history = addMineQuestion(history, item)
        store.rememberQuestion('alice', 42, 10, id)
        store.setCompleted('alice', id, true)
      }
      expect(history.length).assertEqual(50)
      expect(store.getDone('alice', '42', 10, 100)).assertEqual(60)
      expect(store.isCompleted('alice', 'question-0')).assertTrue()
    })

    it('doesNotReportSuccessOrOverwriteCompletionsWhenStorageFails', 0, () => {
      const storage = new MemoryProgressStorage()
      const store = new StudyProgressStore(storage)
      store.setCompleted('alice', 'q1', true)
      storage.failWrites = true
      expect(store.setCompleted('alice', 'q1', false)).assertFalse()
      expect(store.setCompleted('alice', 'q2', true)).assertFalse()
      expect(store.isCompleted('alice', 'q1')).assertTrue()
      storage.failReads = true
      expect(store.isCompleted('alice', 'q1')).assertUndefined()
      expect(store.setCompleted('alice', 'q3', true)).assertFalse()
      storage.failReads = false
      expect(store.isCompleted('alice', 'q3')).assertFalse()
    })

    it('rejectsInvalidInputsAndCapsCountsWithoutCountingDuplicateIds', 0, () => {
      const storage = new MemoryProgressStorage()
      const store = new StudyProgressStore(storage)
      expect(store.setCompleted(undefined, 'q1', true)).assertFalse()
      expect(store.setCompleted('alice', '', true)).assertFalse()
      expect(store.rememberQuestion('alice', undefined, 10, 'q1')).assertFalse()
      expect(store.rememberQuestion('alice', -1, 10, 'q1')).assertFalse()
      storage.values.set('ids:alice:10:42', ['q1', 'q1', 'q2'])
      store.setCompleted('alice', 'q1', true)
      store.setCompleted('alice', 'q2', true)
      expect(store.getDone('alice', '42', 10, 100)).assertEqual(2)
      expect(store.getDone('alice', '42', 10, 1)).assertEqual(1)
      expect(store.getDone('alice', 'invalid', 10, 100)).assertEqual(0)
      expect(store.getDone('alice', '42', 10, Number.NaN)).assertEqual(0)
    })
  })
}
