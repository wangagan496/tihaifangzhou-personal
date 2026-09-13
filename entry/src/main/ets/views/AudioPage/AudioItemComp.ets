import { InterviewAudioItem } from '../../common/utils/AudioDB'

@Component
export struct AudioItemComp {
  @Prop
  item: InterviewAudioItem = {} as InterviewAudioItem
  onPlay: () => void = () => {}
  onTranscribe: () => void = () => {}
  @Prop canTranscribe: boolean = true

  build() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 10 }) {
          Image($r('app.media.ic_mine_audio')).width(32).aspectRatio(1)
          Column({ space: 6 }) {
            Text(this.item.name).fontColor($r('app.color.black')).fontSize(16).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${(this.item.duration / 1000).toFixed(0)} 秒 · ${(this.item.size / 1000).toFixed(0)} KB`)
              .fontSize(14).fontColor($r('app.color.common_gray_03')).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%')
      }.layoutWeight(1).padding(0).backgroundColor(Color.Transparent)
        .onClick(() => this.onPlay()).accessibilityText(`播放录音 ${this.item.name}`)
      Button('转文字').fontSize(14).width(80).height(44)
        .enabled(this.canTranscribe)
        .onClick(() => this.onTranscribe()).accessibilityText(`转写录音 ${this.item.name}`)
        .id(`transcribeAudio_${this.item.id}`)
    }
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .constraintSize({ minHeight: 88 })
    .width('100%')
    .backgroundColor($r('app.color.white'))
    .borderRadius(10)
    .border({ width: 1, color: '#EEF1F4' })
  }
}
