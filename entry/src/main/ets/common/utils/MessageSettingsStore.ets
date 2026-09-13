import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'

export interface MessageSettings {
  studyProgress: boolean
  reviewReminder: boolean
  featureUpdates: boolean
  soundAndVibration: boolean
}

export type MessageSettingKey = keyof MessageSettings

const DEFAULT_SETTINGS: MessageSettings = {
  studyProgress: true,
  reviewReminder: true,
  featureUpdates: false,
  soundAndVibration: true
}

class MessageSettingsStore {
  load(): MessageSettings {
    const context = contextManager.getCtx()
    if (!context) {
      return DEFAULT_SETTINGS
    }
    try {
      const file = preferences.getPreferencesSync(context, { name: 'messageSettings' })
      return {
        studyProgress: file.getSync('studyProgress', DEFAULT_SETTINGS.studyProgress) as boolean,
        reviewReminder: file.getSync('reviewReminder', DEFAULT_SETTINGS.reviewReminder) as boolean,
        featureUpdates: file.getSync('featureUpdates', DEFAULT_SETTINGS.featureUpdates) as boolean,
        soundAndVibration: file.getSync('soundAndVibration', DEFAULT_SETTINGS.soundAndVibration) as boolean
      }
    } catch (_) {
      return DEFAULT_SETTINGS
    }
  }

  save(key: MessageSettingKey, enabled: boolean): boolean {
    const context = contextManager.getCtx()
    if (!context) {
      return false
    }
    try {
      const file = preferences.getPreferencesSync(context, { name: 'messageSettings' })
      file.putSync(key, enabled)
      file.flushSync()
      return true
    } catch (_) {
      return false
    }
  }
}

export const messageSettingsStore = new MessageSettingsStore()
