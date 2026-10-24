import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { preferences } from '@kit.ArkData'
import { auth } from '../../../main/ets/common/utils/Auth'
import { contextManager } from '../../../main/ets/common/utils/ContextManager'
import { InterviewTrackingEvent, PendingInterviewTracking } from '../../../main/ets/common/utils/InterviewTrackingPolicy'
import { interviewTrackingStore } from '../../../main/ets/common/utils/InterviewTrackingStore'
import { ILoginBody, ILoginDta } from '../../../main/ets/models/AccountModel'
import { tgRequest, instance } from '../../../main/ets/common/utils/request'
import { getDeviceTestContext, prepareDeviceTestContext } from './DeviceTestContext'

interface ReceivedTrackingEvent {
  ownerId: string
  questionNo: string
  stayTime: number
  exp: boolean
}

const STORAGE_NAME = 'interviewTracking'
const EVENTS_KEY = 'events'
const TEST_USERNAME = 'tracking-test'
const TEST_PASSWORD = 'tracking-test-pass'

function check(value: boolean, message: string): void {
  if (!value) { throw new Error(message) }
}

export default class InterviewTrackingLiveServerRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    const previousBaseURL = instance.defaults.baseURL
    const previousUser = AppStorage.get<ILoginDta>('user')
    let storage: preferences.Preferences | undefined = undefined
    let previousEvents: preferences.ValueType = []
    let failure = ''
    try {
      await prepareDeviceTestContext()
      contextManager.ctx = getDeviceTestContext()
      storage = preferences.getPreferencesSync(getDeviceTestContext(), { name: STORAGE_NAME })
      previousEvents = storage.getSync(EVENTS_KEY, [])
      storage.putSync(EVENTS_KEY, [])
      storage.flushSync()
      AppStorage.set('user', {} as ILoginDta)
      instance.defaults.baseURL = 'http://127.0.0.1:3001'

      const user = await tgRequest<ILoginDta, ILoginBody>({
        url: '/hm/login', method: 'POST', data: { username: TEST_USERNAME, password: TEST_PASSWORD }, silent: true
      })
      check(user.id === 'local-interview-tracking-test-user' && user.token.length > 0,
        'Local HTTP login did not return the test user')
      auth.setUser(user)
      await delegator.print('LOCAL_HTTP_LOGIN=PASS')

      const questionNo = `local-http-${Date.now()}`
      const tracking: InterviewTrackingEvent = { ownerId: user.id, questionNo, stayTime: 7, exp: true }
      await interviewTrackingStore.record(tracking)

      const received = await tgRequest<ReceivedTrackingEvent[]>({
        url: '/__test/interview-tracking', method: 'GET', silent: true
      })
      let found = false
      for (let i = 0; i < received.length; i++) {
        const item = received[i]
        if (item.ownerId === user.id && item.questionNo === questionNo && item.stayTime === 7 && item.exp) {
          found = true
          break
        }
      }
      check(found, 'Local server did not record the posted interview event')

      const remaining = storage.getSync(EVENTS_KEY, []) as PendingInterviewTracking[]
      for (let i = 0; i < remaining.length; i++) {
        check(remaining[i].questionNo !== questionNo, 'Successfully received event remained in the local queue')
      }
      await delegator.print('LOCAL_HTTP_TRACKING_RECEIVED_AND_QUEUE_CLEARED=PASS')
    } catch (error) {
      failure = (error as Error).message
    } finally {
      instance.defaults.baseURL = previousBaseURL
      AppStorage.set('user', previousUser || {} as ILoginDta)
      if (storage) {
        storage.putSync(EVENTS_KEY, previousEvents)
        storage.flushSync()
      }
    }
    await delegator.finishTest(failure || 'Local server interview tracking integration passed', failure ? 1 : 0)
  }
}
