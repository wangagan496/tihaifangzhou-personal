import { MineProfileHeader } from './MineProfileHeader'
import { MineStatsGrid } from './MineStatsGrid'
import { MineToolsList } from './MineToolsList'
import { windowManager } from '../../common/utils/WindowManager'
import { ILoginDta } from '../../models/AccountModel'
import { auth } from '../../common/utils/Auth'
import { studyTimeStore } from '../../common/utils/StudyTimeStore'

@Component
export default struct Mine {
  @Watch('onUserChange')
  @StorageProp('user') user: ILoginDta = {} as ILoginDta
  @State totalTime: number = 0

  aboutToAppear(): void {
    windowManager.setStatusBarLight()
    this.getData()
  }

  onUserChange(): void {
    this.getData()
  }

  aboutToDisappear(): void {
    windowManager.setStatusBarDark()
  }

  private getData(): void {
    const user = auth.getUser()
    this.totalTime = studyTimeStore.getTotalTime(user?.id, user?.username)
  }

  build() {
    Column({ space: 16 }) {
      MineProfileHeader({ user: this.user })
      MineStatsGrid({ totalTime: this.totalTime })
      MineToolsList()
    }
    .padding($r('app.float.common_gutter'))
    .backgroundColor($r('app.color.common_gray_bg'))
    .linearGradient({
      colors: [[$r('app.color.common_blue'), 0], [$r('app.color.common_blue_bg'), 0.3], ['#f3f4f5', 1]]
    })
    .width('100%')
    .height('100%')
  }
}
