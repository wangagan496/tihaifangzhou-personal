import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DEMO_PASSWORD, DEMO_USERNAME } from 'BuildProfile';
import { theme } from '../common/utils/Theme';
import { appDiagnostics } from '../common/utils/AppDiagnostics';
import { studyCardRoute } from '../common/utils/StudyCardPolicy';
import { readAloud } from '../common/utils/ReadAloud';
import { openPendingStudyCard } from '../common/utils/StudyCardNavigation';

const DOMAIN = 0x0000;
const DEMO_USERNAME_PARAM = 'demoUsername';
const DEMO_PASSWORD_PARAM = 'demoPassword';

export default class EntryAbility extends UIAbility {
  private mainWindow?: window.Window
  // 启动链路的第一步：保存 Context，供 Preferences、RDB 等非组件工具使用。
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate('context', this.context)
    AppStorage.setOrCreate('SYSTEM_COLOR_MODE', this.context.config.colorMode)
    AppStorage.setOrCreate(DEMO_USERNAME_PARAM, DEMO_USERNAME)
    AppStorage.setOrCreate(DEMO_PASSWORD_PARAM, DEMO_PASSWORD)
    this.applyDemoLoginParameters(want)
    this.receiveCardAction(want)
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onCreate');
    appDiagnostics.start(this.context)
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyDemoLoginParameters(want)
    this.receiveCardAction(want)
  }

  private receiveCardAction(want: Want): void {
    const action = want.parameters?.['studyCardAction']
    if (typeof action !== 'string' || !studyCardRoute(action)) { return }
    AppStorage.setOrCreate('studyCardAction', action)
    this.openCardAction()
  }

  private openCardAction(): void {
    const win = this.mainWindow
    if (win) { openPendingStudyCard(win.getUIContext()) }
  }

  private applyDemoLoginParameters(want: Want): void {
    const username = want.parameters?.[DEMO_USERNAME_PARAM]
    const password = want.parameters?.[DEMO_PASSWORD_PARAM]
    if (typeof username !== 'string' || typeof password !== 'string' ||
      username.trim().length === 0 || password.length === 0) {
      return
    }
    AppStorage.setOrCreate(DEMO_USERNAME_PARAM, username.trim())
    AppStorage.setOrCreate(DEMO_PASSWORD_PARAM, password)
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    if (newConfig.colorMode !== undefined) {
      AppStorage.setOrCreate('SYSTEM_COLOR_MODE', newConfig.colorMode)
      theme.updateSystemColorMode(newConfig.colorMode)
    }
  }

  onDestroy(): void {
    readAloud.stop()
    appDiagnostics.stop()
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onDestroy');
  }

  // 主窗口创建后初始化主题并加载 Index；Index 再组织四个一级 Tab。
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onWindowStageCreate');
    theme.initTheme()
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'EntryAbility', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'EntryAbility', 'Succeeded in loading content.');
      this.mainWindow = windowStage.getMainWindowSync()
      this.openCardAction()
    });
  }

  onWindowStageDestroy(): void {
    this.mainWindow = undefined
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onForeground');
  }

  onBackground(): void {
    readAloud.stop()
    hilog.info(DOMAIN, 'EntryAbility', 'Ability onBackground');
  }
}
