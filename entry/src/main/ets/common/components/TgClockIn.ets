import { ILoginDta } from '../../models/AccountModel'
import { IClockData } from '../../models/HomeModels'
import { tgRequest } from '../utils/request'
import { promptAction } from '@kit.ArkUI'
import { auth } from '../utils/Auth'

@Component
export struct TgClockIn {
  @StorageProp('user') user: ILoginDta = {} as ILoginDta
  @Prop
  clockCount: number = 0

  aboutToAppear(): void {
    const user = auth.getUser()
    if (user?.token) {
      this.getData()
    }
  }

  getData(): Promise<void> {
    return tgRequest<IClockData>({ url: '/hm/clockinInfo' }).then((res): void => {
      this.clockCount = res.clockinNumbers
    }, (): void => {
      this.clockCount = 0
    })
  }

  onClock(): Promise<void> {
    return tgRequest({ url: '/hm/clockin', method: 'POST' }).then((): Promise<void> => {
      this.getUIContext().getPromptAction().showToast({ message: '打卡成功' })
      return this.getData()
    }, (): void => {
      this.getUIContext().getPromptAction().showToast({ message: '打卡失败，请稍后重试' })
    })
  }

  build() {
    Stack({ alignContent: Alignment.End }) {
      Image(this.clockCount > 0 ? $r('app.media.clocked') : $r('app.media.unclock'))
        .objectFit(ImageFit.Fill)
      if (this.clockCount > 0) {
        Column() {
          Text('已连续打卡')
            .fontSize(8)
          Text() {
            Span(this.clockCount.toString())
              .fontWeight(600)
              .fontSize(12)
            Span(' 天')
              .fontSize(10)
          }
        }
        .width('50')
        .onClick(() => {
          auth.checkAuth({
            url: 'pages/ClockPage'
          })
        })
      } else {
        Text('打卡')
          .width('50')
          .textAlign(TextAlign.Center)
          .fontSize((18))
          .fontWeight(500)
          .fontColor('#333C4F')
          .margin({ bottom: (4) })
          .onClick(() => {
            // 1、判断有没有登录
            // 2、获取打卡信息
            // 3、登录情况下，打卡，未登录情况，跳转登录
            if (!this.user.token) {
              auth.checkAuth({
                url: 'pages/ClockPage'
              })
            } else {
              this.onClock()
            }
          })
      }
    }
    .width((74))
    .height((28))
  }
}
