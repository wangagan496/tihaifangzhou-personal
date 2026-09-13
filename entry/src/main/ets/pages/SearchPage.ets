import { preferences } from '@kit.ArkData'
import { FilterParams } from '../views/home/QuestionFilterComp'
import { QuestionListComp } from '../views/home/QuestionListComp'

interface IRouterParams {
  keywordText: string
}

@Entry
@Component
struct SearchPage {
  @State keyword: string = ''
  @StorageProp('topHeight') topHeight: number = 0
  @State isDel: boolean = false
  @State list: string[] = []
  @State isInput: boolean = false
  private historyFile?: preferences.Preferences

  aboutToAppear(): void {
    this.initializeHistory()
  }

  private initializeHistory(): void {
    const context = this.getUIContext().getHostContext()
    if (!context) {
      return
    }
    this.historyFile = preferences.getPreferencesSync(context, { name: 'history' })
    const params = this.getUIContext().getRouter().getParams() as IRouterParams
    if (params?.keywordText) {
      this.keyword = params.keywordText
    }
    this.list = this.historyFile.getSync('list', []) as string[]
  }

  private saveHistory(): void {
    if (!this.historyFile) {
      return
    }
    this.historyFile.putSync('list', this.list)
    this.historyFile.flushSync()
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message })
  }

  onInputSubmit(): void {
    const value = this.keyword.trim()
    if (!value) {
      this.showToast('请输入内容')
      return
    }
    const oldIndex = this.list.findIndex(item => item === value)
    if (oldIndex >= 0) {
      this.list.splice(oldIndex, 1)
    }
    this.list.unshift(value)
    this.saveHistory()
    this.keyword = ''
    this.isInput = false
  }

  build() {
    Navigation() {
      Column({ space: 15 }) {
        TextInput({ placeholder: '回车搜索', text: $$this.keyword })
          .onSubmit(() => { this.onInputSubmit() })
          .onClick(() => { this.isInput = true })
        if (this.isInput) {
          Row() {
            Text('搜索记录').fontSize(20).fontWeight(800)
            Row() {
              if (this.isDel) {
                Text('全部删除').onClick(() => { this.list = []; this.saveHistory() })
                Text(' | ')
                Text('取消删除').onClick(() => { this.isDel = false })
              }
              Image($r('app.media.ic_common_delete')).height(28).onClick(() => { this.isDel = true })
            }
          }.width('100%').justifyContent(FlexAlign.SpaceBetween)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.list, (item: string) => { this.itemBuilder(item) })
          }
        } else {
          QuestionListComp({ typeId: 0, selfIndex: 0, params: new FilterParams(), keyword: this.keyword })
        }
      }.padding(15)
    }.titleMode(NavigationTitleMode.Mini).title('搜索页面').padding({ top: this.topHeight })
  }

  @Builder
  itemBuilder(text: string) {
    Row({ space: 20 }) {
      Text(text)
      if (this.isDel) {
        Text('x').height(30).onClick(() => {
          const index = this.list.findIndex(item => item === text)
          if (index >= 0) {
            this.list.splice(index, 1)
            this.saveHistory()
          }
        })
      }
    }.margin({ right: 10, top: 10 }).padding({ left: 15, right: 15, top: 5, bottom: 5 })
      .backgroundColor('rgba(0,0,0,0.05)').borderRadius(20)
  }
}
