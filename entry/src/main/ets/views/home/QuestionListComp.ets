import { TgLoadingDialog } from '../../common/components/TgLoadingDialog'
import { tgRequest } from '../../common/utils/request'
import { IListData } from '../../models/HomeModels'
import { QuestionItem, QuestionItemComp } from './QuestionItemComp'
import { FilterParams } from './QuestionFilterComp'
import { auth } from '../../common/utils/Auth'
import { mineQuestionStore } from '../../common/utils/MineQuestionStore'
import {
  matchesQuestionKeyword,
  mergeUniqueQuestions,
  questionKey
} from '../../common/utils/QuestionListPolicy'

@Component
export struct QuestionListComp {
  @Watch('onDataSourceChange')
  @Prop typeId: number
  @Watch('onDataSourceChange')
  @Prop questionBankType: number = 10
  @Watch('onDataSourceChange')
  @Prop keyword: string = ''
  isInterview: boolean = false
  emptyText: string = '暂无题目'
  // 定义状态属性，类型：QuestionItem[]
  @State list: QuestionItem[] = []
  // 控制刷新
  @State refreshing: boolean = false
  page: number = 0
  totalPage: number = 1
  // 请求中
  @State isRequesting: boolean = false
  @State isInitialLoading: boolean = true
  @State loadFailed: boolean = false
  // 监听参数变化
  @Watch('onFilterParamsChange')
  @Prop params: FilterParams
  selfIndex: number = 0

  aboutToAppear(): void {
    this.loadData(false)
  }

  onFilterParamsChange() {
    this.loadData(false)
  }

  onDataSourceChange(): void {
    this.page = 0
    this.totalPage = 1
    this.list = []
    this.isInitialLoading = true
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
    this.loadFailed = false
    const nextPage = isLoadMore ? this.page + 1 : 1
    const interviewSearch = this.isInterview && this.keyword.trim().length > 0
    const pageSize = interviewSearch ? 500 : 10
    if (isLoadMore) {
      this.dialog.open()
    }
    return tgRequest<IListData>({
        url: '/hm/question/list',
        params: {
          type: this.typeId,
          questionBankType: this.questionBankType,
          page: nextPage,
          pageSize,
          sort: this.params.sort,
          keyword: interviewSearch ? '' : this.keyword
        }
      }).then((res): void => {
      this.page = nextPage
      this.totalPage = res.pageTotal
      const rows = interviewSearch
        ? res.rows.filter((item: QuestionItem) => matchesQuestionKeyword(item, this.keyword))
        : res.rows
      this.list = isLoadMore ? mergeUniqueQuestions(this.list, rows) : mergeUniqueQuestions([], rows)
      this.isRequesting = false
      this.isInitialLoading = false
      this.refreshing = false
      if (isLoadMore) {
        this.dialog.close()
      }
    }, (): void => {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: this.isInterview ? '面经加载失败，请稍后重试' : '题目加载失败，请稍后重试'
        })
      } catch (_) {
        // showToast 失败不影响主流程
      }
      this.isRequesting = false
      this.isInitialLoading = false
      this.loadFailed = !isLoadMore && this.list.length === 0
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
      if (this.isInitialLoading) {
        Column({ space: 12 }) {
          ForEach(Array.from({ length: 5 }), () => {
            Row() {
              LoadingProgress().width(22).height(22).color('#B8C2CE')
              Text(this.isInterview ? '正在加载面经' : '正在加载题目')
                .fontSize(13)
                .fontColor('#8A94A3')
                .margin({ left: 10 })
            }
            .height(68)
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(Color.White)
            .borderRadius(8)
          })
        }
        .padding({ top: 8 })
      } else if (this.loadFailed) {
        Column({ space: 12 }) {
          Text(this.isInterview ? '面经加载失败' : '题目加载失败')
            .fontSize(15)
            .fontColor('#697483')
          Button('重新加载')
            .height(38)
            .fontSize(14)
            .fontColor('#2878C8')
            .backgroundColor('#EAF4FF')
            .borderRadius(6)
            .onClick(() => {
              this.isInitialLoading = true
              this.loadData(false)
            })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.list.length === 0) {
        Column({ space: 8 }) {
          Text(this.emptyText).fontSize(15).fontColor('#697483')
          Text('可以尝试切换分类或调整搜索条件')
            .fontSize(12)
            .fontColor('#9AA4B2')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: this.isInterview ? 10 : 0 }) {
            ForEach(this.list, (item: QuestionItem) => {
              ListItem() {
                QuestionItemComp({ item, isInterview: this.isInterview })
                  .padding({ left: this.isInterview ? 0 : 10, right: this.isInterview ? 0 : 10 })
                  .onClick(() => {
                    const contentType: 0 | 1 = this.isInterview ? 1 : 0
                    const userId = auth.getUser()?.id
                    // 在跳转前同步设置 idList，确保详情页上下题导航始终对应当前列表
                    AppStorage.setOrCreate('idList', this.list.map((i: QuestionItem) => i.id))
                    AppStorage.setOrCreate('questionNoList', this.list.map((i: QuestionItem) => i.questionNo || ''))
                    if (userId) {
                      mineQuestionStore.recordHistory(userId, {
                        id: item.id,
                        stem: item.stem,
                        difficulty: item.difficulty || 0,
                        likeCount: item.likeCount || 0,
                        views: item.views || 0,
                        readFlag: item.readFlag === 1 ? 1 : 0,
                        contentType,
                        questionNo: item.questionNo
                      })
                    }
                    auth.checkAuth({
                      url: 'pages/QuestionDetailPage',
                      params: {
                        id: item.id,
                        type: contentType,
                        questionNo: item.questionNo,
                        stem: item.stem,
                        content: item.content,
                        creatorName: item.creatorName,
                        createdAt: item.createdAt,
                        questionTypeId: this.typeId,
                        questionBankType: this.questionBankType
                      }
                    })
                  })
              }
            }, (item: QuestionItem) => questionKey(item))
          }
          .layoutWeight(1)
          .onReachEnd(() => {
            if (!this.isRequesting && this.page < this.totalPage) {
              this.loadData(true)
            }
          })
        }
        .layoutWeight(1)
        .onRefreshing(() => {
          this.loadData(false)
        })
      }

    }
    .justifyContent(FlexAlign.Start)
    .layoutWeight(1)
  }
}
