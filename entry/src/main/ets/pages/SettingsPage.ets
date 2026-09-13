import { auth } from '../common/utils/Auth';
import { SettingsThemeDialog } from '../views/SettingsPage/SettingsThemeDialog';
import { bundleManager, ConfigurationConstant } from '@kit.AbilityKit';
import { fileIo, storageStatistics } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';

export interface Tool {
  icon?: ResourceStr
  name: string
  value?: string
  onClick?: () => void,
  radius?: 0 | 1 | 2
}

@Entry
@Component
struct SettingsPage {
  @StorageProp('COLOR_MODE') colorMode: ConfigurationConstant.ColorMode =
    ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  @StorageProp('topHeight') topHeight: number = 0
  dialog = new CustomDialogController({
    builder: SettingsThemeDialog(),
    customStyle: true,
    alignment: DialogAlignment.Bottom
  })
  @State cache: string = '0MB'
  @State version: string = '1.0.0'

  getVersion(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).then((bundleInfo): void => {
      this.version = 'v' + bundleInfo.versionName
    }, (): void => {
      this.version = '未知版本'
    })
  }

  // 获取缓存大小
  getCache(): void {
    storageStatistics.getCurrentBundleStats().then((res): void => {
      // 缓存大小,单位为字节  bt  kb  mb gb
      // 单位转换，时间转换，逻辑处理 ，ai完成可以提高效率
      const cacheSizeInMB = (res.cacheSize / (1024 * 1024)).toFixed(2);
      this.cache = `${cacheSizeInMB}MB`;
    }, (): void => {
      this.cache = '未知'
    })
  }

  // 清除缓存
  clearCache(): void {
    let ctx = AppStorage.get<Context>('context')
    if (!ctx) {
      return
    }
    const cacheDir = ctx.cacheDir
    if (fileIo.accessSync(cacheDir)) {
      fileIo.rmdirSync(cacheDir)
    }
    this.getUIContext().getPromptAction().showToast({ message: '清除成功' })
    this.getCache()


  }

  aboutToAppear(): void {
    this.getCache()
    this.getVersion()
  }

  build() {
    Navigation() {
      Column({ space: 0.5 }) {
        Blank()
          .height(15)
        this.toolsBuilder({
          name: '编辑资料', radius: 1, onClick: () => {
            auth.checkAuth({
              url: 'pages/ProfileEditPage'
            })
          }
        })
        this.toolsBuilder({ name: '账号设置', radius: 2 })
        Blank()
          .height(15)
        this.toolsBuilder({ name: '消息推送', radius: 1 })
        this.toolsBuilder({
          name: '深色模式',
          value: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '已开启' : '已关闭',
          radius: 1,
          onClick: () => {
            // TODO 设置主题
            this.dialog.open()
          }
        })
        this.toolsBuilder({
          name: '清除应用缓存', value: this.cache, onClick: () => {
            // TODO 清除缓存
            this.clearCache()

          }
        })
        this.toolsBuilder({ name: '当前版本', value: this.version, radius: 2 })
        Blank()
          .height(15)
        Text('退出账号')
          .height(50)
          .fontColor($r('app.color.common_main_color'))
          .opacity(0.6)
          .onClick(async () => {
            auth.removeUser()
            this.getUIContext().getRouter().back()
          })
      }
      .layoutWeight(1)
      .padding({ right: 15, left: 15 })
      .backgroundColor($r('app.color.common_gray_bg'))
    }
    .title('设置')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight })

  }

  @Builder
  toolsBuilder(tool: Tool) {
    Row() {
      if (tool.icon) {
        Image(tool.icon)
          .width(16)
          .aspectRatio(1)
          .margin({ right: 12 })
      }
      Text(tool.name)
        .fontSize(16)
        .fontColor($r('app.color.common_gray_01'))
      Blank()
      if (tool.value) {
        Text(tool.value)
          .fontSize(14)
          .fontColor($r('app.color.common_gray_01'))
          .margin({ right: 10 })
      }
      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(18)
        .aspectRatio(1)
        .fillColor($r('app.color.common_gray_01'))
    }
    .height(50)
    .width('100%')
    .backgroundColor('#ffffff')
    .padding({ left: 16, right: 10 })
    .borderRadius({
      topLeft: tool.radius === 1 ? 8 : 0,
      topRight: tool.radius === 1 ? 8 : 0,
      bottomLeft: tool.radius === 2 ? 8 : 0,
      bottomRight: tool.radius === 2 ? 8 : 0
    })
    .onClick(() => {
      tool.onClick && tool.onClick()
    })
  }
}
