import { media } from '@kit.MediaKit'

@CustomDialog
export struct WordSoundDialog {
  controller: CustomDialogController
  wordEn: string = ''
  wordZh: string = ''
  @State isGreen: boolean = false
  timer: number = -1
  avPlayer: media.AVPlayer | null = null

  aboutToAppear(): void {
    this.startPlay()
  }

  startPlay(): void {
    if (this.avPlayer || !this.wordEn) {
      return
    }
    media.createAVPlayer().then((player) => {
      player.on('stateChange', (state: string): void => {
        if (state === 'initialized') {
          player.prepare().then(() => {}, () => { this.disposePlayer() })
        } else if (state === 'prepared') {
          player.loop = true
          player.play().then(() => {}, () => { this.disposePlayer() })
        }
      })
      player.url = `https://dict.youdao.com/dictvoice?audio=${encodeURIComponent(this.wordEn)}&type=1`
      this.avPlayer = player
    }, () => {
      this.avPlayer = null
    })
  }

  disposePlayer(): void {
    const player = this.avPlayer
    this.avPlayer = null
    if (!player) {
      return
    }
    player.stop().then(() => {
      player.release().then(() => {}, () => {})
    }, () => {
      player.release().then(() => {}, () => {})
    })
  }

  aboutToDisappear(): void {
    this.disposePlayer()
    if (this.timer !== -1) {
      clearInterval(this.timer)
      this.timer = -1
    }
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text(this.wordEn).fontSize(20).fontColor(Color.White).fontWeight(500)
        Image($r('app.media.icon_public_search'))
          .width(20).aspectRatio(1)
          .fillColor(this.isGreen ? $r('app.color.common_green') : Color.White)
          .onAppear(() => {
            if (this.timer !== -1) { clearInterval(this.timer) }
            this.timer = setInterval(() => { this.isGreen = !this.isGreen }, 500)
          })
          .onDisAppear(() => {
            if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1 }
          })
          .animation({ duration: 300 })
      }
      Text(this.wordZh).fontColor(Color.White)
    }.constraintSize({ minWidth: 175 }).padding({ left: 16, right: 16 }).height(90)
      .borderRadius(45).backgroundColor('#8f000000').justifyContent(FlexAlign.Center)
  }
}
