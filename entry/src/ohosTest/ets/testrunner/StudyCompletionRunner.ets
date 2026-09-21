import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { preferences } from '@kit.ArkData'
import { AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios'
import { prepareDeviceTestContext, getDeviceTestContext } from './DeviceTestContext'
import { instance, IRes } from '../../../main/ets/common/utils/request'
import { contextManager } from '../../../main/ets/common/utils/ContextManager'
import { studyProgressStore } from '../../../main/ets/common/utils/StudyProgressStore'
import { QuestionDetail } from '../../../main/ets/models/QuestionDetailModel'
import { ILoginDta } from '../../../main/ets/models/AccountModel'
import { IQuestionType } from '../../../main/ets/models/CategoryModel'
import { IListData } from '../../../main/ets/models/HomeModels'

const OWNER = '__completion_device_v1__'
const QID = '__completion_question_v1__'
const TYPE = 987654

function check(value: boolean, message: string): void {
  if (!value) { throw new Error(message) }
}

async function pause(ms: number = 500): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, ms))
}

// Synthetic responses exercise the production detail page without submitting
// fixture reading records to the teaching backend or using real credentials.
async function fixtureResponse(config: InternalAxiosRequestConfig): Promise<AxiosResponse<IRes<Object>>> {
  const question: QuestionDetail = {
    id: QID, stem: '完成进度设备验证', difficulty: 1, likeCount: 0, views: 1,
    readFlag: 1, answer: '<p>仅浏览不会增加完成数。请用下方按钮标记或取消完成。</p>',
    collectFlag: 0, likeFlag: 0
  }
  let data: Object = question
  if (config.url === '/hm/question/type') { const categories: IQuestionType[] = []; data = categories }
  if (config.url === '/hm/question/list') {
    const list: IListData = { rows: [], total: 0, pageTotal: 0 }; data = list
  }
  return { config, status: 200, statusText: 'OK', headers: {},
    data: { code: 10000, success: true, message: 'fixture', data } }
}

export default class StudyCompletionRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    const stage = abilityDelegatorRegistry.getArguments().parameters['-s stage'] || 'save'
    const adapter = instance.defaults.adapter
    instance.defaults.adapter = fixtureResponse
    let previousUser: ILoginDta | undefined = undefined
    let win: window.Window | undefined = undefined
    let oldOrientation: window.Orientation | undefined = undefined
    let progress: preferences.Preferences | undefined = undefined
    let trackFile: preferences.Preferences | undefined = undefined
    let previousQueue: preferences.ValueType = []
    let failure = ''
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
      trackFile = preferences.getPreferencesSync(getDeviceTestContext(), { name: 'trackFile' })
      previousQueue = trackFile.getSync('list', [])
      trackFile.putSync('list', [])
      trackFile.flushSync()
      const user: ILoginDta = { id: OWNER, username: OWNER, token: 'synthetic-not-a-real-token',
        refreshToken: '', nickName: '设备验收', clockinNumbers: 0, shareInfo: '', totalTime: 0 }
      AppStorage.set('user', user)
      progress = preferences.getPreferencesSync(getDeviceTestContext(), { name: 'studyProgress' })
      if (stage === 'save') {
        progress.deleteSync(`completed:v1:question:${OWNER}`)
        progress.putSync(`ids:${OWNER}:10:${TYPE}`, [QID])
        progress.flushSync()
        check(studyProgressStore.getDone(OWNER, String(TYPE), 10, 5) === 0, 'Legacy visit counted')
      } else {
        check(studyProgressStore.isCompleted(OWNER, QID) === true, 'Completion lost across process restart')
        await delegator.print('COMPLETION_PROCESS_RESTART=PASS')
      }
      await win.getUIContext().getRouter().pushUrl({ url: 'pages/QuestionDetailPage',
        params: { id: QID, type: 0, questionTypeId: TYPE, questionBankType: 10 } })
      const uiTest = await import('./CompletionUiDriver')
      const driver = uiTest.createDriver()
      for (let attempt = 0; attempt < 40; attempt++) {
        if (await driver.findComponent(uiTest.byId('questionCompletionButton'))) { break }
        await pause(250)
      }
      const scroll = await driver.findComponent(uiTest.byType('Scroll'))
      if (scroll) { await scroll.scrollToBottom() }
      await pause()
      let button = await driver.findComponent(uiTest.byId('questionCompletionButton'))
      check(button !== null, 'Completion button missing')
      if (stage === 'save') {
        check((await button.getText()) === '标记已完成', 'Visit auto-completed question')
        check(studyProgressStore.getDone(OWNER, String(TYPE), 10, 5) === 0, 'Visit changed count')
        await delegator.print('VISIT_DOES_NOT_COMPLETE=PASS')
        await driver.screenCap(`${getDeviceTestContext().filesDir}/completion-before.png`)
        await button.click()
        await pause()
        button = await driver.findComponent(uiTest.byId('questionCompletionButton'))
        check((await button.getText()) === '已完成 · 取消标记', 'Mark button state failed')
        check(studyProgressStore.getDone(OWNER, String(TYPE), 10, 5) === 1, 'Mark did not increment count')
        check(studyProgressStore.setCompleted(OWNER, QID, true), 'Repeated mark failed')
        check(studyProgressStore.getDone(OWNER, String(TYPE), 10, 5) === 1, 'Repeated mark double-counted')
        await delegator.print('MARK_AND_DEDUPLICATION=PASS')
      } else {
        check((await button.getText()) === '已完成 · 取消标记', 'Restart UI did not restore completion')
        await button.click()
        await pause()
        check(studyProgressStore.getDone(OWNER, String(TYPE), 10, 5) === 0, 'Undo did not decrease count')
        button = await driver.findComponent(uiTest.byId('questionCompletionButton'))
        check((await button.getText()) === '标记已完成', 'Undo button state failed')
        await delegator.print('UNDO_COMPLETION=PASS')
        await button.click()
        await pause()
      }
      await driver.screenCap(`${getDeviceTestContext().filesDir}/completion-marked.png`)
      const other: ILoginDta = { id: `${OWNER}_other`, token: 'synthetic-other-token',
        refreshToken: '', nickName: '其他测试账号', clockinNumbers: 0, shareInfo: '', totalTime: 0 }
      AppStorage.set('user', other)
      await pause()
      button = await driver.findComponent(uiTest.byId('questionCompletionButton'))
      check((await button.getText()) === '标记已完成', 'Other account saw completion')
      AppStorage.set('user', user)
      await pause()
      button = await driver.findComponent(uiTest.byId('questionCompletionButton'))
      check((await button.getText()) === '已完成 · 取消标记', 'Account restoration failed')
      await delegator.print('ACCOUNT_ISOLATION=PASS')
      oldOrientation = win.getPreferredOrientation()
      await win.setPreferredOrientation(window.Orientation.LANDSCAPE)
      await pause(1000)
      const wideScroll = await driver.findComponent(uiTest.byType('Scroll'))
      if (wideScroll) { await wideScroll.scrollToBottom() }
      await pause()
      await driver.screenCap(`${getDeviceTestContext().filesDir}/completion-landscape.png`)
      await win.setPreferredOrientation(oldOrientation)
      oldOrientation = undefined
      // Replacing with a detail route omitting category parameters exercises favorites/history entry.
      await win.getUIContext().getRouter().replaceUrl({ url: 'pages/QuestionDetailPage', params: { id: QID, type: 0 } })
      await pause(1200)
      const reopenedScroll = await driver.findComponent(uiTest.byType('Scroll'))
      if (reopenedScroll) { await reopenedScroll.scrollToBottom() }
      await pause()
      button = await driver.findComponent(uiTest.byId('questionCompletionButton'))
      check((await button.getText()) === '已完成 · 取消标记', 'Reopen without category lost state')
      await delegator.print('REOPEN_WITHOUT_CATEGORY=PASS')
      if (stage === 'read') {
        await button.click()
        await pause()
        check(studyProgressStore.isCompleted(OWNER, QID) === false, 'Final undo failed')
      }
    } catch (error) { failure = (error as Error).message }
    finally {
      if (win) {
        if (oldOrientation !== undefined) { await win.setPreferredOrientation(oldOrientation) }
        win.getUIContext().getRouter().back()
        await pause(800)
      }
      AppStorage.set('user', previousUser || {} as ILoginDta)
      if (trackFile) {
        trackFile.putSync('list', previousQueue)
        trackFile.flushSync()
      }
      const history = preferences.getPreferencesSync(getDeviceTestContext(), { name: 'mineQuestions' })
      history.deleteSync(`mine_history_${OWNER}`)
      history.flushSync()
      const time = preferences.getPreferencesSync(getDeviceTestContext(), { name: 'studyTime' })
      time.deleteSync(`total:id:${OWNER}`)
      time.deleteSync(`total:username:${OWNER}`)
      time.deleteSync(`legacyTotalResetV1:total:id:${OWNER}`)
      time.flushSync()
      if (progress && (stage === 'read' || failure)) {
        progress.deleteSync(`completed:v1:question:${OWNER}`)
        progress.deleteSync(`ids:${OWNER}:10:${TYPE}`)
        progress.flushSync()
      }
      instance.defaults.adapter = adapter
    }
    await delegator.finishTest(failure || `Completion ${stage} passed`, failure ? 1 : 0)
  }
}
