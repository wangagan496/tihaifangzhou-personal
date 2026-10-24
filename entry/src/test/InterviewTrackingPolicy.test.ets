import { describe, expect, it } from '@ohos/hypium'
import {
  appendPendingInterviewTracking,
  firstPendingForOwner,
  removePendingInterviewTrackingById,
  PendingInterviewTracking,
  shouldDiscardFailedInterviewTracking
} from '../main/ets/common/utils/InterviewTrackingPolicy'

function item(id: string, ownerId: string, questionNo: string): PendingInterviewTracking {
  return { id, ownerId, questionNo, stayTime: 3, exp: true }
}

export default function interviewTrackingPolicyTest() {
  describe('InterviewTrackingPolicyTest', () => {
    it('keepsEventsSeparatedByOwner', 0, () => {
      const list: PendingInterviewTracking[] = [item('id-a', 'user-a', 'a-1'), item('id-b', 'user-b', 'b-1')]

      expect(firstPendingForOwner(list, 'user-b')?.questionNo).assertEqual('b-1')
      const remaining = removePendingInterviewTrackingById(list, 'id-b')
      expect(remaining.length).assertEqual(1)
      expect(remaining[0].ownerId).assertEqual('user-a')
    })

    it('rejectsInvalidEventsWithoutChangingQueue', 0, () => {
      const list: PendingInterviewTracking[] = [item('id-a', 'user-a', 'a-1')]

      const next = appendPendingInterviewTracking(list, { id: 'id-b', ownerId: '', questionNo: '', stayTime: 0, exp: false })
      expect(next.length).assertEqual(1)
      expect(next[0].questionNo).assertEqual('a-1')
    })

    it('removesOnlyTheSentIdAfterTheQueueChanges', 0, () => {
      const sent = item('sent-id', 'user-a', 'same-question')
      const duplicate = item('duplicate-id', 'user-a', 'same-question')
      const unrelated = item('other-id', 'user-b', 'b-1')
      const current: PendingInterviewTracking[] = [duplicate, unrelated, sent]

      const remaining = removePendingInterviewTrackingById(current, sent.id)

      expect(remaining.length).assertEqual(2)
      expect(remaining[0].id).assertEqual('duplicate-id')
      expect(remaining[0].questionNo).assertEqual(sent.questionNo)
      expect(remaining[1].id).assertEqual('other-id')
    })

    it('keepsTheQueueUnchangedWhenTheSentEventWasClipped', 0, () => {
      const clippedQueue: PendingInterviewTracking[] = [
        item('newer-id', 'user-a', 'newer-question'), item('other-id', 'user-b', 'b-1')
      ]

      const remaining = removePendingInterviewTrackingById(clippedQueue, 'already-clipped-id')

      expect(remaining.length).assertEqual(2)
      expect(remaining[0].id).assertEqual('newer-id')
      expect(remaining[1].id).assertEqual('other-id')
    })

    it('drainsOwnerEventsUntilNoMatchingEventRemains', 0, () => {
      const list: PendingInterviewTracking[] = [item('id-a', 'user-a', 'a-1'),
        item('id-b', 'user-b', 'b-1'), item('id-c', 'user-a', 'a-2')]
      const first = firstPendingForOwner(list, 'user-a')
      const afterFirst = first ? removePendingInterviewTrackingById(list, first.id) : list
      const next = firstPendingForOwner(afterFirst, 'user-a')
      const afterSecond = next ? removePendingInterviewTrackingById(afterFirst, next.id) : afterFirst

      expect(afterSecond.length).assertEqual(1)
      expect(firstPendingForOwner(afterSecond, 'user-a')).assertEqual(undefined)
      expect(firstPendingForOwner(afterSecond, 'user-b')?.questionNo).assertEqual('b-1')
    })

    it('discardsAndContinuesAfterBusinessRejection', 0, () => {
      expect(shouldDiscardFailedInterviewTracking({ businessCode: 40001 })).assertEqual(true)
    })

    it('retainsEventAndStopsAfterNetworkFailure', 0, () => {
      expect(shouldDiscardFailedInterviewTracking({})).assertEqual(false)
    })

    it('retainsEventAndStopsAfterUnauthorizedResponse', 0, () => {
      expect(shouldDiscardFailedInterviewTracking({ httpStatus: 401, businessCode: 40001 })).assertEqual(false)
    })
  })
}
