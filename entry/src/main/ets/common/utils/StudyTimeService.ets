import { tgRequest } from './request'
import { auth } from './Auth'
import { studyTimeStore } from './StudyTimeStore'
import { studyProgressStore } from './StudyProgressStore'

export interface StudyTimeItem {
  id: string
  name: string
  total: number
  done: number
  undone: number
}

export interface StudyTimeCate {
  type: string
  list: StudyTimeItem[]
}

export interface StudyTimeData {
  totalTime: number
  studyData: StudyTimeCate[]
}

/**
 * 获取学习数据。
 * - totalTime：从本地 studyTimeStore 实时计算，服务端该字段为固定值故不采用。
 * - studyData：从服务端获取分类和总题数，完成数改由本机阅读记录聚合。
 */
export async function getStudyData(): Promise<StudyTimeData> {
  const user = auth.getUser()
  const totalTime = studyTimeStore.getTotalTime(user?.id, user?.username)
  try {
    const res = await tgRequest<StudyTimeData>({ url: '/hm/studyInfo' })
    const studyData: StudyTimeCate[] = (res.studyData || []).map((category: StudyTimeCate): StudyTimeCate => {
      const list: StudyTimeItem[] = category.list.map((item: StudyTimeItem): StudyTimeItem => {
        const done = studyProgressStore.getDone(user?.id, item.id, 10, item.total)
        return {
          id: item.id,
          name: item.name,
          total: item.total,
          done,
          undone: Math.max(0, item.total - done)
        }
      })
      return {
        type: category.type,
        list
      }
    })
    return {
      totalTime,
      studyData
    }
  } catch (_) {
    return { totalTime, studyData: [] }
  }
}
