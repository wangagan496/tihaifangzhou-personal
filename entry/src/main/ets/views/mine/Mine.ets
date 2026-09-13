import { MineProfileHeader } from './MineProfileHeader'
import { MineToolsList } from './MineToolsList'
import { ILoginDta } from '../../models/AccountModel'

@Component
export default struct Mine {
  @StorageProp('user') user: ILoginDta = {} as ILoginDta

  build() {
    Scroll() {
      Column({ space: 16 }) {
        MineProfileHeader({ user: this.user })
        MineToolsList()
      }
      .padding($r('app.float.common_gutter'))
      .width('100%')
    }.height('100%').width('100%')
    .backgroundColor($r('app.color.common_gray_bg'))
  }
}
