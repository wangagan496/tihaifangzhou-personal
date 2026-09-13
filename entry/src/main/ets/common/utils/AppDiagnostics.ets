import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { hiAppEvent, hilog } from '@kit.PerformanceAnalysisKit'
import { createDiagnosticRecord, DiagnosticRecord, mergeDiagnosticRecords, readDiagnosticHistory } from './DiagnosticPolicy'

const DOMAIN: number = 0x0000
const TAG: string = 'AppDiagnostics'
const STORE_NAME: string = 'app_diagnostics_v1'
const HISTORY_KEY: string = 'events'

class AppDiagnostics {
  private watcher?: hiAppEvent.Watcher
  private writeQueue: Promise<void> = Promise.resolve()

  start(context: common.UIAbilityContext): void {
    if (this.watcher) {
      return
    }
    const appContext = context.getApplicationContext()
    const watcher: hiAppEvent.Watcher = {
      name: 'thfz_fault_watcher',
      appEventFilters: [{ domain: hiAppEvent.domain.OS, names: [hiAppEvent.event.APP_CRASH, hiAppEvent.event.APP_FREEZE] }],
      onReceive: (domain: string, groups: hiAppEvent.AppEventGroup[]) => {
        if (domain === hiAppEvent.domain.OS) {
          this.receive(appContext, groups)
        }
      }
    }
    try {
      hiAppEvent.addWatcher(watcher)
      this.watcher = watcher
      hilog.info(DOMAIN, TAG, 'Crash and freeze watcher registered')
    } catch (_) {
      hilog.warn(DOMAIN, TAG, 'Fault watcher unavailable; application startup continues')
    }
    this.enablePageSwitchLogs()
  }

  private async enablePageSwitchLogs(): Promise<void> {
    try {
      // API 24 adds page-switch history to system fault logs; this does not repair RenderService.
      await hiAppEvent.configEventPolicy({
        appCrashPolicy: { pageSwitchLogEnable: true },
        appFreezePolicy: { pageSwitchLogEnable: true }
      })
      hilog.info(DOMAIN, TAG, 'API 24 crash/freeze page-switch logging enabled')
    } catch (_) {
      hilog.warn(DOMAIN, TAG, 'Page-switch fault logging unavailable; application startup continues')
    }
  }

  private receive(context: common.ApplicationContext, groups: hiAppEvent.AppEventGroup[]): void {
    const records: DiagnosticRecord[] = []
    for (const group of groups) {
      for (const event of group.appEventInfos) {
        if (event.domain !== hiAppEvent.domain.OS) {
          continue
        }
        const params = event.params as Record<string, hiAppEvent.ParamType>
        const time: hiAppEvent.ParamType = params['time']
        const pid: hiAppEvent.ParamType = params['pid']
        const foreground: hiAppEvent.ParamType = params['foreground']
        const record = createDiagnosticRecord(event.name, typeof time === 'number' ? time : 0,
          typeof pid === 'number' ? pid : 0, typeof foreground === 'boolean' ? foreground : undefined)
        if (record) {
          records.push(record)
          hilog.info(DOMAIN, TAG, 'System fault received: %{public}s time=%{public}s pid=%{public}d',
            record.name, record.time.toString(), record.pid)
        }
      }
    }
    if (records.length === 0) {
      return
    }
    // Serialize async read/merge/flush so adjacent callbacks cannot overwrite one another.
    this.writeQueue = this.writeQueue.then(async () => {
      const store = await preferences.getPreferences(context, { name: STORE_NAME })
      const saved = await store.get(HISTORY_KEY, '[]')
      const history = readDiagnosticHistory(typeof saved === 'string' ? saved : '')
      const merged = mergeDiagnosticRecords(history, records)
      await store.put(HISTORY_KEY, JSON.stringify(merged))
      await store.flush()
      hilog.info(DOMAIN, TAG, 'Local fault summaries saved: %{public}d', merged.length)
    }).catch(() => {
      hilog.warn(DOMAIN, TAG, 'Local fault summary save failed; application continues')
    })
  }

  stop(): void {
    const watcher = this.watcher
    if (!watcher) {
      return
    }
    try {
      hiAppEvent.removeWatcher(watcher)
      this.watcher = undefined
    } catch (_) {
      // Retain the handle if removal fails, preventing duplicate registration on a later start.
      hilog.warn(DOMAIN, TAG, 'Fault watcher removal failed')
    }
  }
}

export const appDiagnostics = new AppDiagnostics()
