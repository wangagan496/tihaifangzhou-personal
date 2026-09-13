import { window } from '@kit.ArkUI'
import { contextManager } from './ContextManager'

class WindowManager {
  enableFullScreen(): Promise<void> {
    const context = contextManager.getCtx()
    const uiContext = contextManager.getUiCtx()
    if (!context || !uiContext) {
      return Promise.resolve()
    }
    return window.getLastWindow(context).then((win): Promise<void> => {
      return win.setWindowLayoutFullScreen(true).then((): void => {
      const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      AppStorage.setOrCreate('topHeight', uiContext.px2vp(systemArea.topRect.height))
      })
    }, (): void => {
      AppStorage.setOrCreate('topHeight', 0)
    }).then((): void => {}, (): void => { AppStorage.setOrCreate('topHeight', 0) })
  }

  disableFullScreen(): Promise<void> {
    const context = contextManager.getCtx()
    if (!context) {
      AppStorage.setOrCreate('topHeight', 0)
      return Promise.resolve()
    }
    return window.getLastWindow(context).then((win): Promise<void> => win.setWindowLayoutFullScreen(false), (): void => {}).then((): void => {
      AppStorage.setOrCreate('topHeight', 0)
    }, (): void => { AppStorage.setOrCreate('topHeight', 0) })
  }

  async setStatusBarLight(): Promise<void> {
    await this.setStatusBarContentColor('#ffffff')
  }

  async setStatusBarDark(): Promise<void> {
    await this.setStatusBarContentColor('#000000')
  }

  private setStatusBarContentColor(color: string): Promise<void> {
    const context = contextManager.getCtx()
    if (!context) {
      return Promise.resolve()
    }
    return window.getLastWindow(context).then((win): Promise<void> => win.setWindowSystemBarProperties({ statusBarContentColor: color }), (): void => {}).then((): void => {}, (): void => {})
  }
}

export const windowManager = new WindowManager()
