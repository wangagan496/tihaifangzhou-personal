import { window } from '@kit.ArkUI'
import { ILoginDta } from '../models/AccountModel'
import { auth } from '../common/utils/Auth'
import { audioDB, InterviewAudioItem } from '../common/utils/AudioDB'
import { AudioTranscriptionJob, TranscriptionProgress } from '../common/utils/AudioTranscription'
import { MAX_TRANSCRIPTION_MS, transcriptionErrorMessage } from '../common/utils/TranscriptionPolicy'
import { ReadAloudControl } from '../common/components/ReadAloudControl'
import { readAloud } from '../common/utils/ReadAloud'

interface TranscriptRoute { audioId: number }
type Phase = 'loading' | 'ready' | 'preparing' | 'recognizing' | 'saving' | 'done' | 'error' | 'cancelled'

@Entry
@Component
struct AudioTranscriptPage {
  @StorageProp('topHeight') topHeight: number = 0
  @StorageProp('user') @Watch('onAccountChanged') user: ILoginDta = {} as ILoginDta
  @State item: InterviewAudioItem | undefined = undefined
  @State phase: Phase = 'loading'
  @State savedText: string = ''
  @State preview: string = ''
  @State unsaved: string = ''
  @State message: string = ''
  @State percent: number = 0
  private ownerId: string = ''
  private active: boolean = false
  private needsReload: boolean = false
  private generation: number = 0
  private job?: AudioTranscriptionJob
  private keptWindow?: window.Window
  private previousKeepAwake: boolean = false
  private screenQueue: Promise<void> = Promise.resolve()

  aboutToAppear(): void { this.active = true; this.load() }
  aboutToDisappear(): void { this.active = false; this.cancel(false) }
  onPageHide(): void { this.cancel(true) }
  onPageShow(): void {
    if (this.active && this.needsReload) { this.needsReload = false; this.load() }
  }

  private onAccountChanged(): void {
    if (!this.active || this.ownerId === (auth.getUser()?.id || '')) { return }
    this.cancel(false)
    this.savedText = ''; this.preview = ''; this.unsaved = ''; this.item = undefined
    this.load()
  }

  private isCurrent(generation: number): boolean {
    return this.active && generation === this.generation && this.ownerId === (auth.getUser()?.id || '')
  }

  private busy(): boolean { return this.phase === 'preparing' || this.phase === 'recognizing' || this.phase === 'saving' }

  private async load(): Promise<void> {
    const generation = ++this.generation
    this.ownerId = auth.getUser()?.id || ''
    this.phase = 'loading'
    const params = this.getUIContext().getRouter().getParams() as TranscriptRoute
    if (!this.ownerId || !params || !Number.isSafeInteger(params.audioId) || params.audioId <= 0) {
      this.message = '请登录后从录音列表打开文字稿'; this.phase = 'error'; return
    }
    if (!await audioDB.initStore()) {
      if (this.isCurrent(generation)) { this.message = '录音数据初始化失败，请返回后重试'; this.phase = 'error' }
      return
    }
    try {
      const item = await audioDB.find(params.audioId, this.ownerId)
      const text = item ? await audioDB.getTranscript(params.audioId, this.ownerId) : ''
      if (!this.isCurrent(generation)) { return }
      this.item = item
      this.savedText = text
      this.phase = text ? 'done' : 'ready'
      if (!item) { this.message = '录音不存在或已删除'; this.phase = 'error' }
      else if (item.duration > MAX_TRANSCRIPTION_MS) { this.message = transcriptionErrorMessage('AUDIO_TOO_LONG') }
    } catch (_) {
      if (this.isCurrent(generation)) {
        this.item = undefined; this.message = '录音或文字稿读取失败，请返回后重试'; this.phase = 'error'
      }
    }
  }

  private keepScreenOn(generation: number): Promise<void> {
    this.screenQueue = this.screenQueue.then(async () => {
      const context = this.getUIContext().getHostContext()
      if (!context || !this.isCurrent(generation)) { return }
      const win = await window.getLastWindow(context)
      const previous = win.getWindowProperties().isKeepScreenOn
      await win.setWindowKeepScreenOn(true)
      if (!this.isCurrent(generation)) { await win.setWindowKeepScreenOn(previous); return }
      this.keptWindow = win
      this.previousKeepAwake = previous
    }).catch(() => {})
    return this.screenQueue
  }

  private releaseScreen(): void {
    this.screenQueue = this.screenQueue.then(async () => {
      const win = this.keptWindow
      this.keptWindow = undefined
      if (win) { await win.setWindowKeepScreenOn(this.previousKeepAwake) }
    }).catch(() => {})
  }

  private cancel(showMessage: boolean): void {
    readAloud.stop()
    const wasRecognizing = this.phase === 'preparing' || this.phase === 'recognizing'
    if (this.phase === 'loading' || this.phase === 'saving') { this.needsReload = true }
    ++this.generation
    const job = this.job
    this.job = undefined
    job?.cancel()
    this.releaseScreen()
    if (job && wasRecognizing && showMessage && this.active) {
      this.phase = 'cancelled'; this.preview = ''; this.message = transcriptionErrorMessage('CANCELLED')
    }
  }

  private async start(): Promise<void> {
    readAloud.stop()
    const item = this.item
    const context = this.getUIContext().getHostContext()
    if (!item || item.id === null || !context || this.busy() || item.duration > MAX_TRANSCRIPTION_MS) { return }
    const generation = ++this.generation
    if (!this.isCurrent(generation)) { return }
    const job = new AudioTranscriptionJob()
    this.job = job
    this.phase = 'preparing'; this.message = ''; this.preview = ''; this.unsaved = ''; this.percent = 0
    await this.keepScreenOn(generation)
    try {
      if (!this.isCurrent(generation)) { return }
      const result = await job.run(item.path, context.cacheDir, (update: TranscriptionProgress) => {
        if (!this.isCurrent(generation)) { return }
        this.phase = update.phase; this.percent = update.percent; this.preview = update.partial
      })
      if (!this.isCurrent(generation)) { return }
      this.unsaved = result
      await this.saveResult(generation)
    } catch (error) {
      if (!this.isCurrent(generation)) { return }
      this.phase = 'error'; this.preview = ''; this.message = transcriptionErrorMessage((error as Error).message)
    } finally {
      if (this.job === job) { this.job = undefined; this.releaseScreen() }
    }
  }

  private async saveResult(generation: number): Promise<void> {
    const item = this.item
    if (!item || item.id === null || !this.unsaved || !this.isCurrent(generation) || this.phase === 'saving') { return }
    this.phase = 'saving'
    const result = this.unsaved
    const saved = await audioDB.saveTranscript(item.id, this.ownerId, result)
    if (!this.isCurrent(generation)) { return }
    this.preview = ''
    if (saved) {
      this.savedText = result; this.unsaved = ''; this.phase = 'done'; this.message = '文字稿已保存到本机'
    } else {
      this.phase = 'error'; this.message = '文字稿保存未确认，可重试保存'
    }
  }

  build() {
    Navigation() {
      Column({ space: 16 }) {
        if (this.phase === 'loading') {
          LoadingProgress().width(32).height(32).accessibilityText('正在读取录音')
        } else {
          Scroll() {
            Column({ space: 16 }) {
              if (this.item) {
                Column({ space: 6 }) {
                  Text(this.item.name).fontSize(20).fontWeight(FontWeight.Medium).maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.black'))
                  Text(`${Math.round(this.item.duration / 1000)} 秒 · 中文离线转写`).fontSize(14)
                  .fontColor($r('app.color.common_gray_03'))
                  Text('录音与文字稿保留在本机。转写时请保持此页在前台，离开会取消。')
                  .fontSize(14).lineHeight(22).fontColor($r('app.color.common_gray_03'))
                }.width('100%').alignItems(HorizontalAlign.Start)
              }
              if (this.busy()) {
                Column({ space: 8 }) {
                  Text(this.phase === 'preparing' ? '正在准备识别引擎和音频…' : this.phase === 'saving' ? '正在保存文字稿…' :
                  this.percent === 100 ? '音频处理完成，正在等待识别结果…' : `音频处理进度 ${this.percent}%`)
                  .fontSize(14).fontColor($r('app.color.common_blue')).id('transcriptionStatus')
                  if (this.phase === 'recognizing') {
                    Progress({ value: this.percent, total: 100 }).width('100%')
                  } else { LoadingProgress().width(24).height(24) }
                }.width('100%').alignItems(HorizontalAlign.Start)
              }
              if (this.message) {
                Text(this.message).fontSize(14).lineHeight(22).width('100%')
                .fontColor($r('app.color.common_gray_03')).id('transcriptionMessage')
              }
              Column({ space: 12 }) {
                Text(this.unsaved ? '待保存文字' : this.preview ? '识别中的文字（尚未保存）' :
                this.busy() && this.savedText ? '上次已保存的文字稿' : '文字稿')
                .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
                if (this.preview || this.unsaved || this.savedText) {
                  Text(this.unsaved || this.preview || this.savedText).fontSize(16).lineHeight(27)
                  .fontColor($r('app.color.black')).copyOption(CopyOptions.LocalDevice).width('100%')
                  .id('transcriptText')
                } else {
                  Text('转写完成后可在这里查看、长按复制文字。识别结果仅供复盘，请对照原录音核对。')
                  .fontSize(16).lineHeight(27).fontColor($r('app.color.common_gray_03'))
                }
              }.width('100%').alignItems(HorizontalAlign.Start)
              if (!this.busy() && (this.unsaved || this.savedText)) {
                ReadAloudControl({ text: this.unsaved || this.savedText })
                Button('核对文字并 AI 评分').width('100%').height(44).id('transcriptAiScore')
                  .onClick(() => auth.checkAuth({ url: 'pages/AiScorePage', params: {
                    answer: this.unsaved || this.savedText
                  } }))
              }
            }.width('100%').alignItems(HorizontalAlign.Start)
          }.layoutWeight(1).width('100%').align(Alignment.TopStart)
          if (this.item) {
            if (this.phase === 'preparing' || this.phase === 'recognizing') {
              Button('取消转写').width('100%').height(48).onClick(() => this.cancel(true)).id('cancelTranscription')
            } else if (this.unsaved) {
              Button(this.phase === 'saving' ? '正在保存…' : '重试保存').width('100%').height(48).enabled(!this.busy())
              .onClick(() => this.saveResult(this.generation)).id('saveTranscript')
            } else {
              Button(this.savedText ? '重新转写' : '开始转写').width('100%').height(48)
              .enabled(!this.busy() && this.item.duration <= MAX_TRANSCRIPTION_MS)
              .onClick(() => this.start()).id('startTranscription')
            }
          }
        }
      }.padding(20).width('100%').height('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.white'))
    }.title('录音转文字').titleMode(NavigationTitleMode.Mini).mode(NavigationMode.Stack)
    .padding({ top: this.topHeight })
  }
}
