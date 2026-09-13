import { MineProfileHeader } from './MineProfileHeader'
import { MineStatsGrid } from './MineStatsGrid'
import { MineToolsList } from './MineToolsList'
import { tgRequest } from '../../common/utils/request'
import { windowManager } from '../../common/utils/WindowManager'
import { ILoginDta } from '../../models/AccountModel'
import { StudyTimeData } from '../../pages/StudyTimePage'

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

  private async getData(): Promise<void> {
    const res = await tgRequest<StudyTimeData>({ url: '/hm/studyInfo' })
    this.totalTime = res.totalTime
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
