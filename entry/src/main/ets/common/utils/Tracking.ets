import { TimeItem } from '../../models/HomeModels';
import { tgRequest } from './request';
import { preferences } from '@kit.ArkData';
import { contextManager } from './ContextManager';
import { appendTrackingItem, resolveTrackingQueue, shouldUploadTrackingQueue } from './TrackingPolicy';
import { studyTimeStore } from './StudyTimeStore';
import { auth } from './Auth';

class Tracking {
  private timeItem: TimeItem = {} as TimeItem

  // 只在题目详情请求成功、内容可展示后开始计时，不把接口等待时间算进去。
  start(id: string): void {
    this.timeItem.questionId = id
    this.timeItem.startTime = Date.now()
  }

  // 离开详情页时写入本地队列；满 5 条才上报，成功清空、失败保留。
  save(): Promise<void> {
    this.timeItem.endTime = Date.now()
    studyTimeStore.record(auth.getUser()?.id, this.timeItem.questionId, this.timeItem.startTime, this.timeItem.endTime)
    const context = contextManager.getCtx()
    if (!context) {
      return Promise.resolve()
    }
    const trackFile = preferences.getPreferencesSync(context, { name: 'trackFile' })
    const storedList = trackFile.getSync('list', []) as TimeItem[]
    const list = appendTrackingItem(storedList, this.timeItem)
    if (!shouldUploadTrackingQueue(list)) {
      trackFile.putSync('list', list)
      trackFile.flushSync()
      return Promise.resolve()
    }
    return tgRequest({ url: '/hm/time/tracking', method: 'POST', data: { timeList: list } }).then((): void => {
      trackFile.putSync('list', resolveTrackingQueue(list, true))
      trackFile.flushSync()
    }, (): void => {
      trackFile.putSync('list', resolveTrackingQueue(list, false))
      trackFile.flushSync()
    })
  }
}

export const tracking = new Tracking();
