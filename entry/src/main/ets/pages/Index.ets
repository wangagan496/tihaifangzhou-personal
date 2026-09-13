import { contextManager } from '../common/utils/ContextManager'
import { windowManager } from '../common/utils/WindowManager'
import { auth } from '../common/utils/Auth'
import { HomeCategoryComp } from '../views/home/HomeCategoryComp'

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
        Text('学习记录')
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
      Column() {
        Column({ space: 8 }) {
          Button('历史记录')
            .height(44)
            .width('100%')
            .fontSize(16)
            .onClick(() => {
              auth.checkAuth({ url: 'pages/MineQuestionsPage', params: { mode: 'history' } })
            })

          Button('我的收藏')
            .height(44)
            .width('100%')
            .fontSize(16)
            .onClick(() => {
              auth.checkAuth({ url: 'pages/MineQuestionsPage', params: { mode: 'collect' } })
            })

          Button('我的点赞')
            .height(44)
            .width('100%')
            .fontSize(16)
            .onClick(() => {
              auth.checkAuth({ url: 'pages/MineQuestionsPage', params: { mode: 'like' } })
            })
        }.width('100%').padding({ left: 16, right: 16 })
      }
      HomeCategoryComp().layoutWeight(1)
    }
    .padding({ top: this.topHeight + 12, bottom: this.bottomHeight + 12 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.white'))
  }
}
