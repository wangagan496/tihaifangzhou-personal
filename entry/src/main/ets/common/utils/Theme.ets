import { ConfigurationConstant } from '@kit.AbilityKit'

class Theme {
  initTheme(): void {
    // 持久化主题色
    PersistentStorage.persistProp('COLOR_MODE', ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
    // 取出存储的主题色
    let colorMode = AppStorage.get<ConfigurationConstant.ColorMode>('COLOR_MODE')
    this.setTheme(colorMode!)
  }

  // 设置主题色
  setTheme(mode: ConfigurationConstant.ColorMode): void {
    AppStorage.set('COLOR_MODE', mode)
    let ctx = AppStorage.get<Context>('context')
    if (ctx) {
      ctx.getApplicationContext().setColorMode(mode)
    }
    AppStorage.setOrCreate('isDark', mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
  }

  // 未设置主题色，跟随系统
  notSet(): void {

    this.setTheme(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
  }

  // 浅色主题
  setLight(): void {
    this.setTheme(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
  }

  // 深色主题
  setDark(): void {
    this.setTheme(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
  }
}

export  const theme = new Theme()
