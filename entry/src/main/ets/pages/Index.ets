import { contextManager } from '../common/utils/ContextManager'
import { windowManager } from '../common/utils/WindowManager'
import { auth } from '../common/utils/Auth'

auth.initUser()

@Entry
@Component
struct Index {
  @StorageProp('topHeight') topHeight: number = 0
  @StorageProp('bottomHeight') bottomHeight: number = 0

  aboutToAppear(): void {
    contextManager.ctx = this.getUIContext().getHostContext()!
    contextManager.UiCtx = this.getUIContext()
    windowManager.enableFullScreen()
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Text('登录与鉴权')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.black'))
          .layoutWeight(1)
        Button('账号')
          .height(40)
          .width(72)
          .onClick(() => auth.checkAuth({ url: 'pages/AccountSettingsPage' }))
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      Scroll() {
        Column({ space: 8 }) {
          Button('登录')
            .height(44)
            .width('100%')
            .fontSize(16)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' })
            })

          Button('账号与退出登录')
            .height(44)
            .width('100%')
            .fontSize(16)
            .onClick(() => {
              auth.checkAuth({ url: 'pages/AccountSettingsPage' })
            })
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).align(Alignment.Top)
    }
    .padding({ top: this.topHeight + 12, bottom: this.bottomHeight + 12 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.white'))
  }
}
