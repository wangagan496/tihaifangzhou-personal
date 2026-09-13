import { TgClockIn } from '../../common/components/TgClockIn'
import { TgSearch } from '../../common/components/TgSearch'
import { HomeCategoryComp } from './HomeCategoryComp'
import { scanBarcode } from '@kit.ScanKit'
import { auth } from '../../common/utils/Auth'


@Component
export default struct Home {
  // 获取AppStorage中的数据
  @StorageProp("topHeight") topHeight: number = 0

  scanQuestionCode() {
    if (canIUse('SystemCapability.Multimedia.Scan.ScanBarcode')) {
      scanBarcode.startScanForResult(this.getUIContext().getHostContext(), (err, res) => {
        if (res) {
          auth.checkAuth({
            url: 'pages/QuestionDetailPage',
            params: {
              id: res.originalValue
            }
          })
        }
      })
    }
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Image($r('app.media.ic_home_scan'))
          .width(24)
          .aspectRatio(1)
          .onClick(() => {
            this.scanQuestionCode()
          })
        // 1.0 搜索组件静态
        TgSearch()
          .layoutWeight(3) // 占3/4份
        // 2.0 打卡组件
        TgClockIn()
          .layoutWeight(1) //占1/4
      }
      .padding(10)

      // 3.0 轮播图
      Swiper() {
        Image($r('app.media.banner_qa'))
          .objectFit(ImageFit.Fill)
          .height(200)
          .borderRadius(10)


        Image($r('app.media.banner_pj'))
          .objectFit(ImageFit.Fill)
          .height(200)
          .borderRadius(10)


        Image($r('app.media.banner_ai'))
          .objectFit(ImageFit.Fill)
          .height(200)
          .borderRadius(10)

      }
      .padding(10)
      .autoPlay(true)
      .indicator(DotIndicator.dot()
        .selectedColor(Color.White)
        .bottom(20))

      //   4.0 使用题目的分类组件
      HomeCategoryComp()
        .layoutWeight(1)
    }
    .padding({ top: this.topHeight })
    .height('100%')
    .width('100%')
  }
}