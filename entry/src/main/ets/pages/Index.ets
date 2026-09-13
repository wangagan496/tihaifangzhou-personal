import { contextManager } from '../common/utils/ContextManager'
import { windowManager } from '../common/utils/WindowManager'


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
        Text('题海方舟 · 基础框架')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.black'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      Column({ space: 16 }) {
        Text('框架已启动')
          .fontSize(20)
          .fontColor($r('app.color.black'))
        Text('已保留启动生命周期、主题、安全区与通用组件。切换功能分支开始学习，切换 full 查看完整应用。')
          .fontSize(16)
          .fontColor($r('app.color.common_gray_03'))
          .lineHeight(26)
      }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
      Blank()
    }
    .padding({ top: this.topHeight + 12, bottom: this.bottomHeight + 12 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.white'))
  }
}
