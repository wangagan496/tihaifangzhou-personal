import { UnderstandingExperimentSpec } from '../utils/UnderstandingExperimentCatalog'

/**
 * A small, hands-on experiment for a single concept.
 *
 * The user predicts first, changes the example themselves, then answers a
 * focused check. The component owns only its temporary experiment state.
 */
@Component
export struct UnderstandingLab {
  spec: UnderstandingExperimentSpec = {} as UnderstandingExperimentSpec
  @State items: string[] = ['A', 'B', 'C']
  @State expandedId: string = 'A'
  @State expandedIndex: number = 0
  @State keyMode: number = 0 // 0: position, 1: stable id
  @State hasChanged: boolean = false
  @State prediction: number = -1
  @State selectedAnswer: number = -1
  @State outcome: number = -1
  @State message: string = ''
  @State experimentMessage: string = ''
  @State showHint: boolean = false

  private isExpanded(item: string, index: number): boolean {
    return this.keyMode === 0 ? index === this.expandedIndex : item === this.expandedId
  }

  private toggleItem(item: string, index: number): void {
    if (!this.hasChanged) { return }
    this.expandedIndex = index
    this.expandedId = item
    this.experimentMessage = `已选择 ${item}。接着改变顺序，对比状态跟随位置还是这一项。`
  }

  private insertItem(): void {
    if (this.items.indexOf('X') >= 0 || this.prediction < 0) {
      return
    }
    this.items = ['X', ...this.items]
    this.hasChanged = true
    this.experimentMessage = this.prediction === 1
      ? '预测对了：按位置记录时，展开状态留在第 0 行，所以现在展开的是 X。'
      : '实际展开的是 X。按位置记录时，状态留在第 0 行；A 已经移到第 1 行。'
  }

  private reorderItems(): void {
    if (!this.hasChanged) {
      return
    }
    this.items = this.items.slice().reverse()
    this.hasChanged = true
    this.experimentMessage = '顺序已改变。比较两种识别方式，观察展开状态。'
  }

  private deleteA(): void {
    if (!this.hasChanged || this.items.indexOf('A') < 0) {
      return
    }
    this.items = this.items.filter((item: string) => item !== 'A')
    this.experimentMessage = 'A 已移除。按位置记录保留原位置；按 id 记录只跟随对应的项，删除该项后不再显示它的状态。'
  }

  private reset(): void {
    this.items = ['A', 'B', 'C']
    this.expandedId = 'A'
    this.expandedIndex = 0
    this.keyMode = 0
    this.hasChanged = false
    this.prediction = -1
    this.selectedAnswer = -1
    this.message = ''
    this.experimentMessage = ''
    this.showHint = false
    this.outcome = -1
  }

  private chooseMode(mode: number): void {
    this.keyMode = mode
    this.experimentMessage = ''
  }

  private predict(item: number): void {
    this.prediction = item
    this.experimentMessage = ''
  }

  private answer(option: number): void {
    if (!this.hasChanged || this.outcome < 0) {
      this.message = '先操作实验，再预测小考中的结果。'
      return
    }
    this.selectedAnswer = option
    this.message = this.outcome !== 0
      ? '再看位置：B 原本在第 1 行。删除 A 后，C 到了第 1 行；按位置保存的展开状态就落到了 C。'
      : option === 1
        ? '本轮小考通过：结果和原因都判断正确。位置变了，B 的身份没变。可以再回实验试一次。'
        : '结果判断对了，但 id 不会阻止排序。它标识的是同一项，而不是固定位置。'
  }

  @Builder
  modeButton(label: string, mode: number) {
    Button(label, { type: ButtonType.Normal })
      .height(38)
      .layoutWeight(1)
      .backgroundColor(this.keyMode === mode ? $r('app.color.common_blue') : $r('app.color.common_blue_bg'))
      .fontColor(this.keyMode === mode ? Color.White : $r('app.color.common_blue'))
      .accessibilityText(`${label}${this.keyMode === mode ? '，当前选择' : ''}`)
      .onClick(() => this.chooseMode(mode))
  }

  @Builder
  itemCard(item: string, index: number) {
    Column({ space: 6 }) {
      Row() {
        Text(item)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.black'))
        Blank()
        Text(this.isExpanded(item, index) ? '展开' : '收起')
          .fontSize(13)
          .fontColor(this.isExpanded(item, index)
            ? $r('app.color.common_blue') : $r('app.color.common_gray_03'))
      }
      if (this.isExpanded(item, index)) {
        Text(this.keyMode === 0 ? '状态跟随这个位置' : '状态跟随这个 id')
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.common_gray_03'))
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.isExpanded(item, index) ? $r('app.color.common_blue_bg') : $r('app.color.white'))
    .border({
      width: this.isExpanded(item, index) ? 1.5 : 0.5,
      color: this.isExpanded(item, index) ? $r('app.color.common_blue') : $r('app.color.common_gray_border')
    })
    .borderRadius(8)
    .animation({ duration: 220, curve: Curve.EaseOut })
    .accessibilityGroup(true)
    .accessibilityText(`列表项 ${item}${this.isExpanded(item, index) ? '，已展开' : '，未展开'}`)
    .onClick(() => this.toggleItem(item, index))
  }

  build() {
    Column({ space: 12 }) {
      Text('先理解这道题')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.black'))
        .width('100%')
      Text(this.spec.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.black'))
        .width('100%')
      Text(this.spec.scenario)
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.common_gray_03'))
        .width('100%')
      Text('key 是列表用来认出每一项的标识，id 像这一项的身份证号。这里用展开状态演示两种识别方式；实际组件表现还取决于代码写法。')
        .fontSize(13).fontColor($r('app.color.common_gray_03')).width('100%')
      Text(this.spec.prompt)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.black'))
        .width('100%')

      Row({ space: 8 }) {
        Button('顶部插入 X', { type: ButtonType.Normal })
          .height(38)
          .layoutWeight(1)
          .enabled(this.items.indexOf('X') < 0 && this.prediction >= 0)
          .onClick(() => this.insertItem())
        Button('重新排序', { type: ButtonType.Normal })
          .height(38)
          .layoutWeight(1)
          .enabled(this.hasChanged)
          .onClick(() => this.reorderItems())
      }.width('100%')
      Row({ space: 8 }) {
        Button('删除 A', { type: ButtonType.Normal })
          .height(38)
          .layoutWeight(1)
          .enabled(this.hasChanged && this.items.indexOf('A') >= 0)
          .onClick(() => this.deleteA())
        Button('重置', { type: ButtonType.Normal })
          .height(38)
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.common_gray_03'))
          .onClick(() => this.reset())
      }.width('100%')

      Text(this.hasChanged
        ? '切换识别方式，对比展开的是谁。也可以点一项，再排序或删除，看看状态如何变化。'
        : '先预测：当前按位置记录状态，在顶部插入 X 后，哪一项会展开？')
        .fontSize(13)
        .fontColor($r('app.color.common_gray_03'))
        .width('100%')
      if (!this.hasChanged) {
        Row({ space: 8 }) {
          Button('原来的 A', { type: ButtonType.Normal })
            .height(38)
            .layoutWeight(1)
            .backgroundColor(this.prediction === 0 ? $r('app.color.common_blue_bg') : $r('app.color.ih_bg_color'))
            .fontColor(this.prediction === 0 ? $r('app.color.common_blue') : $r('app.color.black'))
            .onClick(() => this.predict(0))
          Button('新来的 X', { type: ButtonType.Normal })
            .height(38)
            .layoutWeight(1)
            .backgroundColor(this.prediction === 1 ? $r('app.color.common_blue_bg') : $r('app.color.ih_bg_color'))
            .fontColor(this.prediction === 1 ? $r('app.color.common_blue') : $r('app.color.black'))
            .onClick(() => this.predict(1))
        }.width('100%')
      }

      Column({ space: 8 }) {
        ForEach(this.items, (item: string, index: number) => {
          this.itemCard(item, index)
        }, (item: string) => item)
      }.width('100%')

      if (this.hasChanged) {
        Row({ space: 8 }) {
          this.modeButton('按位置识别', 0)
          this.modeButton('按每项 id 识别', 1)
        }.width('100%')
      }
      if (this.experimentMessage) {
        Text(this.experimentMessage)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.common_blue'))
          .width('100%')
      }

      Text(this.keyMode === 0
        ? '当前实验：记住的是第几行。插入或排序后，这一行可能已经换了人。'
        : '当前实验：记住的是这一项的 id。插入或排序后，同一项仍然能被认出来。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.common_gray_03'))
        .width('100%')

      Row() {
        Text('新场景：A、B、C 中 B 展开，删除 A 后剩下 B、C。谁会展开？')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.black'))
          .layoutWeight(1)
        Button(this.showHint ? '收起提示' : '看提示', { type: ButtonType.Normal })
          .height(34)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.common_blue'))
          .onClick(() => { this.showHint = !this.showHint })
      }.width('100%')
      if (this.showHint) {
        Text(this.spec.hint)
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.common_gray_03'))
          .width('100%')
      }
      Button('按位置是 C，按 id 是 B').id('labOutcomeCorrect').width('100%')
        .constraintSize({ minHeight: 44 }).enabled(this.hasChanged)
        .onClick(() => { this.outcome = 0; this.message = ''; this.selectedAnswer = -1 })
      Button('两种方式都是 B').id('labOutcomeWrong').width('100%')
        .constraintSize({ minHeight: 44 }).enabled(this.hasChanged)
        .onClick(() => { this.outcome = 1; this.message = ''; this.selectedAnswer = -1 })
      Text(this.outcome < 0 ? '选择结果后，再判断原因。' : `你的预测：${this.outcome === 0 ? '按位置 C，按 id B' : '都是 B'}。为什么？`)
        .fontSize(14).fontColor($r('app.color.black'))
      Row({ space: 8 }) {
        Button('id 阻止排序', { type: ButtonType.Normal })
          .enabled(this.hasChanged && this.outcome >= 0)
          .height(40)
          .layoutWeight(1)
          .backgroundColor(this.selectedAnswer === 0 ? '#FFF0F0' : $r('app.color.ih_bg_color'))
          .fontColor(this.selectedAnswer === 0 ? '#D94838' : $r('app.color.black'))
          .onClick(() => this.answer(0))
        Button('位置变，身份不变', { type: ButtonType.Normal })
          .enabled(this.hasChanged && this.outcome >= 0)
          .height(40)
          .layoutWeight(1)
          .backgroundColor(this.selectedAnswer === 1 ? $r('app.color.common_blue_bg') : $r('app.color.ih_bg_color'))
          .fontColor(this.selectedAnswer === 1 ? $r('app.color.common_blue') : $r('app.color.black'))
          .onClick(() => this.answer(1))
      }.width('100%')
      if (this.message) {
        Text(this.message)
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.selectedAnswer === 1 && this.outcome === 0 ? '#2F9E66' : $r('app.color.common_gray_03'))
          .width('100%')
          .accessibilityText(this.message)
      }
    }
    .width('100%')
    .id('questionUnderstanding')
    .alignItems(HorizontalAlign.Start)
  }
}
