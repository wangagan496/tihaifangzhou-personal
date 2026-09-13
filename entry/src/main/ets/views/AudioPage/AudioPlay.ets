import { InterviewAudioItem } from '../../common/utils/AudioDB'
import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'
import { Logger } from '../../common/utils/Logger'

@Component
export struct AudioPlayer {
  @State playing: boolean = false
  @Prop item: InterviewAudioItem = {} as InterviewAudioItem
  avPlayer?: media.AVPlayer
  private fd?: number
  private isTransitioning: boolean = false
  @State total: number = 0
  @State value: number = 0

  // 按沙箱文件路径创建播放器；播放器和文件描述符都在 stop/离页时释放。
  startPlay(): void {
    if (this.isTransitioning || this.avPlayer || !this.item.path) {
      return
    }
    this.isTransitioning = true
    let file: fileIo.File
    try {
      file = fileIo.openSync(this.item.path, fileIo.OpenMode.READ_ONLY)
    } catch (_) {
      this.isTransitioning = false
      Logger.error('startPlay', '录音文件无法打开')
      return
    }
    this.fd = file.fd
    try {
      media.createAVPlayer().then((player) => {
        player.on('stateChange', (state) => {
          if (state === 'initialized') {
            player.prepare().then(() => {}, () => { this.stopPlay() })
          } else if (state === 'prepared') {
            player.setVolume(1)
            player.loop = true
            this.total = player.duration
            player.play().then(() => {}, () => { this.stopPlay() })
          }
        })
        player.on('timeUpdate', (time) => { this.value = time })
        player.url = `fd://${file.fd}`
        this.avPlayer = player
        this.playing = true
        this.isTransitioning = false
      }, () => {
        Logger.error('startPlay', '播放器创建失败')
        this.playing = false
        this.isTransitioning = false
        this.closeFile()
      })
    } catch (_) {
      this.playing = false
      this.isTransitioning = false
      this.closeFile()
    }
  }

  stopPlay(): void {
    const player = this.avPlayer
    this.avPlayer = undefined
    this.playing = false
    this.value = 0
    if (!player) {
      this.closeFile()
      return
    }
    try {
      player.stop().then(() => {
        player.release().then(() => { this.closeFile() }, () => { this.closeFile() })
      }, () => {
        player.release().then(() => { this.closeFile() }, () => { this.closeFile() })
      })
    } catch (_) {
      this.closeFile()
    }
  }

  private closeFile(): void {
    if (this.fd === undefined) {
      return
    }
    try {
      fileIo.closeSync(this.fd)
    } catch (_) {
      // The descriptor may already have been closed by a failed player transition.
    }
    this.fd = undefined
  }

  aboutToDisappear(): void {
    this.stopPlay()
  }

  build() {
    Column({ space: 20 }) {
      Image($r('app.media.ic_mine_audio')).width(100).aspectRatio(1)
      Text(this.item.name).fontSize(18)
      Row({ space: 20 }) {
        Image(!this.playing ? $r('sys.media.ohos_ic_public_play') : $r('sys.media.ohos_ic_public_pause'))
          .width(24).aspectRatio(1)
          .onClick(() => { if (this.playing) { this.stopPlay() } else { this.startPlay() } })
        Progress({ value: this.value, total: this.total }).layoutWeight(1).margin({ top: 20, bottom: 20 })
      }.width('80%')
    }.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor($r('app.color.white'))
  }
}
