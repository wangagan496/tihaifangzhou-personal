import { preferences } from '@kit.ArkData'
import { contextManager } from './ContextManager'

export interface StoredFeedback {
  content: string
  time: number
  delivered: boolean
}

const MAX_HISTORY: number = 20

class MineFeedbackStore {
  save(content: string, delivered: boolean): boolean {
    const context = contextManager.getCtx()
    if (!context) {
      return false
    }
    try {
      const file = preferences.getPreferencesSync(context, { name: 'feedback' })
      file.putSync('lastFeedback', content)
      const history = this.readHistory(file)
      history.unshift({ content, time: Date.now(), delivered })
      file.putSync('history', history.slice(0, MAX_HISTORY))
      file.flushSync()
      return true
    } catch (_) {
      return false
    }
  }

  list(): StoredFeedback[] {
    const context = contextManager.getCtx()
    if (!context) {
      return []
    }
    try {
      const file = preferences.getPreferencesSync(context, { name: 'feedback' })
      return this.readHistory(file)
    } catch (_) {
      return []
    }
  }

  private readHistory(file: preferences.Preferences): StoredFeedback[] {
    const raw = file.getSync('history', []) as StoredFeedback[]
    if (!Array.isArray(raw)) {
      return []
    }
    const items: StoredFeedback[] = []
    for (let i = 0; i < raw.length; i++) {
      const item = raw[i]
      if (item && typeof item.content === 'string' && typeof item.time === 'number' && typeof item.delivered === 'boolean') {
        items.push(item)
      }
    }
    return items
  }
}

export const mineFeedbackStore = new MineFeedbackStore()
