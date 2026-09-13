import { auth } from '../common/utils/Auth';
import { SettingsThemeDialog } from '../views/SettingsPage/SettingsThemeDialog';
import { bundleManager, ConfigurationConstant } from '@kit.AbilityKit';
import { storageStatistics } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';

export interface Tool {
  icon?: ResourceStr
  name: string
  value?: string
  onClick?: () => void,
  radius?: 0 | 1 | 2,
  enabled?: boolean
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
  @State isClearingCache: boolean = false
  @State version: string = '1.0.0'
  private clearCacheConfirmConfig: promptAction.ShowDialogOptions = {
    title: '清除应用缓存',
    message: '仅清除临时缓存，不会删除账号、收藏、错题或录音。',
    buttons: [
      { text: '取消', color: $r('app.color.common_gray_01') },
      { text: '清除', color: $r('app.color.common_blue') }
    ]
  }

  getVersion(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).then((bundleInfo): void => {
      this.version = 'v' + bundleInfo.versionName
    }, (): void => {
      this.version = '未知版本'
    })
  }

  // 获取缓存大小
  getCache(): void {
    try {
      storageStatistics.getCurrentBundleStats().then((res): void => {
        const cacheSizeInMB = (res.cacheSize / (1024 * 1024)).toFixed(2)
        this.cache = `${cacheSizeInMB}MB`
      }, (): void => {
        this.cache = '未知'
      })
    } catch (_) {
      this.cache = '未知'
    }
  }

  // 清除缓存
  confirmClearCache(): void {
    if (this.isClearingCache) {
      return
    }
    try {
      this.getUIContext().getPromptAction().showDialog(this.clearCacheConfirmConfig).then((result) => {
        if (result.index === 1) {
          this.clearCache()
        }
      }, () => this.showToast('操作失败，请稍后重试'))
    } catch (_) {
      this.showToast('操作失败，请稍后重试')
    }
  }

  // 交给系统只清理当前应用的缓存数据，避免删除 cacheDir 根目录。
  async clearCache(): Promise<void> {
    if (this.isClearingCache) {
      return
    }
    this.isClearingCache = true
    try {
      await bundleManager.cleanBundleCacheFilesForSelf()
      this.showToast('清除成功')
    } catch (_) {
      this.showToast('清除失败，请稍后重试')
    } finally {
      this.isClearingCache = false
      this.getCache()
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      return
    }
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
          name: '账号设置', radius: 1, onClick: () => {
            auth.checkAuth({ url: 'pages/AccountSettingsPage' })
          }
        })
        Blank()
          .height(15)
        this.toolsBuilder({
          name: '消息推送', radius: 1, onClick: () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/MessageSettingsPage' })
          }
        })
        this.toolsBuilder({
          name: '评分服务配置', onClick: () => {
            auth.checkAuth({ url: 'pages/ScoreSettingsPage' })
          }
        })
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
          name: '清除应用缓存',
          value: this.isClearingCache ? '清除中…' : this.cache,
          enabled: !this.isClearingCache,
          onClick: () => this.confirmClearCache()
        })
        this.toolsBuilder({
          name: '当前版本', value: this.version, radius: 2, onClick: () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/MineAboutPage' })
          }
        })
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
      if (tool.enabled !== false) {
        tool.onClick && tool.onClick()
      }
    })
    .enabled(tool.enabled !== false)
    .opacity(tool.enabled === false ? 0.6 : 1)
  }
}
