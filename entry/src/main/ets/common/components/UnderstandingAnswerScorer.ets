import { AI_SCORING_ALLOW_LOCAL, AI_SCORING_URL } from 'BuildProfile'
import { auth } from '../utils/Auth'
import { AiScoringJob, scoringConfigured } from '../utils/AiScoring'
import { AiScoreInput, AiScoreResult, scoreInputError } from '../utils/AiScorePolicy'
import { scoreCredentialStore, ScoreConnectionState } from '../utils/ScoreCredentialStore'
import { ILoginDta } from '../../models/AccountModel'

@Component
export struct UnderstandingAnswerScorer {
  question: string = ''
  referenceAnswer: string = ''
  @StorageProp('user') @Watch('accountChanged') user: ILoginDta = {} as ILoginDta
  @State answer: string = ''
  @State busy: boolean = false
  @State connection: ScoreConnectionState = 'loading'
  @State message: string = ''
  @State result?: AiScoreResult = undefined
  private owner: string = ''
  private token: string = ''
  private active: boolean = false
  private generation: number = 0
  private connectionSequence: number = 0
  private job?: AiScoringJob

  aboutToAppear(): void {
    this.active = true
    this.owner = auth.getUser()?.id || ''
    this.token = auth.getUser()?.token || ''
    this.refreshConnection()
  }

  aboutToDisappear(): void {
    this.active = false
    this.cancel()
    this.connectionSequence++
  }

  private async refreshConnection(): Promise<void> {
    const sequence = ++this.connectionSequence
    this.connection = 'loading'
    const state = await scoreCredentialStore.status(this.owner, AI_SCORING_URL)
    if (this.active && sequence === this.connectionSequence) {
      this.connection = state
    }
  }

  private accountChanged(): void {
    const currentUser = auth.getUser()
    const owner = currentUser?.id || ''
    const token = currentUser?.token || ''
    if (this.owner === owner && this.token === token) { return }
    this.cancel()
    this.owner = owner
    this.token = token
    this.answer = ''
    this.result = undefined
    this.message = '登录状态已变更，请重新填写回答'
    this.refreshConnection()
  }

  private cancel(): void {
    ++this.generation
    this.job?.cancel()
    this.job = undefined
    if (this.busy) { this.message = '评分已取消，回答仍保留在此页' }
    this.busy = false
  }

  private edited(value: string): void {
    this.answer = value
    this.result = undefined
    this.message = ''
  }

  private openSettings(): void {
    auth.checkAuth({ url: 'pages/ScoreSettingsPage' })
  }

  private async submit(): Promise<void> {
    if (this.busy) { return }
    const input: AiScoreInput = {
      question: this.question.trim(),
      answer: this.answer.trim(),
      referenceAnswer: this.referenceAnswer.trim()
    }
    this.message = scoreInputError(input)
    if (this.message) { return }
    if (!scoringConfigured(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)) {
      this.message = '当前版本尚未配置 AI 评分服务；回答保留在本页，未发送'
      return
    }
    if (!this.owner || !this.token) {
      this.message = '请先登录后再评分'
      return
    }

    const generation = ++this.generation
    this.busy = true
    this.result = undefined
    try {
      const credential = await scoreCredentialStore.read(this.owner, AI_SCORING_URL)
      if (generation !== this.generation || !this.active) { return }
      this.connection = credential.state
      if (credential.state !== 'ready') {
        this.message = credential.state === 'missing'
          ? '先完成评分服务连接配置，回答会留在本页'
          : '暂时无法读取评分连接配置，请解锁设备后重试'
        return
      }
      const consent = await this.getUIContext().getPromptAction().showDialog({
        title: '发送回答进行 AI 评分？',
        message: `将题目、你的回答和参考答案发送至 ${AI_SCORING_URL}，再由该服务提交给其配置的模型提供方。不会上传录音或课堂登录信息。请先删除不希望外传的个人信息。`,
        buttons: [{ text: '取消', color: '#64748B' }, { text: '同意并评分', color: '#007DFF' }]
      })
      if (generation !== this.generation || !this.active || consent.index !== 1) { return }
      const job = new AiScoringJob(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)
      this.job = job
      this.message = '正在分析回答的理解程度、要点和表达…'
      const result = await job.run(input, credential.accessCode)
      if (generation !== this.generation || !this.active) { return }
      this.result = result
      this.message = '评分完成，仅供学习复盘参考'
    } catch (error) {
      if (generation !== this.generation || !this.active) { return }
      switch ((error as Error).message) {
        case 'INVALID_RESPONSE': this.message = '评分返回格式无效，未展示不完整结果'; break
        case 'UNAUTHORIZED': this.connection = 'missing'; this.message = '连接验证未通过，请更新评分服务配置'; break
        case 'RATE_LIMITED': this.message = '评分请求过多，请稍后重试'; break
        case 'SERVICE_NOT_READY': this.message = '评分服务已连接，但模型服务尚未配置完成'; break
        case 'TIMEOUT': this.message = '评分超时，请稍后重试'; break
        case 'CANCELLED': this.message = '评分已取消，回答仍保留在本页'; break
        default: this.message = '评分未完成，请检查网络或服务配置后重试；回答仍保留在本页'
      }
    } finally {
      if (generation === this.generation) {
        this.busy = false
        this.job = undefined
      }
    }
  }

  build() {
    Column({ space: 12 }) {
      Text('用自己的话解释')
        .fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
      Text('先不照抄参考答案。说清楚你观察到的变化，以及为什么会这样。')
        .fontSize(14).lineHeight(22).fontColor($r('app.color.common_gray_03'))
      TextArea({ text: this.answer, placeholder: '写下你的理解和原因…' })
        .id('understandingAnswer')
        .accessibilityText('用自己的话解释')
        .height(150)
        .enabled(!this.busy)
        .onChange((value: string) => this.edited(value))
      Row({ space: 8 }) {
        Button(this.busy ? '取消评分' : '检查理解并打分')
          .id('understandingScoreButton')
          .layoutWeight(1).height(46)
          .enabled(this.busy || this.connection !== 'loading')
          .onClick(() => { if (this.busy) { this.cancel() } else { this.submit() } })
        if (scoringConfigured(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL) &&
          (this.connection === 'missing' || this.connection === 'unavailable')) {
          Button('连接设置')
            .id('understandingScoreSettings')
            .height(46)
            .onClick(() => this.openSettings())
        }
      }.width('100%')
      if (!scoringConfigured(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)) {
        Text('当前版本未配置评分服务；可以先写下理解，不会发送文字或生成分数。')
          .fontSize(13).lineHeight(20).fontColor($r('app.color.common_gray_03'))
      }
      if (this.message) {
        Text(this.message)
          .id('understandingScoreStatus')
          .fontSize(14).lineHeight(22).fontColor($r('app.color.common_gray_03'))
      }
      if (this.result) {
        Text(`${this.result.score} / 100`)
          .id('understandingScoreValue')
          .fontSize(30).fontWeight(FontWeight.Medium).fontColor($r('app.color.common_blue'))
        Text(this.result.summary)
          .fontSize(15).lineHeight(23).fontColor($r('app.color.black'))
        if (this.result.strengths.length > 0) {
          Text('你已经理解到的部分').fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
          ForEach(this.result.strengths, (item: string, index: number) => {
            Text(`${index + 1}. ${item}`).fontSize(14).lineHeight(21).fontColor($r('app.color.black'))
          }, (item: string, index: number) => `strength-${index}`)
        }
        if (this.result.improvements.length > 0) {
          Text('下一步可以补清楚').fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
          ForEach(this.result.improvements, (item: string, index: number) => {
            Text(`${index + 1}. ${item}`).fontSize(14).lineHeight(21).fontColor($r('app.color.black'))
          }, (item: string, index: number) => `improvement-${index}`)
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
