import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios'
import { prepareDeviceTestContext, getDeviceTestContext } from './DeviceTestContext'
import { contextManager } from '../../../main/ets/common/utils/ContextManager'
import { audioDB } from '../../../main/ets/common/utils/AudioDB'
import { instance, IRes } from '../../../main/ets/common/utils/request'
import { ILoginDta } from '../../../main/ets/models/AccountModel'

const OWNER = '__audio_record_device_v1__'

function check(value: boolean, message: string): void {
  if (!value) { throw new Error(message) }
}

async function pause(ms: number = 500): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, ms))
}

function recordings(): string[] {
  const dir = getDeviceTestContext().filesDir
  return fileIo.listFileSync(dir).filter((name: string) => name.endsWith('.m4a')).map((name: string) => `${dir}/${name}`)
}

function exists(path: string): boolean {
  try { return fileIo.accessSync(path) } catch (_) { return false }
}

// 合成账号不能访问真实服务；返回空成功响应，避免后台请求 401 跳到登录页。
async function fixtureResponse(config: InternalAxiosRequestConfig): Promise<AxiosResponse<IRes<null>>> {
  return { config, status: 200, statusText: 'OK', headers: {},
    data: { code: 10000, success: true, message: 'fixture', data: null } }
}

function added(before: string[]): string[] {
  return recordings().filter((path: string) => !before.includes(path))
}

// 驱动生产录音页：开始/停止、离页清理与离页后重新录制。需要可用麦克风的设备或模拟器。
export default class AudioRecordRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    let win: window.Window | undefined = undefined
    let previousUser: ILoginDta | undefined = undefined
    const created: string[] = []
    let failure = ''
    const adapter = instance.defaults.adapter
    instance.defaults.adapter = fixtureResponse
    try {
      await prepareDeviceTestContext()
      for (let attempt = 0; attempt < 100; attempt++) {
        try {
          const candidate = await window.getLastWindow(getDeviceTestContext())
          if (candidate.getUIContext().getRouter().getState().name) { win = candidate; break }
        } catch (_) {}
        await pause(100)
      }
      if (!win) { throw new Error('Router not ready') }
      contextManager.ctx = getDeviceTestContext()
      contextManager.UiCtx = win.getUIContext()
      previousUser = AppStorage.get<ILoginDta>('user')
      const user: ILoginDta = { id: OWNER, username: OWNER, token: 'synthetic-not-a-real-token',
        refreshToken: '', nickName: '录音验收', clockinNumbers: 0, shareInfo: '', totalTime: 0 }
      AppStorage.set('user', user)
      check(await audioDB.initStore(), 'Audio DB init failed')
      const router = win.getUIContext().getRouter()
      const uiTest = await import('./CompletionUiDriver')
      const driver = uiTest.createDriver()

      const openPage = async (): Promise<void> => {
        await router.pushUrl({ url: 'pages/AudioPage' })
        for (let attempt = 0; attempt < 40; attempt++) {
          if (await driver.findComponent(uiTest.byId('audioRecordToggle'))) { return }
          const enable = await driver.findComponent(uiTest.byId('enableRecording'))
          if (enable) {
            await enable.click()
            await pause(1200)
            // 首次申请走系统授权框；用户曾拒绝时走应用的“去授权”二次授权弹窗。
            for (const text of ['去授权', '允许', '仅使用期间允许', '本次使用允许', '确定']) {
              const allow = await driver.findComponent(uiTest.byText(text))
              if (allow) { await allow.click(); await pause(1200) }
            }
          }
          await pause(250)
        }
        throw new Error('Record button missing; microphone permission not granted')
      }
      const toggle = async (): Promise<void> => {
        const button = await driver.findComponent(uiTest.byId('audioRecordToggle'))
        check(button !== null, 'Record button missing')
        await button.click()
      }

      await openPage()
      let before = recordings()
      await toggle()
      await pause(1500)
      let fresh = added(before)
      check(fresh.length === 1, `Start did not create one file: ${fresh.length}`)
      created.push(fresh[0])
      await delegator.print('START=PASS')
      await toggle()
      await pause(1500)
      const rows = (await audioDB.query(OWNER)).filter((row) => row.path === fresh[0])
      if (rows.length === 1) {
        check(exists(fresh[0]) && rows[0].size > 0, 'Saved row without usable file')
        await delegator.print('STOP=PASS saved')
      } else {
        // 模拟器无声输入会走“未检测到声音”分支，文件必须被删除。
        check(!exists(fresh[0]), 'Stopped without row but file remains')
        await delegator.print('STOP=PASS discarded-without-row')
      }

      before = recordings()
      await toggle()
      await pause(1500)
      fresh = added(before)
      check(fresh.length === 1, `Second start did not create one file: ${fresh.length}`)
      created.push(fresh[0])
      router.back()
      await pause(2000)
      check((await audioDB.query(OWNER)).every((row) => row.path !== fresh[0]), 'Leave saved a row')
      check(!exists(fresh[0]), 'Leave left an orphan recording file')
      await delegator.print('LEAVE_CLEANUP=PASS')

      await openPage()
      before = recordings()
      await toggle()
      await pause(1500)
      fresh = added(before)
      check(fresh.length === 1, 'Recording could not restart after leaving the page')
      created.push(fresh[0])
      await toggle()
      await pause(1500)
      await delegator.print('RESTART_AFTER_LEAVE=PASS')
    } catch (error) { failure = (error as Error).message }
    finally {
      try {
        for (const row of await audioDB.query(OWNER)) {
          if (row.id !== null) { await audioDB.delete(row.id, OWNER) }
          if (!created.includes(row.path)) { created.push(row.path) }
        }
      } catch (_) {}
      for (const path of created) {
        try { if (exists(path)) { fileIo.unlinkSync(path) } } catch (_) {}
      }
      if (win) {
        try { win.getUIContext().getRouter().back() } catch (_) {}
        await pause(800)
      }
      AppStorage.set('user', previousUser || {} as ILoginDta)
      instance.defaults.adapter = adapter
    }
    await delegator.finishTest(failure || 'Audio record lifecycle passed', failure ? 1 : 0)
  }
}
