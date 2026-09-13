import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant'
import { theme } from '../../common/utils/Theme'

@CustomDialog
export struct SettingsThemeDialog {
  controller: CustomDialogController
  @StorageProp("COLOR_MODE") colorMode: ConfigurationConstant.ColorMode =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET

  build() {
    Column() {
      Row() {
        Column({ space: 4 }) {
          Text('跟随系统')
          Text('开启后，将跟随系统打开或关闭深色模式')
            .fontSize(12)
            .fontColor($r('app.color.common_gray_01'))
        }
        .alignItems(HorizontalAlign.Start)

        Toggle({
          type: ToggleType.Switch,
          isOn: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET

        })
          .onChange((val) => {
            if (val) {
              // TODO 跟随系统
              theme.notSet()
            } else {
              // TODO 默认亮色
              theme.setLight()
            }
          })
      }
      .width('100%')
      .height(70)
      .justifyContent(FlexAlign.SpaceBetween)
      .border({ width: { bottom: 0.5 }, color: $r('app.color.common_gray_border') })


      //  1、判断是否跟随系统，不跟随系统则显示普通模式和深色模式
      //  2、判断在不跟随系统情况下，colorMode状态，显示对勾图标
      // 3、点击模式进行切换
      // 4、设置页面‘深色模式’ 显示是否开启
      if (this.colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
        Row() {
          Text('普通模式')
            .fontSize(15)
          Blank()
          if (this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
            Image($r('app.media.ic_public_ok'))
              .width(16)
              .aspectRatio(1)
              .fillColor($r('app.color.common_green'))
          }
        }
        .width('100%')
        .height(50)
        .border({ width: { bottom: 0.5 }, color: $r('app.color.common_gray_border') })
        .onClick(() => {
          theme.setLight()
        })

        Row() {
          Text('深色模式')
            .fontSize(15)
          Blank()
          if (this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
            Image($r('app.media.ic_public_ok'))
              .width(16)
              .aspectRatio(1)
              .fillColor($r('app.color.common_green'))
          }
        }
        .onClick(() => {
          theme.setDark()
        })
        .width('100%')
        .height(50)
      }

    }
    .padding({
      top: 15,
      bottom: 15,
      left: 30,
      right: 30
    })
    .borderRadius({
      topLeft: 10,
      topRight: 10,
    })
    .backgroundColor($r('app.color.white'))
  }
}