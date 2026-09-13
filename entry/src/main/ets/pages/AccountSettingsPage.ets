import { auth } from '../common/utils/Auth'
import { ILoginDta } from '../models/AccountModel'

interface AccountSettingItem {
  name: string
  value?: string
  onClick?: () => void
}

@Entry
@Component
export default struct AccountSettingsPage {
  @StorageProp('topHeight') topHeight: number = 0
  @StorageProp('user') user: ILoginDta = {} as ILoginDta

  private logout(): void {
    auth.removeUser()
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' })
  }

  @Builder
  settingRow(item: AccountSettingItem) {
    Row() {
      Text(item.name)
        .fontSize(15)
        .fontColor('#1F2937')
      Blank()
      if (item.value) {
        Text(item.value)
          .fontSize(13)
          .fontColor('#8A94A3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '58%' })
      }
      if (item.onClick) {
        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(16)
          .aspectRatio(1)
          .fillColor('#A3ABB7')
          .margin({ left: 8 })
      }
    }
    .height(54)
    .width('100%')
    .padding({ left: 16, right: 14 })
    .onClick(() => item.onClick && item.onClick())
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 14 }) {
            Image(this.user.avatar || $r('app.media.ic_mine_avatar'))
              .width(58)
              .aspectRatio(1)
              .borderRadius(29)
            Column({ space: 5 }) {
              Text(this.user.nickName || '题海方舟用户')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#182230')
              Text(this.user.username || '已登录账号')
                .fontSize(13)
                .fontColor('#7A8493')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(8)

          Column() {
            this.settingRow({ name: '登录账号', value: this.user.username || '未提供' })
            Divider().margin({ left: 16 }).color('#EEF1F4')
            this.settingRow({ name: '用户编号', value: this.user.id || '未提供' })
            Divider().margin({ left: 16 }).color('#EEF1F4')
            this.settingRow({
              name: '编辑个人资料', onClick: () => {
                auth.checkAuth({ url: 'pages/ProfileEditPage' })
              }
            })
          }
          .backgroundColor(Color.White)
          .borderRadius(8)

          Column() {
            this.settingRow({
              name: '用户协议', onClick: () => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage', params: { sign: 'local' } })
              }
            })
            Divider().margin({ left: 16 }).color('#EEF1F4')
            this.settingRow({
              name: '隐私政策', onClick: () => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage', params: { sign: 'online' } })
              }
            })
          }
          .backgroundColor(Color.White)
          .borderRadius(8)

          Button('退出当前账号')
            .width('100%')
            .height(46)
            .fontColor('#E5484D')
            .backgroundColor(Color.White)
            .borderRadius(8)
            .onClick(() => this.logout())
        }
        .width('100%')
        .padding(16)
      }
      .backgroundColor($r('app.color.common_gray_bg'))
    }
    .title('账号设置')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight })
  }
}
