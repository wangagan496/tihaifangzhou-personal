import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'
import { AudioBoComp } from './AudioBoComp'
import { AudioRecording, hasUsableAudioFile } from './AudioRecording'

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
  private peakAmplitude: number = 0
  // 降噪算法需约 400 ms 校准噪声基底，热身期间不标记 startTime。
  private readonly warmupMs: number = 400
  private isTransitioning: boolean = false
  @State warmingUp: boolean = false
  onRecordEnd: (recording: AudioRecording) => void = () => {}

  // 音频写入应用沙箱；FD 交给 AVRecorder，停止或失败时必须关闭。
  startRecord(): Promise<boolean> {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      return Promise.resolve(false)
    }
    const path = `${context.filesDir}/${Date.now()}.m4a`
    let file: fileIo.File
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
    } catch (_) {
      return Promise.resolve(false)
    }
    this.fd = file.fd
    this.filePath = path
    this.peakAmplitude = 0
    const config: media.AVRecorderConfig = {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
      profile: {
        // Mono AAC is supported by the original recorder flow and is less
        // dependent on the device's input route than stereo capture.
        audioBitrate: 100000,
        audioChannels: 1,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000, fileFormat: media.ContainerFormatType.CFT_MPEG_4A
      },
      url: `fd://${file.fd}`
    }
    try {
      return media.createAVRecorder().then((recorder) => {
        return recorder.prepare(config).then(() => {
          return recorder.start().then(() => {
            this.avRecorder = recorder
            this.timer = setInterval(() => { this.readAmplitude(recorder) }, 100)
            return true
          }, () => {
            recorder.release().then(() => {}, () => {})
            this.clearRecordResources()
            this.discardFile(path)
            return false
          })
        }, () => {
          recorder.release().then(() => {}, () => {})
          this.clearRecordResources()
          this.discardFile(path)
          return false
        })
      }, () => {
        this.clearRecordResources()
        this.discardFile(path)
        return false
      })
    } catch (_) {
      this.clearRecordResources()
      this.discardFile(path)
      return Promise.resolve(false)
    }
  }

  private readAmplitude(recorder: media.AVRecorder): void {
    if (this.amplitudeReading || recorder !== this.avRecorder) {
      return
    }
    this.amplitudeReading = true
    try {
      recorder.getAudioCapturerMaxAmplitude().then((amplitude) => {
        this.maxAmplitude = amplitude
        this.peakAmplitude = Math.max(this.peakAmplitude, amplitude)
        this.amplitudeReading = false
      }, () => {
        this.amplitudeReading = false
      })
    } catch (_) {
      this.amplitudeReading = false
    }
  }

  stopRecord(): Promise<boolean> {
    const recorder = this.avRecorder
    if (!recorder) {
      this.clearRecordResources()
      return Promise.resolve(false)
    }
    this.clearTimer()
    try {
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
    } catch (_) {
      this.clearRecordResources()
      return Promise.resolve(false)
    }
  }

  private clearTimer(): void {
    if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1 }
  }

  private closeFile(): void {
    if (this.fd !== undefined) {
      try {
        fileIo.closeSync(this.fd)
      } catch (_) {
        // A failed recorder transition may already have closed the descriptor.
      }
      this.fd = undefined
    }
  }

  private clearRecordResources(): void {
    this.clearTimer()
    this.closeFile()
    this.avRecorder = undefined
    this.maxAmplitude = 0
  }

  private discardFile(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_) {
      // The recorder may already have removed an incomplete output file.
    }
  }

  // 退出页面也统一停止录制、释放 AVRecorder 并关闭文件描述符。
  aboutToDisappear(): void {
    if (this.avRecorder) { this.stopRecord() } else { this.clearRecordResources() }
  }

  private toggleRecord(): void {
    if (this.isTransitioning || this.warmingUp) { return }
    this.isTransitioning = true
    if (!this.recording) {
      this.startRecord().then((started) => {
        if (!started) { this.isTransitioning = false; this.showToast('无法开始录音'); return }
        // 热身期间按钮变橙色，400 ms 后降噪算法完成校准，再切到录音状态。
        this.isTransitioning = false
        this.warmingUp = true
        setTimeout(() => {
          this.warmingUp = false
          this.startTime = Date.now()
          this.recording = true
        }, this.warmupMs)
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
      if (!stopped || !path) {
        if (path) { this.discardFile(path) }
        this.showToast('录音保存失败')
        return
      }
      try {
        const file = fileIo.statSync(path)
        const recording: AudioRecording = { path, duration, size: file.size, createTime: Date.now() }
        if (!hasUsableAudioFile(recording)) {
          this.discardFile(path)
          this.showToast('录音文件为空，请重试')
          return
        }
        if (this.peakAmplitude <= 0) {
          this.discardFile(path)
          this.showToast('未检测到声音，录音已取消')
          return
        }
        this.onRecordEnd(recording)
      } catch (_) {
        this.discardFile(path)
        this.showToast('无法读取录音文件')
      }
    }, () => {
      this.isTransitioning = false
      this.recording = false
      this.clearRecordResources()
      this.showToast('录音操作失败')
    })
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      return
    }
  }

  build() {
    Column() {
      AudioBoComp({ maxAmplitude: this.maxAmplitude, active: this.recording })

      Row() {
        Image($r('sys.media.ohos_ic_public_voice'))
          .width(22)
          .aspectRatio(1)
          .fillColor($r('app.color.white'))
          .onClick(() => { this.toggleRecord() })
      }
      .justifyContent(FlexAlign.Center)
      .height(52)
      .width(52)
      .borderRadius(26)
      .margin({ top: 8 })
      .backgroundColor(this.recording ? '#E5484D' : this.warmingUp ? '#F97316' : $r('app.color.common_blue'))
      .shadow({ radius: 8, color: this.recording ? '#E5484D44' : this.warmingUp ? '#F9731644' : '#3A9BFC44', offsetX: 0, offsetY: 3 })

    }
    .width('100%')
    .height(190)
    .backgroundColor('#F7F9FB')
    .border({ width: 1, color: '#E8EDF2' })
    .padding({ bottom: this.bottomHeight + 10, left: 20, right: 20, top: 12 })
  }
}
