@Entry
@Component
export default struct MineAboutPage {
  @StorageProp('topHeight') topHeight: number = 0

  build() {
    Navigation() {
      Column({ space: 16 }) {
        Image($r('app.media.icon')).width(72).aspectRatio(1)
        Text('题海方舟').fontSize(24).fontWeight(FontWeight.Bold)
        Text('HarmonyOS NEXT 学习应用').fontSize(14).fontColor('#6F6F6F')
        Divider().width('100%')
        Text('题海方舟提供题库练习、学习时长、面经浏览和面试录音等功能。')
          .fontSize(15)
          .fontColor('#4B5563')
          .lineHeight(24)
          .textAlign(TextAlign.Center)
        Text('当前版本：8.3.0').fontSize(13).fontColor('#9AA4B2')
      }
      .padding(24)
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.White)
    }
    .title('关于我们')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight })
  }
}
