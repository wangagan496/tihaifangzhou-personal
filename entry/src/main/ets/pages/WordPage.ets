import { util } from '@kit.ArkTS'
import webview from '@ohos.web.webview'
import { WordSoundDialog } from '../views/mine/WordSoundDialog'

export interface WordItem {
  zh: string
  en: string
  code: string
}

@Entry
@Component
struct WordPage {
  @StorageProp('topHeight') topHeight: number = 0
  @State
  showTypeSheet: boolean = false // 控制当前阶段分类弹框
  @State
  showCodeSheet: boolean = false // 控制当前单词详细代码弹框
  @State
  currentType: string = 'HTML5' // 当前阶段名称
  @State
  loading: boolean = false
  // 单词数据
  @State
  words: Record<string, WordItem[]> = {}
  currentCode: string = ''
  scroller = new Scroller()
  // web控制器
  controller: webview.WebviewController = new webview.WebviewController()
  en: string = '' // 当前的单词
  zh: string = '' // 当前单词的中文
  dialog: CustomDialogController = new CustomDialogController({
    builder: WordSoundDialog({ wordEn: this.en, wordZh: this.zh }),
    customStyle: true,
    alignment: DialogAlignment.Center
  })
  @StorageProp('isDark') isDark: boolean = false

  aboutToAppear(): void {
    this.getWords()
  }

  // 1、跳转到单词页面
  // 2、读取word.json中的单词
  // 3、使用Object.keys获取key值数组，渲染
  getWords(): void {
    this.loading = true
    const ctx = this.getUIContext().getHostContext()
    if (!ctx) {
      this.loading = false
      this.words = {}
      return
    }
    try {
      ctx.resourceManager.getRawFileContent('word.json').then((res): void => {
        try {
          const decoded = new util.TextDecoder().decodeToString(res)
          const data = JSON.parse(decoded) as Record<string, WordItem[]>
          this.words = data
          const categories = Object.keys(data)
          if (!data[this.currentType] && categories.length > 0) {
            this.currentType = categories[0]
          }
          this.loading = false
        } catch (_) {
          this.handleWordLoadFailure()
        }
      }, (): void => this.handleWordLoadFailure())
    } catch (_) {
      this.handleWordLoadFailure()
    }
  }

  private handleWordLoadFailure(): void {
      this.words = {}
      this.loading = false
      try {
        this.getUIContext().getPromptAction().showToast({ message: '单词数据加载失败' })
      } catch (_) {
        return
      }
  }

  // 单词分类弹窗
  @Builder
  typeSheetBuilder() {
    Column() {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        ForEach(Object.keys(this.words), (key: string, index) => {
          Button() {
            Text(key)
              .fontSize(14)
              .fontColor(key === this.currentType ? $r('app.color.common_green') : $r('app.color.common_gray_01'))
          }
          .backgroundColor($r('app.color.common_gray_bg'))
          .padding({
            top: 6,
            right: 12,
            bottom: 6,
            left: 12
          })
          .margin({ right: 12, bottom: 12 })
          .onClick(() => {
            this.currentType = key
            this.showTypeSheet = false
            this.scroller.scrollTo({ yOffset: 0, xOffset: 0 })
          })
        })
      }
    }
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 34
    })
  }

  // 1、给currentCode赋值，点击打开模态框的时候赋值
  // 2、使用web组件显示word.html，
  // 3、在onPageEnd函数中调用控制器的runJavaScript方法，将code传递给web组件

  // 弹出单词用法弹窗
  @Builder
  codeSheetBuilder() {
    Stack() {
      Web({
        src: $rawfile('word.html'),
        controller: this.controller
      })
        .onPageEnd(() => {
          this.controller.runJavaScript(`writeCode(${JSON.stringify(this.currentCode)})`)
        })
        .darkMode(this.isDark ? WebDarkMode.On : WebDarkMode.Off)
        .forceDarkAccess(this.isDark)
    }
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 34
    })
  }

  build() {
    Navigation() {
      Column() {
        Row() {
          Column({ space: 4 }) {
            Text('开发常用词汇')
            Text(`共 ${this.words[this.currentType]?.length} 个单词`)
              .fontSize(12)
              .fontColor($r('app.color.common_gray_03'))
          }
          .alignItems(HorizontalAlign.Start)

          Row() {
            Text(this.currentType)
              .fontSize(12)
              .fontColor($r('app.color.common_gray_01'))
            Image($r('sys.media.ohos_ic_public_arrow_down'))
              .width(16)
              .aspectRatio(1)
              .fillColor($r('app.color.common_gray_01'))
          }
          .onClick(() => this.showTypeSheet = true)
          .bindSheet($$this.showTypeSheet, this.typeSheetBuilder(), {
            height: 200,
            title: { title: '选择分类' }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(16)
        .border({ width: { top: $r('app.float.common_border_width') }, color: $r('app.color.common_gray_bg') })

        Divider()
          .strokeWidth(8)
          .color($r('app.color.common_gray_bg'))

        List({ scroller: this.scroller }) {
          ForEach(this.words[this.currentType] || [], (wordItem: WordItem) => {

            ListItem() {
              Row({ space: 6 }) {
                Image($r('sys.media.ohos_ic_public_sound'))
                  .width(20)
                  .aspectRatio(1)
                  .alignSelf(ItemAlign.Start)
                  .fillColor($r('app.color.common_gray_03'))
                  .onClick(() => {
                    // 开启弹框读单词
                    // 打开之前赋值
                    this.en = wordItem.en
                    this.zh = wordItem.zh

                    // 打开弹窗
                    this.dialog.open()
                  })
                Column({ space: 10 }) {
                  Text(wordItem.en)
                    .fontWeight(FontWeight.Bold)
                  Text(wordItem.zh)
                    .fontSize(14)
                    .fontColor($r('app.color.common_gray_03'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column({ space: 10 }) {
                  Row() {
                    Text('详细代码')
                      .fontSize(12)
                      .fontColor(wordItem.code ? $r('app.color.common_gray_01') : '#dddddd')
                    Image($r('sys.media.ohos_ic_public_arrow_right'))
                      .width(16)
                      .aspectRatio(1)
                      .fillColor(wordItem.code ? $r('app.color.common_gray_01') : '#dddddd')
                  }
                  // .alignSelf(ItemAlign.End)
                  .onClick(() => {
                    // 点击打开详细代码半模态框
                    this.showCodeSheet = true
                    this.currentCode = wordItem.code
                  })
                }
              }
              .padding(16)
            }
          })
        }
        .divider({
          strokeWidth: $r('app.float.common_border_width'),
          color: $r('app.color.common_gray_bg')
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.showCodeSheet, this.codeSheetBuilder, {
        height: 500,
        title: { title: '详细代码' }
      })
    }
    .title('常用单词')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight })
  }
}
