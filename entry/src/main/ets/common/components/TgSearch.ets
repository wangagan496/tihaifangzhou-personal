import { auth } from '../utils/Auth'

@Component
export struct TgSearch {
  @State
  ph: string = 'html'
  bg: string = ''
  color: string = ''
  keywords: string[] = ['html', 'css3', 'javascript', 'vue', 'react'] // 用来给轮播使用的数据
  index: number = 0 //表示取得数组的索引号
  timerId = -1

  aboutToAppear(): void {
    // 页面加载完毕就开启定时器
    // 每三秒轮播一次
    this.timerId = setInterval(() => {
      // 索引先+
      this.index++
      // 判断等于数组长度就重置索引
      if (this.index === this.keywords.length) {
        this.index = 0
      }
      // 从数组中获取当前索引的关键字
      this.ph = this.keywords[this.index]
    }, 3000)
  }

  aboutToDisappear(): void {
    clearInterval(this.timerId)
  }

  build() {
    Row() {
      Row({ space: 4 }) {
        Image($r("app.media.ic_common_search"))
          .width($r('app.float.hd_search_icon_size'))
          .aspectRatio(1)
          .fillColor(this.color || $r('app.color.common_gray_02'))
        Text(this.ph)
          .fontColor(this.color || $r('app.color.common_gray_02'))
          .fontSize($r('app.float.common_font14'))
      }
      .layoutWeight(1)
      .height($r('app.float.hd_search_height'))
      .backgroundColor(this.bg || $r('app.color.common_gray_border'))
      .borderRadius($r('app.float.hd_search_radius'))
      .justifyContent(FlexAlign.Center)
    }
    .onClick(() => {
      auth.checkAuth({
        url: 'pages/SearchPage',
        params: {
          keywordText: this.ph
        }
      })
    })
  }
}