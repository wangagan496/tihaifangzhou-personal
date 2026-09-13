import { auth } from '../../common/utils/Auth'

interface MineStatItem {
  icon: ResourceStr
  name: string
  detail?: string
  onClick?: () => void
}

@Component
export struct MineStatsGrid {
  @Prop totalTime: number = 0

  private formatTime(second: number): string {
    if (second >= 3600) {
      return (second / 3600).toFixed(1) + '小时'
    }
    if (second >= 60) {
      return (second / 60).toFixed(1) + '分钟'
    }
    return second + '秒'
  }

  @Builder
  statBuilder(item: MineStatItem) {
    GridCol() {
      Column() {
        Image(item.icon)
          .width(30)
          .aspectRatio(1)
          .margin({ bottom: 10 })
        Text(item.name)
          .fontSize(14)
          .fontColor($r('app.color.common_gray_03'))
          .margin({ bottom: 4 })
        if (item.detail) {
          Row() {
            Text(item.detail)
              .fontSize(12)
              .fontColor($r('app.color.common_gray_01'))
            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(12)
              .aspectRatio(1)
              .fillColor($r('app.color.common_gray_01'))
          }
        }
      }
      .onClick(() => item.onClick && item.onClick())
    }
  }

  build() {
    GridRow({ columns: 4 }) {
      this.statBuilder({
        icon: $r('app.media.ic_mine_history'), name: '历史记录',
        onClick: () => auth.checkAuth({ url: 'pages/MineQuestionsPage', params: { mode: 'history' } })
      })
      this.statBuilder({
        icon: $r('app.media.ic_mine_collect'), name: '我的收藏',
        onClick: () => auth.checkAuth({ url: 'pages/MineQuestionsPage', params: { mode: 'collect' } })
      })
      this.statBuilder({
        icon: $r('app.media.ic_mine_like'), name: '我的点赞',
        onClick: () => auth.checkAuth({ url: 'pages/MineQuestionsPage', params: { mode: 'like' } })
      })
      this.statBuilder({
        icon: $r('app.media.ic_mine_study'),
        name: '累计学时',
        detail: this.formatTime(this.totalTime),
        onClick: () => auth.checkAuth({ url: 'pages/StudyTimePage' })
      })
    }
    .backgroundColor($r('app.color.white'))
    .padding(16)
    .borderRadius(8)
  }
}
