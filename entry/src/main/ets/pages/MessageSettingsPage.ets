import {
  MessageSettingKey,
  MessageSettings,
  messageSettingsStore
} from '../common/utils/MessageSettingsStore'
import { messageReminderService } from '../common/utils/MessageReminderService'
import { common } from '@kit.AbilityKit'
import { notificationManager } from '@kit.NotificationKit'

@Entry
@Component
struct MessageSettingsPage {
  @StorageProp('topHeight') topHeight: number = 0
  @State settings: MessageSettings = messageSettingsStore.load()
  @State notificationEnabled: boolean = false

  aboutToAppear(): void {
    this.settings = messageSettingsStore.load()
    this.refreshNotificationState()
    messageReminderService.apply(this.settings).then((): void => {}, (): void => {})
  }

  private async refreshNotificationState(): Promise<void> {
    try {
      this.notificationEnabled = await notificationManager.isNotificationEnabled()
    } catch (_) {
      this.notificationEnabled = false
    }
  }

  private updateSetting(key: MessageSettingKey, enabled: boolean): void {
    const next: MessageSettings = {
      studyProgress: this.settings.studyProgress,
      reviewReminder: this.settings.reviewReminder,
      featureUpdates: this.settings.featureUpdates,
      soundAndVibration: this.settings.soundAndVibration
    }
    switch (key) {
      case 'studyProgress':
        next.studyProgress = enabled
        break
      case 'reviewReminder':
        next.reviewReminder = enabled
        break
      case 'featureUpdates':
        next.featureUpdates = enabled
        break
      case 'soundAndVibration':
        next.soundAndVibration = enabled
        break
    }
    this.settings = next
    if (!messageSettingsStore.save(key, enabled)) {
      this.settings = messageSettingsStore.load()
      this.showToast('设置保存失败，请稍后重试')
      return
    }
    if (key === 'featureUpdates') {
      return
    }
    this.syncReminders(key === 'reviewReminder' || key === 'studyProgress' ? enabled : false)
      .then((): void => {}, (): void => {})
  }

  private async syncReminders(requestPermission: boolean): Promise<void> {
    if (requestPermission && !this.notificationEnabled) {
      await this.requestNotificationPermission()
    }
    const ok = await messageReminderService.apply(this.settings)
    await this.refreshNotificationState()
    if (!ok && (this.settings.reviewReminder || this.settings.studyProgress)) {
      this.showToast('设置已保存，提醒未生效，请先开启系统通知权限')
    }
  }

  private async requestNotificationPermission(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      await notificationManager.requestEnableNotification(context)
      await this.refreshNotificationState()
      if (this.notificationEnabled) {
        await messageReminderService.apply(this.settings)
      }
    } catch (_) {
      this.showToast('未能开启系统通知权限')
    }
  }

  private async sendTestNotification(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const ok = await messageReminderService.publishTest(this.settings, context)
    await this.refreshNotificationState()
    if (ok) {
      await messageReminderService.apply(this.settings)
    }
    this.showToast(ok ? '测试通知已发送' : '测试通知发送失败')
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      return
    }
  }

  @Builder
  switchRow(title: string, description: string, enabled: boolean, onChange: (value: boolean) => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title).fontSize(15).fontColor('#1F2937')
        Text(description).fontSize(12).fontColor('#8A94A3')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor('#3A9BFC')
        .onChange(onChange)
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 14, top: 10, bottom: 10 })
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: 16 }) {
          Column() {
            Row() {
              Column({ space: 4 }) {
                Text('系统通知权限').fontSize(15).fontColor('#1F2937')
                Text(this.notificationEnabled ? '系统通知已允许' : '系统通知尚未开启')
                  .fontSize(12)
                  .fontColor('#8A94A3')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(this.notificationEnabled ? '已开启' : '去开启')
                .fontSize(13)
                .fontColor(this.notificationEnabled ? '#2F9E66' : '#3A9BFC')
            }
            .height(62)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              if (!this.notificationEnabled) {
                this.requestNotificationPermission().then((): void => {}, (): void => {})
              }
            })
          }
          .backgroundColor(Color.White)
          .borderRadius(8)

          Column() {
            this.switchRow('学习进度通知', '学习时长与连续学习状态', this.settings.studyProgress,
              (value: boolean) => this.updateSetting('studyProgress', value))
            Divider().margin({ left: 16 }).color('#EEF1F4')
            this.switchRow('复习提醒', '收藏与历史题目的复习提示', this.settings.reviewReminder,
              (value: boolean) => this.updateSetting('reviewReminder', value))
            Divider().margin({ left: 16 }).color('#EEF1F4')
            this.switchRow('功能更新', '新功能和版本更新消息', this.settings.featureUpdates,
              (value: boolean) => this.updateSetting('featureUpdates', value))
            Divider().margin({ left: 16 }).color('#EEF1F4')
            this.switchRow('声音与振动', '通知到达时使用系统提示效果', this.settings.soundAndVibration,
              (value: boolean) => this.updateSetting('soundAndVibration', value))
          }
          .backgroundColor(Color.White)
          .borderRadius(8)

          Button('发送测试通知')
            .width('100%')
            .height(46)
            .fontColor('#2878C8')
            .backgroundColor('#EAF4FF')
            .borderRadius(8)
            .onClick(() => this.sendTestNotification())
        }
        .width('100%')
        .padding(16)
      }
      .backgroundColor($r('app.color.common_gray_bg'))
    }
    .title('消息推送')
    .titleMode(NavigationTitleMode.Mini)
    .padding({ top: this.topHeight })
  }
}
