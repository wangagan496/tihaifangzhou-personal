import { common } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { vibrator } from '@kit.SensorServiceKit'
import { contextManager } from './ContextManager'
import {
  everyDayOfWeek,
  ownedReminderNotification,
  plannedReminders,
  ReminderPlan,
  reminderRingDuration,
  reminderUsesInterruptiveSlot,
  TEST_NOTIFICATION_ID
} from './MessageReminderPolicy'
import { MessageSettings, messageSettingsStore } from './MessageSettingsStore'

class MessageReminderService {
  private pending: Promise<void> = Promise.resolve()

  apply(settings: MessageSettings): Promise<boolean> {
    const run = this.pending.then(() => this.applyLocked(settings))
    this.pending = run.then((): void => {}, (): void => {})
    return run
  }

  syncFromStore(): Promise<boolean> {
    return this.apply(messageSettingsStore.load())
  }

  async publishTest(settings: MessageSettings, context: common.UIAbilityContext): Promise<boolean> {
    try {
      if (!await this.notificationsAllowed()) {
        await notificationManager.requestEnableNotification(context)
      }
      await this.ensureSlot(settings.soundAndVibration)
      const request: notificationManager.NotificationRequest = {
        id: TEST_NOTIFICATION_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '题海方舟',
            text: '通知设置已生效，继续保持今天的学习节奏。'
          }
        },
        tapDismissed: true
      }
      await notificationManager.publish(request)
      if (settings.soundAndVibration) {
        try {
          await vibrator.startVibration({ type: 'time', duration: 200 }, { id: 0, usage: 'notification' })
        } catch (_) {
          // Vibration is optional; the visible notification is the required result.
        }
      }
      return await this.notificationsAllowed()
    } catch (_) {
      return false
    }
  }

  private async applyLocked(settings: MessageSettings): Promise<boolean> {
    const context = contextManager.getCtx() as common.UIAbilityContext | null
    if (!context) {
      return false
    }
    await this.cancelOwned()
    const plans = plannedReminders(settings.reviewReminder, settings.studyProgress)
    if (plans.length === 0) {
      return true
    }
    if (!await this.notificationsAllowed()) {
      return false
    }
    await this.ensureSlot(settings.soundAndVibration)
    const ids: number[] = []
    try {
      for (let i = 0; i < plans.length; i++) {
        ids.push(await reminderAgentManager.publishReminder(this.toAlarm(plans[i], settings.soundAndVibration, context)))
      }
      return messageSettingsStore.saveReminderIds(ids)
    } catch (_) {
      messageSettingsStore.saveReminderIds(ids)
      return false
    }
  }

  private toAlarm(plan: ReminderPlan, soundAndVibration: boolean,
    context: common.UIAbilityContext): reminderAgentManager.ReminderRequestAlarm {
    const request: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour: plan.hour,
      minute: plan.minute,
      daysOfWeek: everyDayOfWeek(),
      title: plan.title,
      content: plan.content,
      notificationId: plan.notificationId,
      ringDuration: reminderRingDuration(soundAndVibration),
      tapDismissed: true,
      wantAgent: {
        pkgName: context.abilityInfo.bundleName,
        abilityName: 'EntryAbility',
        parameters: { 'studyCardAction': plan.studyCardAction }
      }
    }
    if (reminderUsesInterruptiveSlot(soundAndVibration)) {
      request.slotType = notificationManager.SlotType.SOCIAL_COMMUNICATION
    } else {
      request.slotType = notificationManager.SlotType.CONTENT_INFORMATION
    }
    return request
  }

  private async cancelOwned(): Promise<void> {
    const stored = messageSettingsStore.loadReminderIds()
    for (let i = 0; i < stored.length; i++) {
      try {
        await reminderAgentManager.cancelReminder(stored[i])
      } catch (_) {
        // The stored instance may already have been cleared by the system.
      }
    }
    try {
      const valid = await reminderAgentManager.getAllValidReminders()
      for (let i = 0; i < valid.length; i++) {
        const info = valid[i]
        if (typeof info.reminderReq.notificationId === 'number' &&
          ownedReminderNotification(info.reminderReq.notificationId)) {
          try {
            await reminderAgentManager.cancelReminder(info.reminderId)
          } catch (_) {
            // Continue cancelling remaining owned reminders.
          }
        }
      }
    } catch (_) {
      // Listing current reminders is best-effort cleanup after a restart.
    }
    messageSettingsStore.saveReminderIds([])
  }

  private async notificationsAllowed(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled()
    } catch (_) {
      return false
    }
  }

  private async ensureSlot(soundAndVibration: boolean): Promise<void> {
    const slot = reminderUsesInterruptiveSlot(soundAndVibration) ?
      notificationManager.SlotType.SOCIAL_COMMUNICATION :
      notificationManager.SlotType.CONTENT_INFORMATION
    try {
      await notificationManager.addSlot(slot)
    } catch (_) {
      // The slot may already exist.
    }
  }
}

export const messageReminderService = new MessageReminderService()
