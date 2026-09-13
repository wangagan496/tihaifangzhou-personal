import { readAloud, ReadingPhase } from '../utils/ReadAloud'

@Component
export struct ReadAloudControl {
  @Prop @Watch('stop') text: string = ''
  @State phase: ReadingPhase = 'idle'
  @State message: string = ''
  private ownsSpeech: boolean = false

  aboutToDisappear(): void { this.stop() }

  private stop(): void {
    if (this.ownsSpeech) { this.ownsSpeech = false; readAloud.stop() }
    this.phase = 'idle'; this.message = ''
  }

  build() {
    Column({ space: 6 }) {
      Button(this.phase === 'preparing' ? '取消朗读' : this.phase === 'speaking' ? '停止朗读' : '朗读文字')
        .id('readAloudButton').height(44).enabled(this.text.trim().length > 0).width('100%')
        .onClick(() => {
          if (this.phase === 'preparing' || this.phase === 'speaking') { this.stop(); return }
          this.ownsSpeech = true
          readAloud.start(this.text, (phase, message) => {
            this.ownsSpeech = phase === 'preparing' || phase === 'speaking'
            this.phase = phase; this.message = message
          })
        })
      if (this.message) {
        Text(this.message).fontSize(13).fontColor($r('app.color.common_gray_03')).id('readAloudStatus')
      }
    }.width('100%')
  }
}
