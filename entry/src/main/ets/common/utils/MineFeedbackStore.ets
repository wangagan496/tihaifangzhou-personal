import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'

class MineFeedbackStore {
  save(content: string): boolean {
    const context = contextManager.getCtx()
    if (!context) {
      return false
    }
    try {
      const file = preferences.getPreferencesSync(context, { name: 'feedback' })
      file.putSync('lastFeedback', content)
      file.flushSync()
      return true
    } catch (_) {
      return false
    }
  }
}

export const mineFeedbackStore = new MineFeedbackStore()
