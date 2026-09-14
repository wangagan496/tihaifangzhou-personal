import { AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL } from 'BuildProfile'
import { auth } from '../common/utils/Auth'
import { feedbackEndpoint, feedbackInputError } from '../common/utils/AiScorePolicy'
import { FeedbackJob } from '../common/utils/FeedbackSubmit'
import { mineFeedbackStore, StoredFeedback } from '../common/utils/MineFeedbackStore'
import { scoreCredentialStore } from '../common/utils/ScoreCredentialStore'

@Entry
@Component
struct MineFeedbackPage {
  @State feedback: string = ''
  @State history: StoredFeedback[] = []
  @State busy: boolean = false
  @StorageProp('topHeight') topHeight: number = 0

  aboutToAppear(): void {
    this.history = mineFeedbackStore.list()
  }

  private async submit(): Promise<void> {
    if (this.busy) { return }
    const error = feedbackInputError(this.feedback)
    if (error) { this.showToast(error); return }
    const content = this.feedback.trim()
    this.busy = true
    let delivered = false
    try {
      const url = feedbackEndpoint(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)
      const owner = auth.getUser()?.id || ''
      if (url && owner) {
        const credential = await scoreCredentialStore.read(owner, AI_SCORING_URL)
        if (credential.state === 'ready') {
          await new FeedbackJob(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL).run(content, credential.accessCode)
          delivered = true
        }
      }
      if (!mineFeedbackStore.save(content, delivered)) {
        this.showToast(delivered ? '已送达，但本机记录保存失败' : '反馈保存失败，请稍后重试')
        return
      }
      this.feedback = ''
      this.history = mineFeedbackStore.list()
      this.showToast(delivered ? '反馈已送达开发者服务' : '已保存到本机。配置评分服务后可再次提交送达')
    } catch (_) {
      if (mineFeedbackStore.save(content, false)) {
        this.feedback = ''
        this.history = mineFeedbackStore.list()
        this.showToast('未能送达服务，已先保存在本机')
      } else {
        this.showToast('反馈提交失败，请稍后重试')
      }
    } finally {
      this.busy = false
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      return
    }
  }

  private historyLine(item: StoredFeedback): string {
    return `${item.delivered ? '已送达' : '仅本机'} · ${item.content}`
  }

  build() {
    Navigation() {
      Column({ space: 16 }) {
        Text('告诉我们你的使用体验').fontSize(18).fontWeight(FontWeight.Medium)
        TextArea({ placeholder: '请输入意见或建议', text: $$this.feedback })
          .height(180)
          .width('100%')
          .backgroundColor(Color.White)
          .borderRadius(8)
          .padding(14)
          .enabled(!this.busy)
        Button(this.busy ? '正在提交…' : '提交反馈')
          .width('100%')
          .height(44)
          .id('submitFeedback')
          .enabled(!this.busy)
          .onClick(() => this.submit())
        if (this.history.length > 0) {
          Text('最近提交').fontSize(14).fontColor('#8A94A3')
          Scroll() {
            Column({ space: 8 }) {
              ForEach(this.history, (item: StoredFeedback) => {
                Text(this.historyLine(item))
                  .fontSize(13)
                  .fontColor('#4C596A')
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }, (item: StoredFeedback) => `${item.time}`)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }.layoutWeight(1)
        }
      }
      .padding(16)
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.common_gray_bg'))
    }
    .title('意见反馈')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight })
  }
}
