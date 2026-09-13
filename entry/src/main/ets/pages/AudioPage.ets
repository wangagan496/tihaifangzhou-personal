import { permission } from '../common/utils/Permission'
import { promptAction } from '@kit.ArkUI'
import { Permissions } from '@kit.AbilityKit'
import { AudioView } from '../views/AudioPage/AudioView'
import { windowManager } from '../common/utils/WindowManager'

@Entry
@Component
struct AudioPage {
  @State permissionReady: boolean = false
  permissions: Permissions[] = ['ohos.permission.MICROPHONE']
  confirmConfig: promptAction.ShowDialogOptions = {
    title: '温馨提示',
    message: '未授权使用麦克风将无法使用面试录音功能，是否前往设置进行授权？',
    buttons: [
      { text: '离开', color: $r('app.color.common_gray_01') },
      { text: '去授权', color: $r('app.color.common_blue') }
    ]
  }

  // 麦克风属于敏感能力：运行时授权失败就不初始化录音组件。
  getPermission(): void {
    this.permissionReady = false
    permission.requestPermissions(this.permissions).then((isGranted) => {
      if (isGranted) {
        this.permissionReady = true
        return
      }
      this.getUIContext().getPromptAction().showDialog(this.confirmConfig).then((result) => {
        if (result.index !== 1) {
          this.backToPreviousPage()
          return
        }
        permission.onSettingPermissions(this.permissions).then((grantedInSettings) => {
          this.permissionReady = grantedInSettings
          if (!grantedInSettings) {
            this.backToPreviousPage()
          }
        }, () => this.backToPreviousPage())
      }, () => this.backToPreviousPage())
    }, () => this.backToPreviousPage())
  }

  private backToPreviousPage(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: '麦克风授权失败' })
      this.getUIContext().getRouter().back()
    } catch (_) {
      return
    }
  }

  aboutToAppear(): void {
    windowManager.setStatusBarDark()
    this.getPermission()
  }

  aboutToDisappear(): void {
    windowManager.setStatusBarLight()
  }

  build() {
    Column() {
      if (this.permissionReady) {
        AudioView()
      } else {
        LoadingProgress().width(32).height(32)
      }
    }
    .width('100%')
    .height('100%')
  }
}
