@Entry
@Component
struct StudyCard {
  @Builder
  shortcut(title: string, action: string) {
    Button(title).height(28).width('100%').fontSize(13)
      .fontColor('#125AAF').backgroundColor('#EDF5FF')
      .onClick(() => {
        postCardAction(this, {
          action: 'router', abilityName: 'EntryAbility', params: { studyCardAction: action }
        })
      })
  }

  build() {
    Column({ space: 4 }) {
      Text('题海方舟').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#182B49').maxLines(1)
      this.shortcut('题库练习', 'questions')
      this.shortcut('收藏复习', 'favorites')
      this.shortcut('面试录音', 'audio')
    }.width('100%').height('100%').padding(8).justifyContent(FlexAlign.Center)
      .backgroundColor('#FFFFFF')
  }
}
