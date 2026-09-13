import { TimeItem } from '../../models/HomeModels'

export const TRACKING_BATCH_SIZE: number = 5

export function appendTrackingItem(list: TimeItem[], item: TimeItem): TimeItem[] {
  const nextList: TimeItem[] = list.slice()
  nextList.push({
    questionId: item.questionId,
    startTime: item.startTime,
    endTime: item.endTime
  })
  return nextList
}

export function shouldUploadTrackingQueue(list: TimeItem[]): boolean {
  return list.length >= TRACKING_BATCH_SIZE
}

export function resolveTrackingQueue(list: TimeItem[], uploadSucceeded: boolean): TimeItem[] {
  return uploadSucceeded ? [] : list
}
