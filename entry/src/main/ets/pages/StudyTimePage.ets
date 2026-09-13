import { IvSkeleton } from '../common/components/IvSkeleton'
import { tgRequest } from '../common/utils/request'
import { windowManager } from '../common/utils/WindowManager'
import { auth } from '../common/utils/Auth'
import { studyTimeStore } from '../common/utils/StudyTimeStore'


export interface StudyTimeItem {
  id: string
  name: string
  total: number
  done: number
  undone: number
}

export interface StudyTimeCate {
  type: string,
  list: StudyTimeItem[]
}

export interface StudyTimeData {
  totalTime: number,
  studyData: StudyTimeCate[]
}

@Entry
@Component
struct StudyTimePage {
  @State
  knowledge: StudyTimeItem[] = []
  @State
  project: StudyTimeItem[] = []
  @State
  totalTime: number = 0
  @StorageProp('topHeight')
  topHeight: number = 0

  // 秒转换成分钟或者小时
  getTimeText(time: number = 0, hasUnit = true) {
    if (time < 3600) {
      return String(Math.floor(time / 60)) + (hasUnit ? ' 分钟' : '')
    } else {
      return String(Math.round(time / 3600 * 10) / 10) + (hasUnit ? ' 小时' : '')
    }
  }

  //  转换成百分比
  getPercentText(value: number, total: number) {
    if (total <= 0) {
      return '0%'
    }
    return Math.min(100, Math.max(0, Math.round(value / total * 100))) + '%'
  }

  aboutToAppear(): void {
    windowManager.setStatusBarLight()
    this.getData()
  }

  aboutToDisappear(): void {
    windowManager.setStatusBarDark()
  }

  async getData() {
    this.totalTime = studyTimeStore.getTotalTime(auth.getUser()?.id)
    try {
      const res = await tgRequest<StudyTimeData>({ url: '/hm/studyInfo' })
      const categories = res.studyData || []
      this.knowledge = categories.length > 0 ? categories[0].list : []
      this.project = categories.length > 1 ? categories[1].list : []
    } catch (_) {
      this.project = []
      this.knowledge = []
    }
  }

  build() {
    Navigation() {
      Scroll() {
        Column() {
          Row() {
            Text('累计学习时长').margin({ right: (4) })
            Image($r('app.media.icon_study_clock')).width((14)).height((14))
          }.width('100%').margin({ bottom: (10) })

          Row() {
            Text(this.getTimeText(this.totalTime, false)).fontSize((40)).fontWeight(FontWeight.Bold)
            Text(this.totalTime < 3600 ? '分钟' : '小时').margin({ bottom: (8), left: (8) })
          }.width('100%').alignItems(VerticalAlign.Bottom).margin({ bottom: (20) })

          if (this.knowledge.length > 0) {
            Column() {
              Text('知识点学习进度').margin({ bottom: (10) })
              GridRow({ columns: 2, gutter: 20 }) {
                ForEach(this.knowledge, (item: StudyTimeItem) => {
                  GridCol() {
                    Column() {
                      Row() {
                        Text(item.name).fontColor('#c3c4c5').fontSize((14))
                        Text(this.getPercentText(item.done, item.total)).fontColor('#c3c4c5').fontSize((14))
                      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: (5) })

                      Progress({ value: item.done, total: item.total }).color('#87E0CD')
                    }
                  }
                })

                GridCol({ span: 2 }) {
                  Row() {
                    Text()
                      .width((7))
                      .height((7))
                      .borderRadius((4))
                      .backgroundColor('#87E0CD')
                      .margin({ right: (4) })
                    Text('已学占比').fontSize((12)).margin({ right: (20) })
                    Text()
                      .width((7))
                      .height((7))
                      .borderRadius((4))
                      .backgroundColor('#c3c4c5')
                      .margin({ right: (4) })
                    Text('未学占比').fontSize((12))
                  }.justifyContent(FlexAlign.Center)
                }
              }.backgroundColor('#fff').borderRadius((4)).padding((15))

            }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: (25) })
          } else {
            // todo:骨架屏
            Grid() {
              ForEach(Array.from({ length: 20 }), () => {
                GridItem() {
                  IvSkeleton({ widthValue: 150, heightValue: 20 })
                }
                .margin({ bottom: 10 })
              })

            }
            .columnsTemplate('1fr 1fr')
          }


          Column() {
            Text('项目常问学习进度').margin({ bottom: (10) })
            if (this.project.length > 0) {
              GridRow({ columns: 1 }) {
                ForEach(this.project, (item: StudyTimeItem) => {
                  GridCol() {
                    Column() {
                      Row() {
                        Text(item.name).fontColor('#c3c4c5').fontSize((14))
                        Text(this.getPercentText(item.done, item.total)).fontColor('#c3c4c5').fontSize((14))
                      }.width('100%').justifyContent(FlexAlign.SpaceBetween)
                      .margin({ bottom: (5) })

                      Progress({ value: item.done, total: item.total }).color('#c7b5ed').width('100%')
                    }.margin({ bottom: (25) })
                  }
                })

                GridCol({ span: 2 }) {
                  Row() {
                    Text()
                      .width((7))
                      .height((7))
                      .borderRadius((4))
                      .backgroundColor('#c7b5ed')
                      .margin({ right: (4) })
                    Text('已学占比').fontSize((12)).margin({ right: (20) })
                    Text()
                      .width((7))
                      .height((7))
                      .borderRadius((4))
                      .backgroundColor('#c3c4c5')
                      .margin({ right: (4) })
                    Text('未学占比').fontSize((12))
                  }.justifyContent(FlexAlign.Center)
                }
              }.backgroundColor('#fff').borderRadius((4)).padding((15))

            } else {
              // todo:骨架屏
              Column() {
                ForEach(Array.from({ length: 4 }), () => {
                  IvSkeleton({ widthValue: 340, heightValue: 20 })
                    .margin({ bottom: 10 })
                })
              }
            }
          }.width('100%').alignItems(HorizontalAlign.Start)

        }.padding((15))
      }
    }
    .title('学习数据')
    .titleMode(NavigationTitleMode.Mini)
    .mode(NavigationMode.Stack)
    // .margin({ top: this.topHeight })
    .linearGradient({
      angle: 163,
      colors: [['#defbee', 0], ['#dbf4f1', 0.2], ['#f6f7f9', 1]]
    })
    .padding({ top: this.topHeight })
  }
}
