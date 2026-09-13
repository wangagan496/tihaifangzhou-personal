import { TgLoadingDialog } from '../../common/components/TgLoadingDialog'
import { tgRequest } from '../../common/utils/request'
import { IListData } from '../../models/HomeModels'
import { QuestionItem, QuestionItemComp } from './QuestionItemComp'
import { FilterParams } from './QuestionFilterComp'
import { auth } from '../../common/utils/Auth'
import { mineQuestionStore } from '../../common/utils/MineQuestionStore'

@Component
export struct QuestionListComp {
  @Prop typeId: number
  // 定义状态属性，类型：QuestionItem[]
  @State list: QuestionItem[] = []
  // 控制刷新
  @State refreshing: boolean = false
  page: number = 0
  totalPage: number = 1
  // 请求中
  @State isRequesting: boolean = false
  // 监听参数变化
  @Watch('onFilterParamsChange')
  @Prop params: FilterParams
  selfIndex: number = 0
  // 搜索参数
  keyword: string = ''

  onFilterParamsChange() {
    this.loadData(false)
  }

  // 1、给列表传递selfIndex
  // 2、比较selfIndex和params.index，如果相同则加载数据

  // 刷新替换第一页，加载更多追加下一页；只有请求成功后才推进 page。
  loadData(isLoadMore: boolean): Promise<void> {
    if (this.selfIndex !== this.params.index) {
      return Promise.resolve()
    }
    if (this.isRequesting) {
      return Promise.resolve()
    }

    if (isLoadMore) {
      // 加载更多
      if (this.page >= this.totalPage) {
        return Promise.resolve()
      }
    }

    this.isRequesting = true
    const nextPage = isLoadMore ? this.page + 1 : 1
    if (isLoadMore) {
      this.dialog.open()
    }
    return tgRequest<IListData>({
        url: '/hm/question/list',
        params: {
          type: this.typeId,
          questionBankType: 10,
          page: nextPage,
          sort: this.params.sort,
          keyword: this.keyword
        }
      }).then((res): void => {
      this.page = nextPage
      this.totalPage = res.pageTotal
      this.list = isLoadMore ? this.list.concat(res.rows) : res.rows
      AppStorage.setOrCreate('idList', this.list.map(item => item.id))
      this.isRequesting = false
      this.refreshing = false
      if (isLoadMore) {
        this.dialog.close()
      }
    }, (): void => {
      this.getUIContext().getPromptAction().showToast({ message: '题目加载失败，请稍后重试' })
      this.isRequesting = false
      this.refreshing = false
      if (isLoadMore) {
        this.dialog.close()
      }
    })
  }

  // 自定义弹窗
  dialog = new CustomDialogController({
    builder: TgLoadingDialog({ message: '加载中...' }),
    customStyle: true,
  })

  build() {
    Column() {
      Refresh({ refreshing: $$this.refreshing }) {
        List() {
          ForEach(this.list, (item: QuestionItem) => {
            ListItem() {
              QuestionItemComp({
                item
              })
                .padding({ left: 10, right: 10 })
                .onClick(() => {
                  const userId = auth.getUser()?.id
                  if (userId) {
                    mineQuestionStore.recordHistory(userId, {
                      id: item.id,
                      stem: item.stem,
                      difficulty: item.difficulty,
                      likeCount: item.likeCount,
                      views: item.views,
                      readFlag: item.readFlag
                    })
                  }
                  auth.checkAuth({
                    url: 'pages/QuestionDetailPage',
                    params: {
                      id: item.id
                    }
                  })
                })
            }
          })
        }.layoutWeight(1)
        .onReachEnd(() => {
          if (!this.isRequesting && this.page < this.totalPage) {
            this.loadData(true)
          }
        })
      }.layoutWeight(1)
        .onRefreshing(() => {
          this.loadData(false)
        })

    }
    .justifyContent(FlexAlign.Start)
    .layoutWeight(1)
  }
}
