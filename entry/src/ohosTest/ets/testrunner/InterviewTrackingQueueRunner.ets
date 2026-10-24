import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { preferences } from '@kit.ArkData'
import { AxiosError, AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios'
import { ILoginDta } from '../../../main/ets/models/AccountModel'
import { ANONYMOUS_INTERVIEW_OWNER, PendingInterviewTracking } from '../../../main/ets/common/utils/InterviewTrackingPolicy'
import { interviewTrackingStore } from '../../../main/ets/common/utils/InterviewTrackingStore'
import { contextManager } from '../../../main/ets/common/utils/ContextManager'
import { IRes, instance } from '../../../main/ets/common/utils/request'
import { getDeviceTestContext, prepareDeviceTestContext } from './DeviceTestContext'

interface TrackingRequestData {
  questionNo: string
  stayTime: number
  exp: boolean
}

type FailureScenario = 'business' | 'network' | 'unauthorized'

const OWNER = ANONYMOUS_INTERVIEW_OWNER
const STORAGE_NAME = 'interviewTracking'
const EVENTS_KEY = 'events'

function check(value: boolean, message: string): void {
  if (!value) { throw new Error(message) }
}

function event(id: string, questionNo: string): PendingInterviewTracking {
  return { id, ownerId: OWNER, questionNo, stayTime: 3, exp: true }
}

function response(config: InternalAxiosRequestConfig, code: number): AxiosResponse<IRes<null>> {
  return {
    config,
    status: 200,
    statusText: 'OK',
    headers: {},
    data: { code, success: code === 10000, message: 'synthetic fixture', data: null }
  }
}

function adapterFor(scenario: FailureScenario, calls: string[]):
  (config: InternalAxiosRequestConfig) => Promise<AxiosResponse<IRes<null>>> {
  return async (config: InternalAxiosRequestConfig): Promise<AxiosResponse<IRes<null>>> => {
    calls.push(String(config.url || ''))
    if (scenario === 'business' && calls.length === 1) {
      return Promise.reject(response(config, 40001))
    }
    if (scenario === 'network') {
      const networkError: Error = new Error('Synthetic offline')
      const axiosNetworkError = AxiosError.from<IRes<null>, TrackingRequestData>(networkError, 'ERR_NETWORK', config)
      return Promise.reject(axiosNetworkError)
    }
    if (scenario === 'unauthorized') {
      const rejected: AxiosResponse<IRes<null>> = response(config, 401)
      rejected.status = 401
      rejected.statusText = 'Unauthorized'
      const unauthorizedCause: Error = new Error('Synthetic unauthorized')
      const unauthorizedError = AxiosError.from<IRes<null>, TrackingRequestData>(unauthorizedCause,
        'ERR_BAD_REQUEST', config, undefined, rejected)
      return Promise.reject(unauthorizedError)
    }
    return response(config, 10000)
  }
}

export default class InterviewTrackingQueueRunner implements TestRunner {
  onPrepare(): void {}

  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    const originalAdapter = instance.defaults.adapter
    const previousUser = AppStorage.get<ILoginDta>('user')
    let storage: preferences.Preferences | undefined = undefined
    let previousEvents: preferences.ValueType = []
    let failure = ''
    try {
      await prepareDeviceTestContext()
      contextManager.ctx = getDeviceTestContext()
      AppStorage.set('user', {} as ILoginDta)
      storage = preferences.getPreferencesSync(getDeviceTestContext(), { name: STORAGE_NAME })
      previousEvents = storage.getSync(EVENTS_KEY, [])

      const businessCalls: string[] = []
      storage.putSync(EVENTS_KEY, [event('business-first', 'business-rejected'), event('business-next', 'business-next')])
      storage.flushSync()
      instance.defaults.adapter = adapterFor('business', businessCalls)
      await interviewTrackingStore.flush(OWNER)
      const afterBusiness = storage.getSync(EVENTS_KEY, []) as PendingInterviewTracking[]
      check(businessCalls.length === 2, 'Business rejection did not continue to the next event')
      check(businessCalls[0] === '/hm/interview/tracking' && businessCalls[1] === '/hm/interview/tracking',
        'Unexpected request path during business rejection case')
      check(afterBusiness.length === 0, 'Business rejection or following success left queued events')
      await delegator.print('INTERVIEW_TRACKING_BUSINESS_REJECTION_CONTINUES=PASS')

      const networkCalls: string[] = []
      const networkEvents: PendingInterviewTracking[] = [event('network-first', 'network-first'), event('network-next', 'network-next')]
      storage.putSync(EVENTS_KEY, networkEvents)
      storage.flushSync()
      instance.defaults.adapter = adapterFor('network', networkCalls)
      await interviewTrackingStore.flush(OWNER)
      const afterNetwork = storage.getSync(EVENTS_KEY, []) as PendingInterviewTracking[]
      check(networkCalls.length === 1, 'Network failure did not stop the send loop')
      check(afterNetwork.length === 2 && afterNetwork[0].id === 'network-first' && afterNetwork[1].id === 'network-next',
        'Network failure did not retain the queued events')
      await delegator.print('INTERVIEW_TRACKING_NETWORK_FAILURE_RETAINS=PASS')

      const unauthorizedCalls: string[] = []
      const unauthorizedEvents: PendingInterviewTracking[] = [event('unauthorized-first', 'unauthorized-first'),
        event('unauthorized-next', 'unauthorized-next')]
      storage.putSync(EVENTS_KEY, unauthorizedEvents)
      storage.flushSync()
      instance.defaults.adapter = adapterFor('unauthorized', unauthorizedCalls)
      await interviewTrackingStore.flush(OWNER)
      const afterUnauthorized = storage.getSync(EVENTS_KEY, []) as PendingInterviewTracking[]
      check(unauthorizedCalls.length === 1, '401 did not stop the send loop')
      check(afterUnauthorized.length === 2 && afterUnauthorized[0].id === 'unauthorized-first' &&
        afterUnauthorized[1].id === 'unauthorized-next', '401 did not retain the queued events')
      await delegator.print('INTERVIEW_TRACKING_401_RETAINS=PASS')
    } catch (error) {
      failure = (error as Error).message
    } finally {
      instance.defaults.adapter = originalAdapter
      AppStorage.set('user', previousUser || {} as ILoginDta)
      if (storage) {
        storage.putSync(EVENTS_KEY, previousEvents)
        storage.flushSync()
      }
    }
    await delegator.finishTest(failure || 'Interview tracking queue device regression passed', failure ? 1 : 0)
  }
}
