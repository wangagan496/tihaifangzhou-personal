import Home from '../views/home/Home'
import Interview from '../views/interview/Interview'
import Mine from '../views/mine/Mine'
import Project from '../views/project/Project'
import { windowManager } from '../common/utils/WindowManager'
import { contextManager } from '../common/utils/ContextManager'
import { auth } from '../common/utils/Auth'

auth.initUser()

@Entry
@Component
struct Index {
  //1、设置全屏，setWindowLayoutFullScreen
  //2、获取顶部高度，getWindowAvoidArea，将px转vp，存到AppStorage中


  aboutToAppear(): void {
    contextManager.ctx = this.getUIContext().getHostContext()!
    contextManager.UiCtx = this.getUIContext()
    // 开启全屏
    windowManager.enableFullScreen()
  }

  @State currentIndex: number = 0 // 表示默认选中的是第一个tab栏

  // 自定义tab的标签栏
  @Builder
  tabBuilder(text: string, icon: ResourceStr, selectedIcon: ResourceStr, index: number) {
    Column({ space: 5 }) {
      Image(this.currentIndex === index ? selectedIcon : icon)
        .height(26)
        .aspectRatio(1)
      Text(text)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? $r('app.color.common_blue') : $r('app.color.black'))
    }
  }

  build() {
    Tabs({ index: $$this.currentIndex }) {
      TabContent() {
        if (this.currentIndex === 0) {
          Home()
        }
      }.tabBar(this.tabBuilder('首页', $r('app.media.home'), $r('app.media.home_select'), 0))

      TabContent() {
        if (this.currentIndex === 1) {
          Project()
        }
      }.tabBar(this.tabBuilder('项目', $r('app.media.tabbar_project'), $r('app.media.project_select'), 1))

      TabContent() {
        if (this.currentIndex === 2) {
          Interview()
        }
      }.tabBar(this.tabBuilder('面经', $r('app.media.interview'), $r('app.media.interview_select'), 2))

      TabContent() {
        if (this.currentIndex === 3) {
          Mine()
        }
      }.tabBar(this.tabBuilder('我的', $r('app.media.tabbar_mine'), $r('app.media.mine_select'), 3))

    }
    .animationDuration(0) // 去掉切换动画
    .barPosition(BarPosition.End) // tabs在底部显示
    .padding({ bottom: 15 })
  }
}