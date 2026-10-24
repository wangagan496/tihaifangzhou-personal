export interface InterviewTrackingEvent {
  ownerId: string
  questionNo: string
  stayTime: number
  exp: boolean
}

export interface PendingInterviewTracking extends InterviewTrackingEvent {
  id: string
}

export interface InterviewTrackingFailure {
  httpStatus?: number
  businessCode?: number
}

export const ANONYMOUS_INTERVIEW_OWNER: string = '__anonymous__'
export const MAX_PENDING_INTERVIEW_TRACKING: number = 100

export function appendPendingInterviewTracking(list: PendingInterviewTracking[], item: PendingInterviewTracking): PendingInterviewTracking[] {
  if (!item.id || !item.ownerId || !item.questionNo || !Number.isSafeInteger(item.stayTime) || item.stayTime <= 0) {
    return list.slice()
  }
  const next = list.slice()
  next.push({ id: item.id, ownerId: item.ownerId, questionNo: item.questionNo, stayTime: item.stayTime, exp: item.exp })
  return next.length > MAX_PENDING_INTERVIEW_TRACKING
    ? next.slice(next.length - MAX_PENDING_INTERVIEW_TRACKING)
    : next
}

export function firstPendingForOwner(list: PendingInterviewTracking[], ownerId: string): PendingInterviewTracking | undefined {
  for (let i = 0; i < list.length; i++) {
    if (list[i].ownerId === ownerId) { return list[i] }
  }
  return undefined
}

export function removePendingInterviewTrackingById(list: PendingInterviewTracking[], id: string): PendingInterviewTracking[] {
  const next: PendingInterviewTracking[] = []
  let removed = false
  for (let i = 0; i < list.length; i++) {
    const item = list[i]
    if (!removed && item.id === id) {
      removed = true
      continue
    }
    next.push(item)
  }
  return next
}

export function shouldDiscardFailedInterviewTracking(failure: InterviewTrackingFailure): boolean {
  if (failure.httpStatus === 401) { return false }
  return failure.businessCode !== undefined && failure.businessCode !== 10000
}
