import { describe, expect, it } from '@ohos/hypium'
import {
  everyDayOfWeek,
  ownedReminderNotification,
  plannedReminders,
  reminderRingDuration,
  reminderUsesInterruptiveSlot,
  REVIEW_NOTIFICATION_ID,
  storedReminderIds,
  STUDY_NOTIFICATION_ID,
  TEST_NOTIFICATION_ID
} from '../main/ets/common/utils/MessageReminderPolicy'

export default function messageReminderPolicyTest() {
  describe('MessageReminderPolicyTest', () => {
    it('schedulesNoRemindersWhenBothSwitchesAreOff', 0, () => {
      expect(plannedReminders(false, false).length).assertEqual(0)
    })

    it('schedulesEveningReviewToFavoritesAndStudyProgressToQuestionBank', 0, () => {
      const review = plannedReminders(true, false)
      expect(review.length).assertEqual(1)
      expect(review[0].hour).assertEqual(20)
      expect(review[0].minute).assertEqual(0)
      expect(review[0].notificationId).assertEqual(REVIEW_NOTIFICATION_ID)
      expect(review[0].studyCardAction).assertEqual('favorites')
      const study = plannedReminders(false, true)
      expect(study.length).assertEqual(1)
      expect(study[0].hour).assertEqual(21)
      expect(study[0].notificationId).assertEqual(STUDY_NOTIFICATION_ID)
      expect(study[0].studyCardAction).assertEqual('questions')
      expect(plannedReminders(true, true).length).assertEqual(2)
    })

    it('keepsTestNotificationIdSeparateFromScheduledReminders', 0, () => {
      expect(TEST_NOTIFICATION_ID === REVIEW_NOTIFICATION_ID).assertFalse()
      expect(ownedReminderNotification(REVIEW_NOTIFICATION_ID)).assertTrue()
      expect(ownedReminderNotification(STUDY_NOTIFICATION_ID)).assertTrue()
      expect(ownedReminderNotification(TEST_NOTIFICATION_ID)).assertFalse()
    })

    it('usesSilentRingAndNonInterruptiveSlotWhenSoundIsOff', 0, () => {
      expect(reminderRingDuration(true)).assertEqual(1)
      expect(reminderRingDuration(false)).assertEqual(0)
      expect(reminderUsesInterruptiveSlot(true)).assertTrue()
      expect(reminderUsesInterruptiveSlot(false)).assertFalse()
    })

    it('repeatsEveryLocalWeekdayAndDropsInvalidStoredIds', 0, () => {
      const days = everyDayOfWeek()
      expect(days.length).assertEqual(7)
      expect(days[0]).assertEqual(1)
      expect(days[6]).assertEqual(7)
      const ids = storedReminderIds([1, 0, -3, 8])
      expect(ids.length).assertEqual(2)
      expect(ids[0]).assertEqual(1)
      expect(ids[1]).assertEqual(8)
    })
  })
}
