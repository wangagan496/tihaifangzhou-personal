import { mineFeedbackStore } from '../common/utils/MineFeedbackStore'

@Entry
@Component
struct MineFeedbackPage {
  @State feedback: string = ''
  @StorageProp('topHeight') topHeight: number = 0

  private submit(): void {
    const content = this.feedback.trim()
    if (!content) {
      this.showToast('请先填写反馈内容')
      return
    }
    if (mineFeedbackStore.save(content)) {
      this.feedback = ''
      this.showToast('反馈已保存，感谢你的建议')
    } else {
      this.showToast('反馈保存失败，请稍后重试')
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      return
    }
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
        Button('提交反馈')
          .width('100%')
          .height(44)
          .onClick(() => this.submit())
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
