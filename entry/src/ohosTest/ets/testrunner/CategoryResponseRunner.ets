import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios'
import { instance, IRes } from '../../../main/ets/common/utils/request'
import { IQuestionType } from '../../../main/ets/models/CategoryModel'
import { IListData } from '../../../main/ets/models/HomeModels'
import { prepareDeviceTestContext, getDeviceTestContext } from './DeviceTestContext'

interface InvalidCategoryResponse { id: string; stem: string }
let validResponse = false

async function response(config: InternalAxiosRequestConfig): Promise<AxiosResponse<IRes<Object>>> {
  const invalid: InvalidCategoryResponse = { id: 'fixture-question', stem: 'Wrong endpoint shape' }
  const categories: IQuestionType[] = [{ id: 987654, name: '回归测试分类', displayNewestFlag: 0 }]
  const list: IListData = { rows: [], total: 0, pageTotal: 0 }
  const data: Object = config.url === '/hm/question/type' ? (validResponse ? categories : invalid) : list
  return { config, status: 200, statusText: 'OK', headers: {},
    data: { code: 10000, data, message: 'fixture', success: true } }
}

async function pause(): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, 500))
}

export default class CategoryResponseRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    const adapter = instance.defaults.adapter
    instance.defaults.adapter = response
    validResponse = false
    let failure = ''
    try {
      AppStorage.setOrCreate('homeTab', 0)
      await prepareDeviceTestContext()
      let win: window.Window | undefined = undefined
      for (let i = 0; i < 40; i++) {
        try {
          const candidate = await window.getLastWindow(getDeviceTestContext())
          if (candidate.getUIContext().getRouter().getState().name) { win = candidate; break }
        } catch (_) {}
        await pause()
      }
      if (!win) { throw new Error('Startup did not create router') }
      const ui = await import('./CompletionUiDriver')
      const driver = ui.createDriver()
      let retry = await driver.findComponent(ui.byId('categoryRetryButton'))
      for (let i = 0; !retry && i < 20; i++) {
        await pause()
        retry = await driver.findComponent(ui.byId('categoryRetryButton'))
      }
      if (!retry) { throw new Error('Invalid payload did not display retry state') }
      if (!await driver.screenCap(`${getDeviceTestContext().filesDir}/category-invalid.png`)) {
        throw new Error('Invalid-state screenshot failed')
      }
      await delegator.print('MALFORMED_CATEGORY_NO_CRASH=PASS')
      validResponse = true
      await retry.click()
      await pause()
      await pause()
      if (await driver.findComponent(ui.byId('categoryRetryButton'))) {
        throw new Error('Retry did not leave failure state')
      }
      const tab = await driver.findComponent(ui.byText('回归测试分类'))
      if (!tab) { throw new Error('Valid category did not render after retry') }
      if (!await driver.screenCap(`${getDeviceTestContext().filesDir}/category-recovered.png`)) {
        throw new Error('Recovery screenshot failed')
      }
      await delegator.print('CATEGORY_RETRY_RECOVERS=PASS')
    } catch (error) { failure = (error as Error).message }
    finally { instance.defaults.adapter = adapter }
    await delegator.finishTest(failure || 'Category malformed response regression passed', failure ? 1 : 0)
  }
}
