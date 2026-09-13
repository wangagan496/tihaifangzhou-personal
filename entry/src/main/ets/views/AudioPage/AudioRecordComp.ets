import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'
import { AudioBoComp } from './AudioBoComp'
import { auth } from '../../common/utils/Auth'
import dayjs from 'dayjs'
import { InterviewAudioItem } from '../../common/utils/AudioDB'

@Component
export struct AudioRecordComp {
  @StorageProp('bottomHeight') bottomHeight: number = 0
  avRecorder?: media.AVRecorder
  fd?: number
  filePath?: string
  timer: number = -1
  @State maxAmplitude: number = 0
  @State recording: boolean = false
  startTime: number = 0
  private amplitudeReading: boolean = false
  private isTransitioning: boolean = false
  onRecordEnd: (item: InterviewAudioItem) => void = () => {}

  // 音频写入应用沙箱；FD 交给 AVRecorder，停止或失败时必须关闭。
  startRecord(): Promise<boolean> {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      return Promise.resolve(false)
    }
    const path = `${context.filesDir}/${Date.now()}.m4a`
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
    this.fd = file.fd
    this.filePath = path
    const config: media.AVRecorderConfig = {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
      profile: {
        audioBitrate: 100000, audioChannels: 1, audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000, fileFormat: media.ContainerFormatType.CFT_MPEG_4A
      },
      url: `fd://${file.fd}`
    }
    return media.createAVRecorder().then((recorder) => {
      return recorder.prepare(config).then(() => {
        return recorder.start().then(() => {
          this.avRecorder = recorder
          this.timer = setInterval(() => { this.readAmplitude(recorder) }, 100)
          return true
        }, () => {
          recorder.release().then(() => {}, () => {})
          this.clearRecordResources()
          return false
        })
      }, () => {
        recorder.release().then(() => {}, () => {})
        this.clearRecordResources()
        return false
      })
    }, () => {
      this.clearRecordResources()
      return false
    })
  }

  private readAmplitude(recorder: media.AVRecorder): void {
    if (this.amplitudeReading || recorder !== this.avRecorder) {
      return
    }
    this.amplitudeReading = true
    recorder.getAudioCapturerMaxAmplitude().then((amplitude) => {
      this.maxAmplitude = amplitude
      this.amplitudeReading = false
    }, () => {
      this.amplitudeReading = false
    })
  }

  stopRecord(): Promise<boolean> {
    const recorder = this.avRecorder
    if (!recorder) {
      this.clearRecordResources()
      return Promise.resolve(false)
    }
    this.clearTimer()
    return recorder.stop().then(() => {
      return recorder.release().then(() => {
        this.avRecorder = undefined
        this.closeFile()
        this.maxAmplitude = 0
        return true
      }, () => {
        this.avRecorder = undefined
        this.closeFile()
        this.maxAmplitude = 0
        return false
      })
    }, () => {
      return recorder.release().then(() => {
        this.avRecorder = undefined
        this.closeFile()
        this.maxAmplitude = 0
        return false
      }, () => {
        this.avRecorder = undefined
        this.closeFile()
        this.maxAmplitude = 0
        return false
      })
    })
  }

  private clearTimer(): void {
    if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1 }
  }

  private closeFile(): void {
    if (this.fd !== undefined) {
      fileIo.closeSync(this.fd)
      this.fd = undefined
    }
  }

  private clearRecordResources(): void {
    this.clearTimer()
    this.closeFile()
    this.avRecorder = undefined
    this.maxAmplitude = 0
  }

  // 退出页面也统一停止录制、释放 AVRecorder 并关闭文件描述符。
  aboutToDisappear(): void {
    if (this.avRecorder) { this.stopRecord() } else { this.clearRecordResources() }
  }

  private toggleRecord(): void {
    if (this.isTransitioning) { return }
    this.isTransitioning = true
    if (!this.recording) {
      this.startRecord().then((started) => {
        this.isTransitioning = false
        if (!started) { this.showToast('无法开始录音'); return }
        this.startTime = Date.now()
        this.recording = true
      }, () => {
        this.isTransitioning = false
        this.clearRecordResources()
        this.showToast('录音操作失败')
      })
      return
    }
    const path = this.filePath
    const duration = Date.now() - this.startTime
    this.stopRecord().then((stopped) => {
      this.isTransitioning = false
      this.recording = false
      if (!stopped || !path) { this.showToast('录音保存失败'); return }
      const user = auth.getUser()
      if (!user?.id) { return }
      const file = fileIo.statSync(path)
      this.onRecordEnd({ id: null, user_id: user.id, name: dayjs().format('YYYY-MM-DD HH:mm:ss'), path, duration, size: file.size, create_time: Date.now() })
    }, () => {
      this.isTransitioning = false
      this.recording = false
      this.clearRecordResources()
      this.showToast('录音操作失败')
    })
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message })
  }

  build() {
    Column() {
      AudioBoComp({ maxAmplitude: this.maxAmplitude })
      Row() {
        Image($r('sys.media.ohos_ic_public_voice')).width(24).aspectRatio(1).fillColor($r('app.color.white')).onClick(() => { this.toggleRecord() })
      }.justifyContent(FlexAlign.Center).height(50).width(50).borderRadius(25).margin({ top: 20 })
        .backgroundColor(this.recording ? Color.Black : $r('app.color.common_blue'))
    }.width('100%').height(240).backgroundColor($r('app.color.common_gray_bg'))
      .padding({ bottom: this.bottomHeight, left: 80, right: 80, top: 20 })
  }
}
