import { bundleManager } from '@kit.AbilityKit'

@Entry
@Component
struct MineAboutPage {
  @StorageProp('topHeight') topHeight: number = 0
  @State version: string = '未知版本'

  aboutToAppear(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).then((info) => {
      this.version = `v${info.versionName}`
    }, () => {
      this.version = '未知版本'
    })
  }

  @Builder
  featureRow(icon: ResourceStr, title: string, description: string) {
    Row({ space: 14 }) {
      Image(icon)
        .width(34)
        .height(34)
        .objectFit(ImageFit.Contain)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
        Text(description)
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#778190')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 10 }) {
            Image($r('app.media.icon'))
              .width(78)
              .aspectRatio(1)
              .borderRadius(8)
            Text('题海方舟')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#182230')
            Text('专注刷题、复习与面试准备的 HarmonyOS NEXT 学习应用')
              .fontSize(14)
              .lineHeight(22)
              .fontColor('#697483')
              .textAlign(TextAlign.Center)
            Text(this.version)
              .fontSize(12)
              .fontColor('#2878C8')
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor('#EAF4FF')
              .borderRadius(4)
          }
          .width('100%')
          .padding({ top: 24, bottom: 20, left: 24, right: 24 })
          .backgroundColor(Color.White)
          .borderRadius(8)

          Column({ space: 8 }) {
            Text('关于题海方舟')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1D2735')
              .width('100%')
            Text('题海方舟围绕“练习、记录、复习、表达”四个学习环节设计，将题库训练、学习时长、收藏点赞、面试录音和知识复习集中在一个应用中，帮助用户形成持续、可回顾的学习过程。')
              .fontSize(14)
              .lineHeight(24)
              .fontColor('#596575')
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(8)

          Column() {
            Text('核心能力')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1D2735')
              .width('100%')
              .margin({ bottom: 4 })
            this.featureRow($r('app.media.ic_mine_history'), '题库练习与记录', '支持分类筛选、分页浏览、历史记录、收藏和点赞。')
            Divider().color('#EEF1F4')
            this.featureRow($r('app.media.ic_mine_study'), '学习过程跟踪', '记录学习时长、连续打卡和阅读轨迹，让进度更清晰。')
            Divider().color('#EEF1F4')
            this.featureRow($r('app.media.ic_mine_ai'), '面试录音复盘', '录制、保存和播放面试练习内容，方便回听与改进表达。')
            Divider().color('#EEF1F4')
            this.featureRow($r('app.media.ic_mine_notes'), '知识与面经整理', '集中浏览常用词、面试内容和个人学习资料。')
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(8)

          Column({ space: 10 }) {
            Text('原生技术实现')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1D2735')
              .width('100%')
            Text('基于 ArkTS、ArkUI 和 Stage 模型开发，结合 Router、Preferences、关系型数据库、Media Kit、Share Kit 与 Notification Kit，实现页面交互、数据持久化和系统能力调用。')
              .fontSize(14)
              .lineHeight(24)
              .fontColor('#596575')
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Color.White)
          .borderRadius(8)

          Text('题海方舟 · 让每一次练习都留下进步')
            .fontSize(13)
            .fontColor('#8A94A3')
            .margin({ top: 2, bottom: 18 })
        }
        .width('100%')
        .padding(16)
      }
      .backgroundColor($r('app.color.common_gray_bg'))
    }
    .title('关于我们')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight })
  }
}
