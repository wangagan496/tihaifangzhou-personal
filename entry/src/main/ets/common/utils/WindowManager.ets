import { window } from '@kit.ArkUI'
import { contextManager } from './ContextManager'

class WindowManager {
  async enableFullScreen(): Promise<void> {
    const context = contextManager.getCtx()
    const uiContext = contextManager.getUiCtx()
    if (!context || !uiContext) {
      return Promise.resolve()
    }
    try {
      const win = await window.getLastWindow(context)
      await win.setWindowLayoutFullScreen(true)
      const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      AppStorage.setOrCreate('topHeight', uiContext.px2vp(systemArea.topRect.height))
    } catch (_) {
      AppStorage.setOrCreate('topHeight', 0)
    }
  }

  async disableFullScreen(): Promise<void> {
    const context = contextManager.getCtx()
    if (!context) {
      AppStorage.setOrCreate('topHeight', 0)
      return Promise.resolve()
    }
    try {
      const win = await window.getLastWindow(context)
      await win.setWindowLayoutFullScreen(false)
    } catch (_) {
      // The stored inset is still reset when no active window is available.
    } finally {
      AppStorage.setOrCreate('topHeight', 0)
    }
  }

  async setStatusBarLight(): Promise<void> {
    await this.setStatusBarContentColor('#ffffff')
  }

  async setStatusBarDark(): Promise<void> {
    await this.setStatusBarContentColor('#000000')
  }

  private async setStatusBarContentColor(color: string): Promise<void> {
    const context = contextManager.getCtx()
    if (!context) {
      return Promise.resolve()
    }
    try {
      const win = await window.getLastWindow(context)
      await win.setWindowSystemBarProperties({ statusBarContentColor: color })
    } catch (_) {
      return
    }
  }
}

export const windowManager = new WindowManager()
