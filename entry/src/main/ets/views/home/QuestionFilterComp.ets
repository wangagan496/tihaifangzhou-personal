import { FilterButton } from "../../common/components/FilterButton"
import { IQuestionType } from "../../models/CategoryModel"


export class FilterParams {
  // 排序：0 默认 20 浏览量↑ 21 浏览量↓
  sort: number = 0
  // 阶段ID
  index: number = 0
}


@Component
export struct QuestionFilterComp {
  // controller: CustomDialogController
  @Prop
  questionTypeList: IQuestionType[] = []
  @Prop
  params: FilterParams = new FilterParams() // 表示的是当前面板用户选择的筛选条件
  // onSubmit
  // 子组件中定义了一个函数的变量，用来接收父组件传过来的方法
  onSubmit: (params: FilterParams) => void = () => {

  }

  @Builder
  TitleBuilder(title: string) {
    Text(title)
      .padding({ top: 10, bottom: 10 })
      .fontSize(14)
      .fontWeight(500)
  }

  build() {
    Column() {
      Row() {
        Text('重置')
          .fontSize(14)
          .onClick(() => {
            // 实例化FilterParams 类就完成了筛选条件的重置
            this.params = new FilterParams()
          })
        Text('筛选题目')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('完成')
          .fontSize(14)
          .fontColor($r('app.color.common_blue'))
          .onClick(() => {
            // 调用父组件中的回调函数
            this.onSubmit(this.params)
            // this.controller.close()
          })
      }
      .width('100%')
      .height(50)

      this.TitleBuilder('题目排序')
      Flex() {
        FilterButton({ text: '默认', isActive: this.params.sort === 0 })
          .onClick(() => this.params.sort = 0)
        FilterButton({
          text: '浏览量',
          isSort: true,
          isActive: this.params.sort > 0,
          sortValue: this.params.sort
        })
          .onClick(() => {
            if (this.params.sort) {
              this.params.sort = this.params.sort === 21 ? 20 : 21
            } else {
              this.params.sort = 21
            }
          })
      }

      this.TitleBuilder('选择阶段')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.questionTypeList, (item: IQuestionType, index: number) => {
          FilterButton({ text: item.name, isNew: item.displayNewestFlag === 1, isActive: this.params.index === index })
            .onClick(() => this.params.index = index)
        })
      }

    }
    .backgroundColor(Color.White)
    .padding({ left: $r('app.float.common_space16'), right: $r('app.float.common_space16') })
    .width('100%')
    .height(420)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .alignItems(HorizontalAlign.Start)

    // .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
    //   .animation({ duration: 300, curve: curves.springMotion(0.6, 0.8) }))
  }
}