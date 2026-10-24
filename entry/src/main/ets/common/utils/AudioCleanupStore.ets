import { fileIo } from '@kit.CoreFileKit'
import { preferences } from '@kit.ArkData'
import { appendPendingCleanup } from './AudioCleanupPolicy'
import { contextManager } from './ContextManager'

const STORE_NAME: string = 'audioCleanup'
const PATHS_KEY: string = 'paths'

class AudioCleanupStore {
  private getFile(): preferences.Preferences | undefined {
    const context = contextManager.getCtx()
    if (!context) { return undefined }
    try {
      return preferences.getPreferencesSync(context, { name: STORE_NAME })
    } catch (_) {
      return undefined
    }
  }

  private readPaths(file: preferences.Preferences): string[] {
    const raw = file.getSync(PATHS_KEY, []) as string[]
    if (!Array.isArray(raw)) { return [] }
    const paths: string[] = []
    for (let i = 0; i < raw.length; i++) {
      const path = raw[i]
      if (typeof path === 'string' && path.trim()) { paths.push(path) }
    }
    return paths
  }

  private persist(file: preferences.Preferences, paths: string[]): boolean {
    try {
      file.putSync(PATHS_KEY, paths)
      file.flushSync()
      return true
    } catch (_) {
      return false
    }
  }

  enqueue(path: string): boolean {
    const file = this.getFile()
    if (!file) { return false }
    try {
      return this.persist(file, appendPendingCleanup(this.readPaths(file), path))
    } catch (_) {
      return false
    }
  }

  drain(): void {
    const file = this.getFile()
    if (!file) { return }
    const paths = this.readPaths(file)
    if (paths.length === 0) { return }
    const failed: string[] = []
    for (let i = 0; i < paths.length; i++) {
      const path = paths[i]
      try {
        if (fileIo.accessSync(path)) { fileIo.unlinkSync(path) }
      } catch (_) {
        failed.push(path)
      }
    }
    if (failed.length !== paths.length) { this.persist(file, failed) }
  }
}

export const audioCleanupStore = new AudioCleanupStore()
