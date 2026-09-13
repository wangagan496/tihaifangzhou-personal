import { auth } from '../../common/utils/Auth'
import { shareMineApp } from '../../common/utils/MineShare'
import { common } from '@kit.AbilityKit'

interface MineToolItem {
  icon: ResourceStr
  name: string
  id?: string
  onClick?: () => void
}

@Component
export struct MineToolsList {
  private openWords(): void {
    auth.checkAuth({ url: 'pages/WordPage' })
  }

  private openAudio(): void {
    auth.checkAuth({ url: 'pages/AudioPage' })
  }

  private openFeedback(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MineFeedbackPage' })
  }

  private openAbout(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MineAboutPage' })
  }

  private openSettings(): void {
    auth.checkAuth({ url: 'pages/SettingsPage' })
  }

  private async shareApp(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!await shareMineApp(context)) {
      this.getUIContext().getPromptAction().showToast({ message: '暂时无法打开分享面板' })
    }
  }

  @Builder
  toolBuilder(tool: MineToolItem) {
    Row() {
      Image(tool.icon)
        .width(16)
        .aspectRatio(1)
        .margin({ right: 12 })
      Text(tool.name)
        .fontSize(14)
        .fontColor($r('app.color.common_gray_03'))
      Blank()
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(16)
        .aspectRatio(1)
        .fillColor($r('app.color.common_gray_01'))
    }
    .height(50)
    .width('100%')
    .padding({ left: 16, right: 10 })
    .id(tool.id || `mineTool_${tool.name}`)
    .onClick(() => tool.onClick && tool.onClick())
  }

  build() {
    Column() {
      this.toolBuilder({
        icon: $r('app.media.ic_mine_notes'), name: '前端常用词', onClick: () => this.openWords()
      })
      this.toolBuilder({
        icon: $r('app.media.ic_mine_ai'), name: '面试录音', onClick: () => this.openAudio()
      })
      this.toolBuilder({
        icon: $r('app.media.ic_mine_invite'), name: '推荐分享', id: 'mineShareButton', onClick: () => this.shareApp()
      })
      this.toolBuilder({
        icon: $r('app.media.ic_mine_file'), name: '意见反馈', onClick: () => this.openFeedback()
      })
      this.toolBuilder({
        icon: $r('app.media.ic_mine_info'), name: '关于我们', onClick: () => this.openAbout()
      })
      this.toolBuilder({
        icon: $r('app.media.ic_mine_setting'), name: '设置', onClick: () => this.openSettings()
      })
    }
    .backgroundColor($r('app.color.white'))
    .borderRadius(8)
  }
}
