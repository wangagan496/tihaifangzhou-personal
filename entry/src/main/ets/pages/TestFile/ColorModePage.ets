import { ConfigurationConstant } from '@kit.AbilityKit';

@Entry
@Component
struct ColorModePage {
  @State message: string = 'Hello World';

  build() {
    Column({ space: 40 }) {
      Button('深色模式')
        .onClick(() => {
          const ctx = AppStorage.get<Context>('context')
          if (!ctx) {
            return
          }
          ctx.getApplicationContext()
            .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)

        })
      Button('浅色模式')
        .onClick(() => {
          const ctx = AppStorage.get<Context>('context')
          if (!ctx) {
            return
          }
          ctx.getApplicationContext()
            .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)

        })
        .backgroundColor($r('app.color.common_blue'))
      Button('跟随模式')
        .onClick(() => {
          const ctx = AppStorage.get<Context>('context')
          if (!ctx) {
            return
          }
          ctx.getApplicationContext()
            .setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)

        })
    }
    .height('100%')
    .width('100%')
  }
}