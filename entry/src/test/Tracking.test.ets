import { describe, expect, it } from '@ohos/hypium'
import { TimeItem } from '../main/ets/models/HomeModels'
import {
  appendTrackingItem,
  resolveTrackingQueue,
  shouldUploadTrackingQueue
} from '../main/ets/common/utils/TrackingPolicy'

function createTimeItem(questionId: string): TimeItem {
  return {
    questionId: questionId,
    startTime: 100,
    endTime: 200
  }
}

export default function trackingTest() {
  describe('TrackingPolicyTest', () => {
    it('appendDoesNotMutateStoredQueue', 0, () => {
      const storedList: TimeItem[] = []
      const nextList = appendTrackingItem(storedList, createTimeItem('question-1'))

      expect(storedList.length).assertEqual(0)
      expect(nextList.length).assertEqual(1)
      expect(nextList[0].questionId).assertEqual('question-1')
    })

    it('uploadsOnlyAfterFiveRecords', 0, () => {
      const fourItems: TimeItem[] = [
        createTimeItem('1'),
        createTimeItem('2'),
        createTimeItem('3'),
        createTimeItem('4')
      ]
      const fiveItems = appendTrackingItem(fourItems, createTimeItem('5'))

      expect(shouldUploadTrackingQueue(fourItems)).assertEqual(false)
      expect(shouldUploadTrackingQueue(fiveItems)).assertEqual(true)
    })

    it('clearsQueueAfterUploadSuccess', 0, () => {
      const list: TimeItem[] = [createTimeItem('question-1')]
      const result = resolveTrackingQueue(list, true)

      expect(result.length).assertEqual(0)
    })

    it('keepsQueueAfterUploadFailure', 0, () => {
      const list: TimeItem[] = [createTimeItem('question-1')]
      const result = resolveTrackingQueue(list, false)

      expect(result.length).assertEqual(1)
      expect(result[0].questionId).assertEqual('question-1')
    })
  })
}
