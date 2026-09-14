export type ReminderKind = 'review' | 'studyProgress'

export interface ReminderPlan {
  kind: ReminderKind
  hour: number
  minute: number
  notificationId: number
  title: string
  content: string
  studyCardAction: string
}

export const TEST_NOTIFICATION_ID: number = 260816
export const REVIEW_NOTIFICATION_ID: number = 260817
export const STUDY_NOTIFICATION_ID: number = 260818

export function plannedReminders(reviewReminder: boolean, studyProgress: boolean): ReminderPlan[] {
  const plans: ReminderPlan[] = []
  if (reviewReminder) {
    plans.push({
      kind: 'review',
      hour: 20,
      minute: 0,
      notificationId: REVIEW_NOTIFICATION_ID,
      title: '复习提醒',
      content: '打开收藏和历史题目，回顾还没消化的内容。',
      studyCardAction: 'favorites'
    })
  }
  if (studyProgress) {
    plans.push({
      kind: 'studyProgress',
      hour: 21,
      minute: 0,
      notificationId: STUDY_NOTIFICATION_ID,
      title: '学习进度',
      content: '看一眼今天的学习时长，保持连续学习节奏。',
      studyCardAction: 'questions'
    })
  }
  return plans
}

export function reminderRingDuration(soundAndVibration: boolean): number {
  return soundAndVibration ? 1 : 0
}

export function reminderUsesInterruptiveSlot(soundAndVibration: boolean): boolean {
  return soundAndVibration
}

export function everyDayOfWeek(): number[] {
  return [1, 2, 3, 4, 5, 6, 7]
}

export function ownedReminderNotification(id: number): boolean {
  return id === REVIEW_NOTIFICATION_ID || id === STUDY_NOTIFICATION_ID
}

export function storedReminderIds(raw: number[]): number[] {
  const ids: number[] = []
  for (let i = 0; i < raw.length; i++) {
    const id = raw[i]
    if (typeof id === 'number' && Number.isInteger(id) && id > 0) {
      ids.push(id)
    }
  }
  return ids
}
