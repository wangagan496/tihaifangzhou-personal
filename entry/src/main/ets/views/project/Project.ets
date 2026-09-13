import { IvSkeleton } from '../../common/components/IvSkeleton'
import { tgRequest } from '../../common/utils/request'
import { IQuestionType, IQuestionTypeTag } from '../../models/CategoryModel'
import { FilterParams } from '../home/QuestionFilterComp'
import { QuestionListComp } from '../home/QuestionListComp'

@Component
export default struct Project {
  @StorageProp('topHeight') topHeight: number = 0
  @State categories: IQuestionType[] = []
  @State selectedIndex: number = 0
  @State isLoading: boolean = true
  @State loadFailed: boolean = false
  @State params: FilterParams = new FilterParams()

  aboutToAppear(): void {
    this.loadCategories()
  }

  private loadCategories(): void {
    this.isLoading = true
    this.loadFailed = false
    tgRequest<IQuestionType[]>({
      url: '/hm/question/type',
      params: { type: 'items' }
    }).then((data) => {
      this.categories = data
      this.selectedIndex = 0
      this.isLoading = false
    }, () => {
      this.categories = []
      this.isLoading = false
      this.loadFailed = true
      this.getUIContext().getPromptAction().showToast({ message: '项目分类加载失败' })
    })
  }

  @Builder
  categoryTag(tag: IQuestionTypeTag) {
    Text(tag.tagName)
      .fontSize(10)
      .fontColor(tag.nameColor || '#2878C8')
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .border({ width: 0.5, color: tag.borderColor || '#B9D8F5' })
      .borderRadius(4)
  }

  @Builder
  categoryCard(item: IQuestionType, index: number) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Image(item.icon || $r('app.media.tabbar_project'))
          .alt($r('app.media.tabbar_project'))
          .width(38)
          .height(38)
          .objectFit(ImageFit.Contain)
        Column({ space: 3 }) {
          Row({ space: 5 }) {
            Text(item.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1F2937')
              .maxLines(1)
            if (item.displayNewestFlag === 1) {
              Text('新')
                .fontSize(10)
                .fontColor('#D9485F')
                .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                .backgroundColor('#FFF0F2')
                .borderRadius(3)
            }
          }
          Text(item.describeInfo || '按项目阶段练习常见面试题')
            .fontSize(11)
            .fontColor('#8A94A3')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      if (item.tags && item.tags.length > 0) {
        Row({ space: 6 }) {
          ForEach(item.tags.slice(0, 3), (tag: IQuestionTypeTag) => {
            this.categoryTag(tag)
          }, (tag: IQuestionTypeTag) => tag.tagName)
        }
        .width('100%')
      }
    }
    .width(220)
    .height(112)
    .padding(13)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(Color.White)
    .border({
      width: this.selectedIndex === index ? 1.5 : 0.5,
      color: this.selectedIndex === index ? '#3A9BFC' : '#E2E7ED'
    })
    .borderRadius(8)
    .onClick(() => {
      this.selectedIndex = index
    })
  }

  build() {
    Column() {
      Column({ space: 4 }) {
        Text('项目题库')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182230')
          .width('100%')
        Text('按项目方向系统练习，梳理实战中的核心知识点')
          .fontSize(13)
          .fontColor('#758092')
          .width('100%')
      }
      .padding({ left: 16, right: 16, top: 14, bottom: 12 })

      if (this.isLoading) {
        Row({ space: 12 }) {
          ForEach(Array.from({ length: 2 }), () => {
            IvSkeleton({ widthValue: 210, heightValue: 112 })
          })
        }
        .padding({ left: 16, right: 16, bottom: 12 })
      } else if (this.loadFailed) {
        Column({ space: 10 }) {
          Text('项目分类加载失败').fontSize(14).fontColor('#697483')
          Button('重新加载')
            .height(36)
            .fontColor('#2878C8')
            .backgroundColor('#EAF4FF')
            .borderRadius(6)
            .onClick(() => this.loadCategories())
        }
        .height(140)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.categories.length > 0) {
        Scroll() {
          Row({ space: 12 }) {
            ForEach(this.categories, (item: IQuestionType, index: number) => {
              this.categoryCard(item, index)
            }, (item: IQuestionType) => item.id.toString())
          }
          .padding({ left: 16, right: 16, bottom: 12 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(124)

        Row() {
          Text(this.categories[this.selectedIndex].name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#273142')
          Blank()
          Text('下拉可刷新')
            .fontSize(11)
            .fontColor('#9AA4B2')
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 6 })
        .width('100%')

        QuestionListComp({
          typeId: this.categories[this.selectedIndex].id,
          questionBankType: 10,
          params: this.params,
          selfIndex: 0,
          emptyText: '该项目暂无题目'
        })
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
      } else {
        Column({ space: 8 }) {
          Text('暂无项目分类').fontSize(15).fontColor('#697483')
          Text('请稍后重试').fontSize(12).fontColor('#9AA4B2')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .padding({ top: this.topHeight, bottom: 2 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.common_gray_bg'))
  }
}
