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
    const user = auth.getUser()
    studyTimeStore.record(user?.id, user?.username, this.timeItem.questionId,
      this.timeItem.startTime, this.timeItem.endTime)
    const context = contextManager.getCtx()
    if (!context) {
      return Promise.resolve()
    }
    let trackFile: preferences.Preferences
    let storedList: TimeItem[]
    try {
      trackFile = preferences.getPreferencesSync(context, { name: 'trackFile' })
      storedList = trackFile.getSync('list', []) as TimeItem[]
    } catch (_) {
      return Promise.resolve()
    }
    const list = appendTrackingItem(storedList, this.timeItem)
    if (!shouldUploadTrackingQueue(list)) {
      this.persistQueue(trackFile, list)
      return Promise.resolve()
    }
    return tgRequest({ url: '/hm/time/tracking', method: 'POST', data: { timeList: list } }).then((): void => {
      this.persistQueue(trackFile, resolveTrackingQueue(list, true))
    }, (): void => {
      this.persistQueue(trackFile, resolveTrackingQueue(list, false))
    })
  }

  private persistQueue(trackFile: preferences.Preferences, list: TimeItem[]): void {
    try {
      trackFile.putSync('list', list)
      trackFile.flushSync()
    } catch (_) {
      return
    }
  }
}

export const tracking = new Tracking();
