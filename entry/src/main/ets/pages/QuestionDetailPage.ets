import { IvSkeleton } from '../common/components/IvSkeleton'
import { QuestionShareDialog } from '../common/components/QuestionShareDialog'
import { TgLoadingDialog } from '../common/components/TgLoadingDialog'
import { tgRequest } from '../common/utils/request'
import { TgTag } from '../views/home/TgTag'
import { tracking } from '../common/utils/Tracking'
import { auth } from '../common/utils/Auth'
import { mineQuestionStore } from '../common/utils/MineQuestionStore'
import { MineQuestionRecord } from '../common/utils/MineQuestionPolicy'
import { studyTimeStore } from '../common/utils/StudyTimeStore'
import { resolveInterviewIcon } from '../common/utils/InterviewIcon'

export interface QuestionDetail {
  id: string
  questionNo?: string
  stem: string
  difficulty: number
  likeCount: number
  views: number
  readFlag: 0 | 1
  answer?: string
  content?: string
  collectFlag: 0 | 1
  likeFlag: 0 | 1
  stage?: Array<string>
  creatorName?: string
  creatorAvatar?: string
  createdAt?: string
}

export interface IBodyData {
  /**
   * 试题id
   */
  id: string;

  /**
   * 1点赞2收藏
   */
  optType: number;

  /**
   * 0面试题1面经
   */
  type?: number;
}

//接收参数的实体
export interface ParamsType {
  id: string
  type?: 0 | 1
  questionNo?: string
}

@Entry
@Component
export struct QuestionDetailPage {
  @State
  questionId: string = ''
  @State
  question: QuestionDetail = {} as QuestionDetail
  @State
  contentType: 0 | 1 = 0
  private routeQuestionNo: string = ''
  @StorageProp('topHeight') topHeight: number = 0
  private loadingController: CustomDialogController | undefined = undefined
  @State
  isLoading: boolean = true
  @State
  interviewReadComplete: boolean = false
  private interviewStartAt: number = 0
  private questionTrackingStarted: boolean = false

  // 1、变量保存收集的时间点，id
  // 2、数据请求成功，保存时间点，id
  // 3、退出界面，保存时间点

  aboutToAppear(): void {
    this.loadQuestionFromRoute()
  }

  // 离开页面或连续切换内容前保存当前阅读进度。
  aboutToDisappear(): void {
    this.saveReadingProgress()
  }

  private loadQuestionFromRoute(): void {
    const params = this.getUIContext().getRouter().getParams() as ParamsType
    if (params && params.id) {
      this.contentType = params.type === 1 ? 1 : 0
      this.routeQuestionNo = params.questionNo || ''
      this.getData(params.id)
      return
    }
    this.isLoading = false
    this.showToast('题目参数无效')
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message })
  }

  // 1、自定义的加载弹窗，实现，使用ai完成
  // 帮我在这个页面上添加自定义加载弹窗，这个弹窗在项目中写好了，直接使用，发请求之前打开，请求完成之后关闭。
  // 2、加上骨架屏，使用布尔值控制，渲染动态数据的地方，使用骨架屏
  getData(id: string): void {
    this.questionId = id
    this.interviewReadComplete = false
    this.loadingController = new CustomDialogController({
      builder: TgLoadingDialog({ message: '加载中...' }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      offset: { dx: 0, dy: 0 },
      gridCount: 4,
      customStyle: true,
      backgroundColor: 'transparent'
    })
    this.loadingController.open()
    tgRequest<QuestionDetail>({ url: `/hm/question/${this.questionId}` }).then((result): void => {
      this.question = result
      this.isLoading = false
      const userId = auth.getUser()?.id
      if (userId) {
        mineQuestionStore.recordHistory(userId, this.toMineQuestionRecord())
      }
      if (this.contentType === 1) {
        this.interviewStartAt = Date.now()
        this.questionTrackingStarted = false
      } else {
        tracking.start(this.questionId)
        this.questionTrackingStarted = true
      }
      this.closeLoading()
    }, (): void => {
      this.isLoading = false
      this.showToast(this.contentType === 1 ? '获取面经详情失败' : '获取题目详情失败')
      this.closeLoading()
    })
  }

  private closeLoading(): void {
    if (this.loadingController) {
      this.loadingController.close()
      this.loadingController = undefined
    }
  }

  private saveReadingProgress(): void {
    if (this.contentType === 1) {
      if (this.interviewStartAt <= 0) {
        return
      }
      const startedAt = this.interviewStartAt
      const endedAt = Date.now()
      const stayTime = Math.max(1, Math.floor((endedAt - startedAt) / 1000))
      const questionNo = this.question.questionNo || this.routeQuestionNo
      this.interviewStartAt = 0
      studyTimeStore.record(auth.getUser()?.id, this.questionId, startedAt, endedAt)
      if (!questionNo) {
        return
      }
      tgRequest({
        url: '/hm/interview/tracking',
        method: 'POST',
        data: {
          questionNo,
          stayTime,
          exp: this.interviewReadComplete
        }
      }).then((): void => {}, (): void => {})
      return
    }
    if (this.questionTrackingStarted) {
      this.questionTrackingStarted = false
      tracking.save()
    }
  }

  private toMineQuestionRecord(): MineQuestionRecord {
    return {
      id: this.question.id,
      stem: this.question.stem,
      difficulty: this.question.difficulty,
      likeCount: this.question.likeCount,
      views: this.question.views,
      readFlag: this.question.readFlag,
      contentType: this.contentType,
      questionNo: this.question.questionNo || this.routeQuestionNo
    }
  }

  private getStages(): string[] {
    return this.question.stage ? this.question.stage : []
  }

  private getDetailContent(): string {
    if (this.contentType === 1) {
      return this.question.content || '<p>暂无面经正文</p>'
    }
    return this.question.answer || '<p>暂无答案内容</p>'
  }

  // 跳转上一题，下一题
  onPreOrNext(sign: 'pre' | "next"): void {
    // 题目列表id
    const idList = AppStorage.get('idList') as Array<string>
    const questionNoList = AppStorage.get('questionNoList') as Array<string>
    // 判断题目列表是否为空
    if (!idList || idList.length === 0) {
      this.showToast('题目列表为空')
      return
    }
    // 获取题目列表中当前题目的索引
    const selfIndex = idList.findIndex(item => item === this.questionId)
    // 判断题目id是否存在
    if (selfIndex === -1) {
      this.showToast('题目不存在')
      return
    }
    // 根据标识符判断是上一题还是下一题
    switch (sign) {
      case 'pre':
        if (selfIndex === 0) {
          this.showToast('已经是第一题了')
          return
        }
        this.saveReadingProgress()
        this.routeQuestionNo = questionNoList && questionNoList.length > selfIndex - 1 ? questionNoList[selfIndex - 1] : ''
        this.getData(idList[selfIndex - 1])
        break
      case 'next':
        if (selfIndex === idList.length - 1) {
          this.showToast('已经是最后一题了')
          return
        }
        this.saveReadingProgress()
        this.routeQuestionNo = questionNoList && questionNoList.length > selfIndex + 1 ? questionNoList[selfIndex + 1] : ''
        this.getData(idList[selfIndex + 1])
        break
    }
  }

  opt(flag: 1 | 0, optType: 1 | 2): void {
    tgRequest<null, IBodyData>({
        url: flag === 1 ? 'hm/question/opt' : 'hm/question/unOpt',
        method: 'POST',
        data: { id: this.questionId, type: this.contentType, optType }
      }).then((): void => {
      if (optType === 1) {
        this.question.likeFlag = flag
        const userId = auth.getUser()?.id
        if (userId) {
          mineQuestionStore.setFlag('like', userId, this.toMineQuestionRecord(), flag === 1)
        }
        this.showToast(flag === 1 ? '点赞成功' : '取消点赞成功')
      } else {
        this.question.collectFlag = flag
        const userId = auth.getUser()?.id
        if (userId) {
          mineQuestionStore.setFlag('collect', userId, this.toMineQuestionRecord(), flag === 1)
        }
        this.showToast(flag === 1 ? '收藏成功' : '取消收藏成功')
      }
    }, (): void => this.showToast('操作失败，请稍后重试'))
  }

  // 题目所属标签
  @Builder
  tagBuilder(text: string, color: string = '#41B883') {
    Text(text)
      .fontSize(12)
      .padding(5)
      .backgroundColor($r('app.color.ih_bg_color'))
      .borderRadius(2)
      .fontColor(color)
      .margin({ right: 5 })
  }

  // 上一题，下一题
  @Builder
  toggleBuilder() {
    Row() {
      Image($r("app.media.prev_black")).width((80)).onClick(() => {
        // 上一题业务逻辑
        this.onPreOrNext('pre')
      })
      Image($r("app.media.next_black")).width((80)).onClick(() => {
        // 下一题业务逻辑
        this.onPreOrNext('next')
      })
    }.width('100%').justifyContent(FlexAlign.SpaceAround)
  }

  dialog = new CustomDialogController({
    builder: QuestionShareDialog({
      item: this.question,
      contentType: this.contentType,
    }),
    customStyle: true,
  })

  build() {
    Navigation() {
      Flex({ direction: FlexDirection.Column }) {

        if (this.isLoading) {
          Column({ space: 20 }) {
            IvSkeleton({
              heightValue: 30, widthValue: 300
            })
            IvSkeleton({
              heightValue: 30, widthValue: 300
            })
          }
          .width('100%')
          .padding(15)

        } else {
          Column() {
            Column() {
              Row() {

                Text(this.question.stem).width('100%')

              }

              Row() {
                if (!this.isLoading && this.question.id) {
                  if (this.contentType === 1) {
                    Image(resolveInterviewIcon(this.question.stem, '', this.question.creatorName))
                      .width(32)
                      .height(32)
                      .objectFit(ImageFit.Contain)
                      .backgroundColor('#EAF4FF')
                      .borderRadius(16)
                    Column({ space: 2 }) {
                      Text(this.question.creatorName || '面经作者')
                        .fontSize(13)
                        .fontColor('#4C596A')
                      Text(this.question.createdAt || '发布时间未知')
                        .fontSize(11)
                        .fontColor('#9AA4B2')
                    }
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: 8 })
                  } else {
                    TgTag({ difficulty: this.question.difficulty || 0 })
                    ForEach(this.getStages(), (stage: string) => {
                      this.tagBuilder(stage)
                    })
                  }
                  Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.End }) {
                    Image($r('app.media.icon_point')).width(24).bindMenu([
                      {
                        value: this.question.collectFlag === 1 ? '取消收藏' : '收藏',
                        action: () => {
                          // 收藏和取消收藏业务逻辑代码
                          this.opt(this.question.collectFlag === 1 ? 0 : 1, 2)

                        }
                      },
                      {
                        value: this.question.likeFlag === 1 ? '取消点赞' : '点赞',
                        action: () => {
                          // 点赞和取消点赞业务逻辑代码
                          this.opt(this.question.likeFlag === 1 ? 0 : 1, 1)
                        }
                      },
                      {
                        value: this.contentType === 1 ? '面经分享' : '试题分享',
                        action: () => {
                          this.dialog.open()
                        }
                      }
                    ])
                  }
                  .layoutWeight(1)
                }
              }
              .height((40))
              .width('100%')
              .padding({ top: (15) })
            }.padding((15))
          }
        }

        Divider()
          .strokeWidth((8))
          .color($r('app.color.ih_bg_color'))

        if (this.isLoading) {
          Column({ space: 20 }) {
            ForEach(Array.from({ length: 9 }), () => {
              IvSkeleton({
                heightValue: 30, widthValue: 300
              })
            })
          }
          .width('100%')
          .padding(15)
        } else {
          Column() {
            Scroll() {

              RichText(`                      <html>
                      <body>
                        <div style="font-size:54px">${this.getDetailContent()}</div>
                      <body>
                      </html>
                      `)

            }
            .padding((15))
            .layoutWeight(1)
            .onReachEnd(() => {
              if (this.contentType === 1) {
                this.interviewReadComplete = true
              }
            })
          }.layoutWeight(1)
        }

      }
    }
    .padding({ top: this.topHeight })
    .title(this.contentType === 1 ? '面经详情' : '题目详情')
    .titleMode(NavigationTitleMode.Mini)
    .mode(NavigationMode.Stack)
    .toolbarConfiguration(this.toggleBuilder())
  }
}
