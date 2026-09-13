import { TgLoadingDialog } from '../common/components/TgLoadingDialog'
import { ILoginDta } from '../models/AccountModel'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { promptAction } from '@kit.ArkUI'
import { request } from '@kit.BasicServicesKit'
import { tgRequest } from '../common/utils/request'
import { auth } from '../common/utils/Auth'

@Entry
@Component
struct ProfileEditPage {
  @StorageLink('user') user: ILoginDta = {} as ILoginDta
  dialog: CustomDialogController = new CustomDialogController({
    builder: TgLoadingDialog({ message: '更新中...' }),
    customStyle: true,
    alignment: DialogAlignment.Center
  })
  @StorageProp('topHeight') topHeight: number = 0
  @State nickName: string = this.user.nickName

  updateAvatar(): void {
    const options = new photoAccessHelper.PhotoSelectOptions()
    const picker = new photoAccessHelper.PhotoViewPicker()
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
    options.maxSelectNumber = 1
    picker.select(options).then((result) => {
      if (!result.photoUris.length) {
        this.showToast('请选择图片')
        return
      }
      const context = this.getUIContext().getHostContext()
      if (!context || !this.user.token) {
        this.showToast('当前登录状态无效')
        return
      }
      this.dialog.open()
      request.uploadFile(context, {
        url: 'https://api-harmony-teach.itheima.net/hm/userInfo/avatar',
        method: 'POST',
        header: { 'Content-Type': 'multipart/form-data', Authorization: `Bearer ${this.user.token}` },
        files: [{ filename: 'avatar.jpg', type: 'image/jpeg', name: 'file', uri: result.photoUris[0] }],
        data: []
      }).then((task) => {
        task.on('complete', (states) => {
          this.dialog.close()
          if (!states.length || states.some((state) => state.responseCode !== 0)) {
            this.showToast('上传头像失败')
            return
          }
          tgRequest<ILoginDta>({ url: '/hm/userInfo' }).then((user) => {
            this.user.avatar = user.avatar
            auth.setUser(this.user)
            this.showToast('上传头像成功')
          }, () => this.showToast('头像已上传，请稍后刷新'))
        })
        task.on('fail', () => { this.dialog.close(); this.showToast('上传头像失败') })
      }, () => { this.dialog.close(); this.showToast('上传头像失败') })
    }, () => this.showToast('无法打开图片选择器'))
  }

  updateNickname(): void {
    const nickName = this.nickName.trim()
    if (!nickName) { this.showToast('昵称不能为空'); return }
    tgRequest({
      url: '/hm/userInfo/profile',
      method: 'POST',
      data: { nickName }
    }).then(() => {
      this.user.nickName = nickName
      auth.setUser(this.user)
      this.showToast('更新成功')
    }, () => this.showToast('昵称更新失败，请稍后重试'))
  }

  private showToast(message: string): void {
    promptAction.openToast({ message })
  }

  build() {
    Navigation() {
      Column() {
        List() {
          ListItem() {
            Row() {
              Text('头像')
              Image(this.user.avatar || $r('app.media.ic_mine_avatar')).alt($r('app.media.ic_mine_avatar')).width(40).aspectRatio(1).borderRadius(20)
                .border({ width: 0.5, color: $r('app.color.common_gray_border') }).onClick(() => { this.updateAvatar() })
            }.width('100%').height(60).justifyContent(FlexAlign.SpaceBetween)
          }
          ListItem() {
            Row() {
              Text('昵称')
              TextInput({ text: $$this.nickName }).fontColor($r('app.color.common_gray_03')).textAlign(TextAlign.End).layoutWeight(1)
                .padding(0).height(60).backgroundColor($r('app.color.white')).borderRadius(0).onSubmit(() => { this.updateNickname() })
            }.width('100%').justifyContent(FlexAlign.SpaceBetween)
          }
        }.width('100%').height('100%').padding({ left: 35, right: 35, top: 15, bottom: 15 })
          .divider({ strokeWidth: 0.5, color: $r('app.color.common_gray_bg') })
      }
    }.titleMode(NavigationTitleMode.Mini).title('编辑资料').padding({ top: this.topHeight })
  }
}
