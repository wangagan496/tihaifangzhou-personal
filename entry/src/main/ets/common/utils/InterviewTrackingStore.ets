import { preferences } from '@kit.ArkData'
import { AxiosError, AxiosResponse } from '@ohos/axios'
import { auth } from './Auth'
import { contextManager } from './ContextManager'
import { IRes, tgRequest } from './request'
import {
  appendPendingInterviewTracking,
  ANONYMOUS_INTERVIEW_OWNER,
  firstPendingForOwner,
  InterviewTrackingEvent,
  PendingInterviewTracking,
  removePendingInterviewTrackingById,
  shouldDiscardFailedInterviewTracking
} from './InterviewTrackingPolicy'

const STORE_NAME: string = 'interviewTracking'
const EVENTS_KEY: string = 'events'

interface InterviewTrackingRequestData {
  questionNo: string
  stayTime: number
  exp: boolean
}

class InterviewTrackingStore {
  private flushing: boolean = false
  private eventIdSequence: number = 0

  private canSend(ownerId: string): boolean {
    const currentUserId = auth.getUser()?.id
    return ownerId === ANONYMOUS_INTERVIEW_OWNER ? !currentUserId : currentUserId === ownerId
  }

  private getFile(): preferences.Preferences | undefined {
    const context = contextManager.getCtx()
    if (!context) { return undefined }
    try {
      return preferences.getPreferencesSync(context, { name: STORE_NAME })
    } catch (_) {
      return undefined
    }
  }

  private createEventId(usedIds: string[]): string {
    let id = ''
    let used = true
    while (used) {
      this.eventIdSequence++
      id = `interview_${Date.now()}_${this.eventIdSequence}`
      used = false
      for (let i = 0; i < usedIds.length; i++) {
        if (usedIds[i] === id) { used = true; break }
      }
    }
    return id
  }

  private read(file: preferences.Preferences): PendingInterviewTracking[] | undefined {
    const raw = file.getSync(EVENTS_KEY, []) as PendingInterviewTracking[]
    if (!Array.isArray(raw)) { return [] }
    const events: PendingInterviewTracking[] = []
    const usedIds: string[] = []
    let needsMigration = false
    for (let i = 0; i < raw.length; i++) {
      const item = raw[i]
      if (item && typeof item.ownerId === 'string' && typeof item.questionNo === 'string' &&
        Number.isSafeInteger(item.stayTime) && item.stayTime > 0 && typeof item.exp === 'boolean') {
        let id = typeof item.id === 'string' && item.id.length > 0 ? item.id : ''
        for (let j = 0; id && j < usedIds.length; j++) {
          if (usedIds[j] === id) { id = ''; break }
        }
        if (!id) {
          id = this.createEventId(usedIds)
          needsMigration = true
        }
        usedIds.push(id)
        events.push({ id, ownerId: item.ownerId, questionNo: item.questionNo, stayTime: item.stayTime, exp: item.exp })
      }
    }
    if (needsMigration && !this.persist(file, events)) { return undefined }
    return events
  }

  private persist(file: preferences.Preferences, events: PendingInterviewTracking[]): boolean {
    try {
      file.putSync(EVENTS_KEY, events)
      file.flushSync()
      return true
    } catch (_) {
      return false
    }
  }

  async record(item: InterviewTrackingEvent): Promise<void> {
    const file = this.getFile()
    if (!file) { return }
    const current = this.read(file)
    if (!current) { return }
    const next = appendPendingInterviewTracking(current, {
      id: this.createEventId(current.map((event: PendingInterviewTracking) => event.id)),
      ownerId: item.ownerId,
      questionNo: item.questionNo,
      stayTime: item.stayTime,
      exp: item.exp
    })
    if (!this.persist(file, next)) { return }
    await this.flush(item.ownerId)
  }

  async flush(ownerId: string): Promise<void> {
    if (this.flushing || !ownerId || !this.canSend(ownerId)) { return }
    const file = this.getFile()
    if (!file) { return }
    this.flushing = true
    try {
      while (this.canSend(ownerId)) {
        const events = this.read(file)
        if (!events) { return }
        const item = firstPendingForOwner(events, ownerId)
        if (!item) { return }
        try {
          await tgRequest({
            url: '/hm/interview/tracking',
            method: 'POST',
            data: { questionNo: item.questionNo, stayTime: item.stayTime, exp: item.exp },
            silent: true
          })
        } catch (error) {
          const axiosError = error as AxiosError<IRes<null>, InterviewTrackingRequestData>
          const rejectedResponse = error as AxiosResponse<IRes<null>, InterviewTrackingRequestData>
          const httpStatus = axiosError.response?.status ??
            (rejectedResponse.config ? rejectedResponse.status : undefined)
          const businessCode = axiosError.response || !rejectedResponse.config
            ? undefined
            : rejectedResponse.data?.code
          if (shouldDiscardFailedInterviewTracking({ httpStatus, businessCode })) {
            const latest = this.read(file)
            if (!latest || !this.persist(file, removePendingInterviewTrackingById(latest, item.id))) { return }
            continue
          }
          return
        }
        const latest = this.read(file)
        if (!latest || !this.persist(file, removePendingInterviewTrackingById(latest, item.id))) { return }
      }
    } catch (_) {
      return
    } finally {
      this.flushing = false
    }
  }
}

export const interviewTrackingStore = new InterviewTrackingStore()
