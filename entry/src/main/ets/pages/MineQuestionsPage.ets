import { auth } from '../common/utils/Auth'
import { MineQuestionKind, mineQuestionStore } from '../common/utils/MineQuestionStore'
import { MineQuestionRecord } from '../common/utils/MineQuestionPolicy'

interface MineQuestionsParams {
  mode?: MineQuestionKind
}

@Entry
@Component
export default struct MineQuestionsPage {
  @State mode: MineQuestionKind = 'history'
  @State list: MineQuestionRecord[] = []
  @StorageProp('topHeight') topHeight: number = 0

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as MineQuestionsParams
    if (params?.mode === 'collect' || params?.mode === 'like' || params?.mode === 'history') {
      this.mode = params.mode
    }
    this.loadData()
  }

  private loadData(): void {
    const userId = auth.getUser()?.id
    this.list = userId ? mineQuestionStore.list(this.mode, userId) : []
  }

  private title(): string {
    if (this.mode === 'collect') {
      return '我的收藏'
    }
    if (this.mode === 'like') {
      return '我的点赞'
    }
    return '历史记录'
  }

  private emptyText(): string {
    if (this.mode === 'collect') {
      return '还没有收藏内容'
    }
    if (this.mode === 'like') {
      return '还没有点赞内容'
    }
    return '还没有浏览记录'
  }

  build() {
    Navigation() {
      if (this.list.length > 0) {
        List({ space: 8 }) {
          ForEach(this.list, (item: MineQuestionRecord) => {
            ListItem() {
              Column() {
                Text(item.stem)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 12 }) {
                  Text(`点赞 ${item.likeCount}`).fontSize(12).fontColor('#9AA4B2')
                  Text(`浏览 ${item.views}`).fontSize(12).fontColor('#9AA4B2')
                }.margin({ top: 8 })
              }
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .width('100%')
              .backgroundColor(Color.White)
              .borderRadius(8)
            }
            .onClick(() => {
              auth.checkAuth({
                url: 'pages/QuestionDetailPage',
                params: {
                  id: item.id,
                  type: item.contentType === 1 ? 1 : 0,
                  questionNo: item.questionNo
                }
              })
            })
          }, (item: MineQuestionRecord) => `${item.contentType === 1 ? 1 : 0}_${item.id}`)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      } else {
        Column({ space: 16 }) {
          Text(this.emptyText()).fontSize(16).fontColor('#6F6F6F')
          Text('浏览题目或面经后，这里会自动保留记录').fontSize(13).fontColor('#9AA4B2')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .title(this.title())
    .titleMode(NavigationTitleMode.Mini)
    .mode(NavigationMode.Stack)
    .padding({ top: this.topHeight })
    .backgroundColor($r('app.color.common_gray_bg'))
  }
}
