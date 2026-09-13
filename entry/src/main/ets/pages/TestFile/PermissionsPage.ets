import { Permissions } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { permission } from '../../common/utils/Permission'


@Entry
@Component
struct PermissionsPage {
  // 权限
  permissions: Permissions[] = ['ohos.permission.MICROPHONE']
  // 弹框提示
  confirmConfig: promptAction.ShowDialogOptions = {
    title: "温馨提示",
    message: "未授权使用麦克风将无法使用该面试录音功能，是否前往设置进行授权？",
    buttons: [
      { text: '离开', color: $r('app.color.common_gray_01') },
      { text: '去授权', color: $r('app.color.common_blue') }
    ]
  }

  async getPermission() {
    try {
      // 第一次授权
      const isOk = await permission.requestPermissions(this.permissions)
      if (isOk) {
        return
      }
      const confirm = await this.getUIContext().getPromptAction().showDialog(this.confirmConfig)
      if (confirm.index === 1) {
        // 第二次授权
        const isAllow = await permission.onSettingPermissions(this.permissions)
        if (isAllow) {
          return
        }
      }
      this.getUIContext().getRouter().back()
    } catch (e) {
      promptAction.openToast({ message: '未授权' })
        .then(() => {
          this.getUIContext().getRouter().back()
        })

    }
  }

  aboutToAppear(): void {
    this.getPermission()
  }

  build() {
    Column({ space: 20 }) {

    }
    .height('100%')
    .width('100%')
  }
}