import { FilterParams } from '../home/QuestionFilterComp'
import { QuestionListComp } from '../home/QuestionListComp'

@Component
export default struct Interview {
  @StorageProp('topHeight') topHeight: number = 0
  @State keyword: string = ''
  @State queryKeyword: string = ''
  @State params: FilterParams = new FilterParams()
  @State selectedSort: number = 0

  private applySearch(): void {
    this.queryKeyword = this.keyword.trim()
  }

  private changeSort(index: number): void {
    const sortValues: number[] = [0, 30, 21]
    const next = new FilterParams()
    next.sort = sortValues[index]
    next.index = 0
    this.selectedSort = index
    this.params = next
  }

  build() {
    Column() {
      Column({ space: 4 }) {
        Text('面经')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182230')
          .width('100%')
        Text('阅读真实面试经验，结合热度与时间快速筛选')
          .fontSize(13)
          .fontColor('#758092')
          .width('100%')
      }
      .padding({ left: 16, right: 16, top: 14, bottom: 12 })

      Row({ space: 10 }) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_common_search'))
            .width(18)
            .aspectRatio(1)
            .fillColor('#8A94A3')
          TextInput({ placeholder: '搜索标题或作者', text: $$this.keyword })
            .fontSize(14)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onSubmit(() => this.applySearch())
        }
        .height(42)
        .layoutWeight(1)
        .padding({ left: 12, right: 8 })
        .backgroundColor(Color.White)
        .borderRadius(6)
        Text('搜索')
          .fontSize(14)
          .fontColor('#2878C8')
          .onClick(() => this.applySearch())
      }
      .padding({ left: 16, right: 16, bottom: 10 })

      Row() {
        Text(this.queryKeyword ? `“${this.queryKeyword}”的搜索结果` : '全部面经')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#273142')
        Blank()
        Select([
          { value: '最新' },
          { value: '推荐' },
          { value: '浏览最多' }
        ])
          .selected(this.selectedSort)
          .value(this.selectedSort === 0 ? '最新' : this.selectedSort === 1 ? '推荐' : '浏览最多')
          .onSelect((index: number) => this.changeSort(index))
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      QuestionListComp({
        typeId: 0,
        questionBankType: 9,
        keyword: this.queryKeyword,
        params: this.params,
        selfIndex: 0,
        isInterview: true,
        emptyText: '暂无符合条件的面经'
      })
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
    }
    .padding({ top: this.topHeight, bottom: 2 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.common_gray_bg'))
  }
}
