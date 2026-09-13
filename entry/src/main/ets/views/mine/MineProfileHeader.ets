import { TgClockIn } from '../../common/components/TgClockIn'
import { auth } from '../../common/utils/Auth'
import { ILoginDta } from '../../models/AccountModel'

@Component
export struct MineProfileHeader {
  @Prop user: ILoginDta = {} as ILoginDta

  build() {
    Row({ space: 12 }) {
      Image(this.user.avatar || $r('app.media.ic_mine_avatar'))
        .width(55)
        .aspectRatio(1)
        .borderRadius(55)
        .onClick(() => auth.checkAuth({ url: 'pages/ProfileEditPage' }))
      if (this.user.nickName) {
        Column({ space: 4 }) {
          Text(this.user.nickName)
            .fontSize(18)
            .fontWeight(600)
            .width('100%')
            .margin({ bottom: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      } else {
        Text('请登录')
          .layoutWeight(1)
          .onClick(() => auth.checkAuth({ url: 'pages/LoginPage' }))
      }

      TgClockIn()
    }
    .width('100%')
    .height(100)
  }
}
