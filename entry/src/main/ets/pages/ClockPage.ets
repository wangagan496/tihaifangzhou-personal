import { HmCalendar, HmCalendarSelectedDay } from '@ohmos/calendar'
import { tgRequest } from '../common/utils/request'
import { IClockData } from '../models/HomeModels'

@Entry
@Component
struct ClockPage {
  @StorageProp("topHeight") topHeight: number = 0
  @State totalClockinNumber: number = 0 //累计打卡
  @State clockinNumbers: number = 0 //连续打卡
  @State selectedDays: HmCalendarSelectedDay[] = []

  aboutToAppear(): void {
    this.getClockData()
  }

  // 1、onChangeMonth切换月份的时候触发，month参数
  // 2、修改getClockData函数，接收参数，请求也接收参数，
  async getClockData(date?: string) {
    let year: string = ''
    let month: string = ''
    if (date) {
      year = date.split('-')[0]
      month = date.split('-')[1]
    }
    const res = await tgRequest<IClockData>({
      url: "/hm/clockinInfo", params: {
        year,
        month
      }
    })
    this.totalClockinNumber = res.totalClockinNumber
    this.clockinNumbers = res.clockinNumbers
    this.selectedDays = res.clockins.map(item => {
      return {
        date: item.createdAt
      } as HmCalendarSelectedDay
    })
  }

  build() {
    Navigation() {
      Column({ space: 16 }) {
        Row() {
          this.dayBuilder({ day: this.totalClockinNumber, text: '累计打卡' })
          this.dayBuilder({ day: this.clockinNumbers, text: '连续打卡' })
        }
        .padding({
          top: 10,
          bottom: 25,
          left: 16,
          right: 16
        })
        .width('100%')
        .justifyContent(FlexAlign.Start)

        Row() {
          HmCalendar({
            color: '#0094ff',
            weeks: ['日', '一', '二', '三', '四', '五', '六'],
            text: '已打卡',
            selectedDays: this.selectedDays,
            onChangeMonth: (month) => {
              this.getClockData(month)
            }
          })
            .borderRadius(8)
            .border({ width: 0.5, color: '#ededed' })
            .shadow({ color: '#ededed', radius: 16 })

        }
        .padding({ left: 16, right: 16 })

      }
      .width('100%')
      .height('100%')
      .backgroundImage($r('app.media.clocked_bg'))
      .backgroundImageSize({ width: '100%' })
    }
    .title('每日打卡')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight + 15 })

  }

  // 累计打卡、连续打卡公共布局
  @Builder
  dayBuilder(params: DayBuilderParams) {
    Column() {
      Row() {
        Text(params.day.toString())
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
        Text('天')
          .fontSize(10)
          .fontColor($r('app.color.common_gray_01'))
          .margin({ bottom: 8, left: 10 })
      }
      .alignItems(VerticalAlign.Bottom)

      Text(params.text)
        .fontSize(10)
        .fontColor($r('app.color.common_gray_01'))
    }.margin({ right: 36 })
  }
}

interface DayBuilderParams {
  day: number
  text: string
}
