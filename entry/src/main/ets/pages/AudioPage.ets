import { permission } from '../common/utils/Permission'
import { promptAction } from '@kit.ArkUI'
import { Permissions } from '@kit.AbilityKit'
import { AudioView } from '../views/AudioPage/AudioView'
import { windowManager } from '../common/utils/WindowManager'

@Entry
@Component
struct AudioPage {
  @State permissionReady: boolean = false
  @State permissionPending: boolean = false
  permissions: Permissions[] = ['ohos.permission.MICROPHONE']
  confirmConfig: promptAction.ShowDialogOptions = {
    title: '温馨提示',
    message: '录制新音频需要麦克风权限，已有录音的播放和文字转写不受影响。是否前往设置授权？',
    buttons: [
      { text: '暂不授权', color: $r('app.color.common_gray_01') },
      { text: '去授权', color: $r('app.color.common_blue') }
    ]
  }

  // Only request microphone access when the user explicitly enables new recording.
  async getPermission(): Promise<void> {
    if (this.permissionPending) { return }
    this.permissionPending = true
    try {
      this.permissionReady = await permission.requestPermissions(this.permissions)
      if (this.permissionReady) { return }
      const result = await this.getUIContext().getPromptAction().showDialog(this.confirmConfig)
      if (result.index === 1) { this.permissionReady = await permission.onSettingPermissions(this.permissions) }
    } catch (_) {
      this.permissionReady = false
    } finally { this.permissionPending = false }
  }

  aboutToAppear(): void {
    windowManager.setStatusBarDark()
    permission.hasPermissions(this.permissions).then((granted) => { this.permissionReady = granted })
  }

  aboutToDisappear(): void {
    windowManager.setStatusBarLight()
  }

  build() {
    Column() {
      AudioView({ recordingAllowed: this.permissionReady, permissionPending: this.permissionPending,
        onRequestRecording: () => this.getPermission()
      })
    }
    .width('100%')
    .height('100%')
  }
}
