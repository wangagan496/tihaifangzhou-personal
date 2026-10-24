import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios'
import { instance, IRes } from '../../../main/ets/common/utils/request'
import { QuestionDetail } from '../../../main/ets/models/QuestionDetailModel'
import { prepareDeviceTestContext, getDeviceTestContext } from './DeviceTestContext'

const QID = '__understanding_lab_question_v1__'

async function fixtureResponse(config: InternalAxiosRequestConfig): Promise<AxiosResponse<IRes<Object>>> {
  const question: QuestionDetail = {
    id: QID,
    stem: 'ForEach 列表中的 key 有什么作用？',
    difficulty: 1,
    likeCount: 0,
    views: 1,
    readFlag: 1,
    answer: '<p>稳定的 key 帮助列表在插入、删除或排序后识别原来的列表项。</p>',
    collectFlag: 0,
    likeFlag: 0
  }
  return {
    config,
    status: 200,
    statusText: 'OK',
    headers: {},
    data: { code: 10000, success: true, message: 'fixture', data: question }
  }
}

export default class UnderstandingLabRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    const originalAdapter = instance.defaults.adapter
    let failure = ''
    try {
      instance.defaults.adapter = fixtureResponse
      await prepareDeviceTestContext()
      await new Promise<void>((resolve) => setTimeout(resolve, 2000))
      const win = await window.getLastWindow(getDeviceTestContext())
      await win.getUIContext().getRouter().pushUrl({ url: 'pages/QuestionDetailPage', params: { id: QID, type: 0 } })
      await new Promise<void>((resolve) => setTimeout(resolve, 800))
      const ui = await import('./CompletionUiDriver')
      const driver = ui.createDriver()
      const click = async (label: string): Promise<void> => {
        const scroll = await driver.findComponent(ui.byType('Scroll'))
        if (!scroll) { throw new Error('Scroll missing') }
        await scroll.scrollToTop()
        const target = await scroll.scrollSearch(ui.byText(label))
        if (!target) { throw new Error(`Missing: ${label}`) }
        await target.click()
        await new Promise<void>((resolve) => setTimeout(resolve, 300))
      }
      const contains = async (label: string): Promise<void> => {
        const scroll = await driver.findComponent(ui.byType('Scroll'))
        await scroll.scrollToTop()
        if (!await scroll.scrollSearch(ui.byText(label))) { throw new Error(`Missing result: ${label}`) }
      }
      if (!await driver.findComponent(ui.byText('ForEach 列表中的 key 有什么作用？'))) {
        throw new Error('Question stem missing from detail page')
      }
      await contains('先理解这道题')
      await contains('列表状态为什么需要稳定 key')
      await click('原来的 A')
      await click('顶部插入 X')
      await contains('实际展开的是 X。按位置记录时，状态留在第 0 行；A 已经移到第 1 行。')
      await click('按每项 id 识别')
      await click('重新排序')
      await click('删除 A')
      await click('两种方式都是 B')
      await click('位置变，身份不变')
      await contains('再看位置：B 原本在第 1 行。删除 A 后，C 到了第 1 行；按位置保存的展开状态就落到了 C。')
      await click('按位置是 C，按 id 是 B')
      await click('id 阻止排序')
      await contains('结果判断对了，但 id 不会阻止排序。它标识的是同一项，而不是固定位置。')
      await click('位置变，身份不变')
      await contains('本轮小考通过：结果和原因都判断正确。位置变了，B 的身份没变。可以再回实验试一次。')
      await driver.screenCap(`${getDeviceTestContext().filesDir}/understanding-quiz.png`)
      await contains('用自己的话解释')
      await contains('对照这道题的参考答案')
      const scroll = await driver.findComponent(ui.byType('Scroll'))
      const answer = await scroll.scrollSearch(ui.byId('understandingAnswer'))
      if (!answer) { throw new Error('Inline answer field missing') }
      await answer.inputText('稳定 id 能在顺序变化后认出原来的列表项，所以状态不会错跟到别的项。')
      if (await answer.getText() !== '稳定 id 能在顺序变化后认出原来的列表项，所以状态不会错跟到别的项。') {
        throw new Error('Inline answer was not retained')
      }
      if (!await scroll.scrollSearch(ui.byId('understandingScoreButton'))) {
        throw new Error('Inline score button missing')
      }
      await contains('检查理解并打分')
      await click('重置')
      await scroll.scrollToTop()
      await driver.screenCap(`${getDeviceTestContext().filesDir}/understanding-start.png`)
      await delegator.print('UNDERSTANDING_LAB_PREDICT_OPERATE_QUIZ_RESET=PASS')
    } catch (error) { failure = (error as Error).message }
    finally {
      try {
        const win = await window.getLastWindow(getDeviceTestContext())
        win.getUIContext().getRouter().back()
      } catch (_) {}
      instance.defaults.adapter = originalAdapter
    }
    await delegator.finishTest(failure || 'Understanding lab UI passed', failure ? 1 : 0)
  }
}
