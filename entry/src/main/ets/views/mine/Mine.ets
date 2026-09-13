import { MineProfileHeader } from './MineProfileHeader'
import { MineStatsGrid } from './MineStatsGrid'
import { MineToolsList } from './MineToolsList'
import { windowManager } from '../../common/utils/WindowManager'
import { ILoginDta } from '../../models/AccountModel'
import { auth } from '../../common/utils/Auth'
import { studyTimeStore } from '../../common/utils/StudyTimeStore'

@Component
export default struct Mine {
  @StorageProp('user') user: ILoginDta = {} as ILoginDta
  @State totalTime: number = 0

  aboutToAppear(): void {
    windowManager.setStatusBarLight()
    this.getData()
  }

  aboutToDisappear(): void {
    windowManager.setStatusBarDark()
  }

  private getData(): void {
    this.totalTime = studyTimeStore.getTotalTime(auth.getUser()?.id)
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
