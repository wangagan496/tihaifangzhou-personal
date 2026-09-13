import { TgLoadingDialog } from '../common/components/TgLoadingDialog'
import { auth } from '../common/utils/Auth'
import { mergeUserProfile } from '../common/utils/ProfilePolicy'
import { tgRequest } from '../common/utils/request'
import { ILoginDta } from '../models/AccountModel'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { FormData } from '@ohos/axios'

@Entry
@Component
struct ProfileEditPage {
  private readonly avatarUploadTimeout: number = 20000
  private avatarUpdateId: number = 0
  private avatarUpdateTimer: number = -1
  @StorageLink('user') user: ILoginDta = {} as ILoginDta
  @StorageProp('topHeight') topHeight: number = 0
  @State nickName: string = ''
  @State isSaving: boolean = false
  @State isAvatarUpdating: boolean = false
  dialog: CustomDialogController = new CustomDialogController({
    builder: TgLoadingDialog({ message: '更新中...' }),
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear(): void {
    this.nickName = this.user.nickName || ''
  }

  aboutToDisappear(): void {
    if (this.isAvatarUpdating) {
      this.finishAvatarUpdate(this.avatarUpdateId)
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message })
  }

  private updateAvatar(): void {
    if (this.isAvatarUpdating) {
      return
    }
    const options = new photoAccessHelper.PhotoSelectOptions()
    const picker = new photoAccessHelper.PhotoViewPicker()
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
    options.maxSelectNumber = 1
    picker.select(options).then((result) => {
      if (!result.photoUris.length) {
        return
      }
      const context = this.getUIContext().getHostContext()
      if (!context || !this.user.token) {
        this.showToast('当前登录状态无效')
        return
      }
      const updateId = this.startAvatarUpdate()
      let imageBuffer: ArrayBuffer
      try {
        imageBuffer = this.readSelectedImage(result.photoUris[0])
      } catch (_) {
        this.finishAvatarUpdate(updateId)
        this.showToast('无法读取所选图片')
        return
      }
      const formData = new FormData()
      formData.append('file', imageBuffer, { filename: 'avatar.jpg', type: 'image/jpeg' })
      tgRequest<null, FormData>({
        url: '/hm/userInfo/avatar',
        method: 'POST',
        headers: { 'Content-Type': 'multipart/form-data' },
        context: context,
        data: formData
      }).then(() => {
        if (!this.isCurrentAvatarUpdate(updateId)) {
          return
        }
        tgRequest<ILoginDta>({ url: '/hm/userInfo' }).then((latestUser) => {
          if (!this.isCurrentAvatarUpdate(updateId)) {
            return
          }
          const updatedUser = mergeUserProfile(this.user, latestUser.avatar)
          this.user = updatedUser
          auth.setUser(updatedUser)
          if (this.finishAvatarUpdate(updateId)) {
            this.showToast('头像更新成功')
          }
        }, () => {
          if (this.finishAvatarUpdate(updateId)) {
            this.showToast('头像已上传，请稍后刷新')
          }
        })
      }, () => {
        if (this.finishAvatarUpdate(updateId)) {
          this.showToast('上传头像失败')
        }
      })
    }, () => this.showToast('无法打开图片选择器'))
  }

  private readSelectedImage(uri: string): ArrayBuffer {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
    try {
      const size = fileIo.statSync(file.fd).size
      const buffer = new ArrayBuffer(size)
      fileIo.readSync(file.fd, buffer)
      return buffer
    } finally {
      fileIo.closeSync(file.fd)
    }
  }

  private startAvatarUpdate(): number {
    this.avatarUpdateId += 1
    const updateId = this.avatarUpdateId
    this.isAvatarUpdating = true
    this.dialog.open()
    this.avatarUpdateTimer = setTimeout(() => {
      if (this.finishAvatarUpdate(updateId)) {
        this.showToast('上传超时，请检查网络后重试')
      }
    }, this.avatarUploadTimeout)
    return updateId
  }

  private isCurrentAvatarUpdate(updateId: number): boolean {
    return this.isAvatarUpdating && this.avatarUpdateId === updateId
  }

  private finishAvatarUpdate(updateId: number): boolean {
    if (!this.isCurrentAvatarUpdate(updateId)) {
      return false
    }
    if (this.avatarUpdateTimer >= 0) {
      clearTimeout(this.avatarUpdateTimer)
      this.avatarUpdateTimer = -1
    }
    this.dialog.close()
    this.isAvatarUpdating = false
    return true
  }

  private updateNickname(): void {
    const nickName = this.nickName.trim()
    if (!nickName) {
      this.showToast('昵称不能为空')
      return
    }
    if (nickName === this.user.nickName) {
      this.showToast('资料未发生变化')
      return
    }
    this.isSaving = true
    tgRequest({
      url: '/hm/userInfo/profile',
      method: 'POST',
      data: { nickName }
    }).then(() => {
      const updatedUser = mergeUserProfile(this.user, undefined, nickName)
      this.user = updatedUser
      auth.setUser(updatedUser)
      this.isSaving = false
      this.showToast('资料保存成功')
    }, () => {
      this.isSaving = false
      this.showToast('昵称更新失败，请稍后重试')
    })
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: 16 }) {
          Column() {
            Button() {
              Row() {
                Text('头像').fontSize(15).fontColor('#1F2937')
                Blank()
                Stack() {
                  Image(this.user.avatar || $r('app.media.ic_mine_avatar'))
                    .alt($r('app.media.ic_mine_avatar'))
                    .width(48)
                    .aspectRatio(1)
                    .borderRadius(24)
                    .border({ width: 0.5, color: $r('app.color.common_gray_border') })
                  if (this.isAvatarUpdating) {
                    LoadingProgress()
                      .width(24)
                      .height(24)
                      .color(Color.White)
                  }
                }
                .width(48)
                .height(48)
                Image($r('sys.media.ohos_ic_public_arrow_right'))
                  .width(16)
                  .aspectRatio(1)
                  .fillColor('#A3ABB7')
                  .margin({ left: 8 })
              }
              .width('100%')
              .height('100%')
            }
            .width('100%')
            .height(72)
            .padding({ left: 16, right: 14 })
            .enabled(!this.isAvatarUpdating)
            .stateEffect(true)
            .backgroundColor(Color.White)
            .borderRadius(0)
            .onClick(() => this.updateAvatar())
            Divider().margin({ left: 16 }).color('#EEF1F4')
            Row() {
              Text('登录账号').fontSize(15).fontColor('#1F2937')
              Blank()
              Text(this.user.username || '未提供').fontSize(13).fontColor('#8A94A3')
            }
            .width('100%')
            .height(54)
            .padding({ left: 16, right: 16 })
          }
          .backgroundColor(Color.White)
          .borderRadius(8)

          Column({ space: 10 }) {
            Text('昵称')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#273142')
              .width('100%')
            TextInput({ placeholder: '请输入昵称', text: $$this.nickName })
              .maxLength(20)
              .fontSize(15)
              .height(48)
              .padding({ left: 14, right: 14 })
              .backgroundColor('#F7F9FB')
              .border({ width: 1, color: '#E1E6EC' })
              .borderRadius(6)
              .onSubmit(() => this.updateNickname())
            Text(`${this.nickName.length}/20`)
              .fontSize(12)
              .fontColor('#98A1AE')
              .width('100%')
              .textAlign(TextAlign.End)
          }
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(8)

          Button() {
            Row({ space: 8 }) {
              if (this.isSaving) {
                LoadingProgress().width(22).height(22).color(Color.White)
              }
              Text(this.isSaving ? '保存中' : '保存资料')
            }
          }
          .width('100%')
          .height(46)
          .enabled(!this.isSaving)
          .backgroundColor('#3A9BFC')
          .borderRadius(8)
          .onClick(() => this.updateNickname())
        }
        .width('100%')
        .padding(16)
      }
      .backgroundColor($r('app.color.common_gray_bg'))
    }
    .titleMode(NavigationTitleMode.Mini)
    .title('编辑资料')
    .padding({ top: this.topHeight })
  }
}
