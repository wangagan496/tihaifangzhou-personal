import { auth } from '../common/utils/Auth'
import { AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL } from 'BuildProfile'
import { ILoginDta } from '../models/AccountModel'
import { AiScoringJob, scoringConfigured } from '../common/utils/AiScoring'
import { AiScoreInput, AiScoreResult, scoreInputError } from '../common/utils/AiScorePolicy'
import { ReadAloudControl } from '../common/components/ReadAloudControl'
import { readAloud } from '../common/utils/ReadAloud'
import { scoreCredentialStore, ScoreConnectionState } from '../common/utils/ScoreCredentialStore'
import { audioDB } from '../common/utils/AudioDB'
import { canSaveTranscript, scoreWriteBackId } from '../common/utils/TranscriptionPolicy'

interface ScoreRoute { question?: string; answer?: string; referenceAnswer?: string; audioId?: number | string }

@Entry
@Component
struct AiScorePage {
  @StorageProp('topHeight') topHeight: number = 0
  @StorageProp('user') @Watch('accountChanged') user: ILoginDta = {} as ILoginDta
  @State question: string = ''
  @State answer: string = ''
  @State referenceAnswer: string = ''
  @State busy: boolean = false
  @State message: string = ''
  @State connection: ScoreConnectionState = 'loading'
  @State result?: AiScoreResult = undefined
  @State writeBackBusy: boolean = false
  private owner: string = ''
  private token: string = ''
  private audioId: number = 0
  private active: boolean = false
  private generation: number = 0
  private settingsSequence: number = 0
  private job?: AiScoringJob

  aboutToAppear(): void {
    this.active = true; this.owner = auth.getUser()?.id || ''; this.token = auth.getUser()?.token || ''
    const params = this.getUIContext().getRouter().getParams() as ScoreRoute
    this.question = typeof params?.question === 'string' ? params.question : ''
    this.answer = typeof params?.answer === 'string' ? params.answer : ''
    this.referenceAnswer = typeof params?.referenceAnswer === 'string' ? params.referenceAnswer : ''
    this.audioId = scoreWriteBackId(params?.audioId)
  }
  aboutToDisappear(): void { this.active = false; this.cancel(); this.settingsSequence++ }
  onPageHide(): void { this.cancel(); this.settingsSequence++ }
  onPageShow(): void { this.refreshConnection() }
  private async refreshConnection(): Promise<void> {
    const sequence = ++this.settingsSequence
    this.connection = 'loading'
    const connection = await scoreCredentialStore.status(this.owner, AI_SCORING_URL)
    if (this.active && sequence === this.settingsSequence) { this.connection = connection }
  }
  private openSettings(): void { auth.checkAuth({ url: 'pages/ScoreSettingsPage' }) }
  private accountChanged(): void {
    if (this.owner === (auth.getUser()?.id || '') && this.token === (auth.getUser()?.token || '')) { return }
    this.cancel(); this.result = undefined; this.answer = ''; this.question = ''; this.referenceAnswer = ''; this.audioId = 0
    this.owner = auth.getUser()?.id || ''; this.token = auth.getUser()?.token || ''
    this.message = '登录状态已变更，请重新打开评分页面'
    this.refreshConnection()
  }
  private cancel(): void {
    ++this.generation; this.job?.cancel(); this.job = undefined; readAloud.stop()
    if (this.busy) { this.message = '已取消等待评分；已发送的请求可能仍在服务端处理' }
    this.busy = false
  }
  private edited(): void { this.result = undefined; this.message = '' }

  private canWriteBack(): boolean {
    return this.audioId > 0 && !!this.owner && canSaveTranscript(this.audioId, this.owner, this.answer)
  }

  private async writeBack(): Promise<void> {
    if (this.busy || this.writeBackBusy || !this.canWriteBack()) { return }
    this.writeBackBusy = true
    try {
      if (!await audioDB.initStore()) { this.message = '录音数据初始化失败，文字稿未改写'; return }
      const saved = await audioDB.saveTranscript(this.audioId, this.owner, this.answer.trim())
      this.message = saved ? '当前回答已写回本机录音文字稿' : '文字稿写回未确认，请重试'
    } finally { this.writeBackBusy = false }
  }

  private async submit(): Promise<void> {
    if (this.busy) { return }
    const input: AiScoreInput = { question: this.question.trim(), answer: this.answer.trim(), referenceAnswer: this.referenceAnswer.trim() }
    this.message = scoreInputError(input)
    if (this.message) { return }
    if (!scoringConfigured(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)) { this.message = 'AI 评分服务尚未配置，未发送任何文字'; return }
    if (!this.owner || !this.token) { this.message = '请先登录后再评分'; return }
    const generation = ++this.generation
    this.busy = true; this.result = undefined; readAloud.stop()
    try {
      const credential = await scoreCredentialStore.read(this.owner, AI_SCORING_URL)
      if (generation !== this.generation || !this.active) { return }
      this.connection = credential.state
      if (credential.state !== 'ready') {
        this.message = credential.state === 'missing' ? '请先在设置中完成评分服务配置，当前回答会保留' :
          '暂时无法读取连接配置，请解锁设备后重试'
        return
      }
      const consent = await this.getUIContext().getPromptAction().showDialog({
        title: '发送文字进行 AI 评分？',
        message: `将题目、回答和参考答案发送至 ${AI_SCORING_URL}，再由该服务提交给其配置的模型提供方。不会上传录音文件或课堂登录信息。请先删除不希望外传的个人信息。`,
        buttons: [{ text: '取消', color: '#64748B' }, { text: '同意并评分', color: '#007DFF' }]
      })
      if (generation !== this.generation || !this.active || consent.index !== 1) { return }
      const job = new AiScoringJob(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL); this.job = job
      this.message = '正在评分，通常需要一些时间…'
      const result = await job.run(input, credential.accessCode)
      if (generation !== this.generation || !this.active) { return }
      this.result = result; this.message = '评分完成，仅供面试练习参考，不代表真实面试结论'
    } catch (error) {
      if (generation !== this.generation || !this.active) { return }
      switch ((error as Error).message) {
        case 'INVALID_RESPONSE': this.message = '评分返回格式无效，未展示不完整结果'; break
        case 'UNAUTHORIZED': this.connection = 'missing'; this.message = '连接验证未通过，请到设置更新评分服务配置'; break
        case 'RATE_LIMITED': this.message = '评分请求过多，请稍后重试'; break
        case 'SERVICE_NOT_READY': this.message = '评分后端已连接，但模型服务尚未配置完成'; break
        case 'TIMEOUT': this.message = '模型评分超时，请稍后重试'; break
        default: this.message = '评分未完成，请检查网络或服务配置后重试。输入内容已保留'
      }
    } finally {
      if (generation === this.generation) { this.busy = false; this.job = undefined }
    }
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: 16 }) {
          Text('AI 面试评分').fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
          Text('先核对转写文字，再补充题目。评分只分析文字内容，不评价声音、语气或语速。')
            .fontSize(14).lineHeight(22).fontColor($r('app.color.common_gray_03'))
          if (!scoringConfigured(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)) {
            Text('AI 评分服务尚未配置。可以整理回答，当前不会发送文字或生成分数。')
              .id('scoringUnavailable').fontSize(14).fontColor($r('app.color.common_gray_03'))
          }
          if (scoringConfigured(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL) &&
            (this.connection === 'missing' || this.connection === 'unavailable')) {
            Row({ space: 12 }) {
              Text(this.connection === 'missing' ? '首次使用，请先完成连接配置' : '连接配置暂不可用')
                .fontSize(14).fontColor($r('app.color.common_gray_03')).layoutWeight(1)
              Button('前往设置').id('openScoreSettings').height(44)
                .enabled(!this.busy).onClick(() => this.openSettings())
            }.width('100%')
          }
          Text('面试题目').fontColor($r('app.color.black'))
          TextArea({ text: this.question, placeholder: '输入这段回答对应的面试题目' }).height(100).enabled(!this.busy)
            .accessibilityText('面试题目')
            .id('scoreQuestion').onChange((value) => { this.question = value; this.edited() })
          Text('我的回答（可编辑）').fontColor($r('app.color.black'))
          TextArea({ text: this.answer, placeholder: '输入回答，或从录音文字稿进入' }).height(220).enabled(!this.busy)
            .accessibilityText('我的回答，可编辑')
            .id('scoreAnswer').onChange((value) => { this.answer = value; this.edited() })
          Text('参考答案（选填）').fontColor($r('app.color.black'))
          TextArea({ text: this.referenceAnswer, placeholder: '可粘贴题库参考答案' }).height(120).enabled(!this.busy)
            .accessibilityText('参考答案，选填')
            .onChange((value) => { this.referenceAnswer = value; this.edited() })
          if (this.message) {
            Text(this.message).fontSize(14).lineHeight(22).fontColor($r('app.color.common_gray_03')).id('scoreStatus')
          }
          Button(this.busy ? '取消评分' : '提交 AI 评分').width('100%').height(48).id('submitAiScore')
            .enabled(this.busy || this.connection !== 'loading')
            .onClick(() => { if (this.busy) { this.cancel() } else { this.submit() } })
          if (this.audioId > 0) {
            Button(this.writeBackBusy ? '正在写回…' : '保存到录音文字稿').width('100%').height(48)
              .id('writeBackTranscript').enabled(!this.busy && !this.writeBackBusy && this.canWriteBack())
              .onClick(() => this.writeBack())
          }
          if (this.result) {
            Text(`${this.result.score} / 100`).fontSize(30).fontColor($r('app.color.common_blue')).id('aiScoreValue')
            Text(this.result.summary).fontSize(16).lineHeight(26).fontColor($r('app.color.black'))
            Text('回答亮点').fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
            ForEach(this.result.strengths, (item: string, index: number) => {
              Text(`${index + 1}. ${item}`).fontSize(16).fontColor($r('app.color.black'))
            }, (item: string, index: number) => `${index}`)
            Text('改进建议').fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
            ForEach(this.result.improvements, (item: string, index: number) => {
              Text(`${index + 1}. ${item}`).fontSize(16).fontColor($r('app.color.black'))
            }, (item: string, index: number) => `${index}`)
            ReadAloudControl({ text: `${this.result.summary}。${this.result.improvements.join('。')}` })
          }
        }.padding(20).width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart).backgroundColor($r('app.color.white'))
    }.title('回答复盘').titleMode(NavigationTitleMode.Mini).mode(NavigationMode.Stack).padding({ top: this.topHeight })
  }
}
