import { describe, expect, it } from '@ohos/hypium'
import { loadInterviewCatalog, selectInterviewPage } from '../main/ets/common/utils/InterviewCatalog'
import { IListData } from '../main/ets/models/HomeModels'
import { QuestionItem } from '../main/ets/views/home/QuestionItemComp'

function item(id: string, views: number, likes: number = 0, date: string = '2025-01-01'): QuestionItem {
  return { id, stem: `Question ${id}`, views, likeCount: likes, createdAt: date, difficulty: 1, readFlag: 0 }
}

export default function interviewCatalogTest() {
  describe('InterviewCatalog', () => {
    it('sorts the complete catalog before slicing a client page', 0, async () => {
      const requested: number[] = []
      const catalog = await loadInterviewCatalog((page: number): Promise<IListData> => {
        requested.push(page)
        return Promise.resolve<IListData>({ total: 4, pageTotal: 2,
          rows: page === 1 ? [item('1', 4), item('2', 2)] : [item('3', 900), item('4', 100)] })
      })
      const result = selectInterviewPage(catalog, '', 21, 1, 2)
      expect(requested.join(',')).assertEqual('1,2')
      expect(result.rows.map((row: QuestionItem) => row.id).join(',')).assertEqual('3,4')
      expect(result.pageTotal).assertEqual(2)
      expect(catalog[0].id).assertEqual('1')
    })
    it('orders by likes or newest date with deterministic ties', 0, () => {
      const rows: QuestionItem[] = [item('1', 0, 20, '2024-01-01'), item('2', 0, 2), item('3', 0, 2)]
      expect(selectInterviewPage(rows, '', 30, 1, 10).rows[0].id).assertEqual('1')
      expect(selectInterviewPage(rows, '', 0, 1, 10).rows.map((row: QuestionItem) => row.id).join(',')).assertEqual('3,2,1')
    })
    it('filters title and author before pagination and supports no matches', 0, () => {
      const first = item('1', 10)
      const second = item('2', 20)
      second.creatorName = 'ArkUI author'
      const result = selectInterviewPage([first, second], '  arkui  ', 21, 1, 1)
      expect(result.total).assertEqual(1)
      expect(result.rows[0].id).assertEqual('2')
      expect(selectInterviewPage([first, second], 'not-found', 21, 1, 10).pageTotal).assertEqual(0)
    })
    it('accepts an empty catalog', 0, async () => {
      const rows = await loadInterviewCatalog((): Promise<IListData> => Promise.resolve<IListData>({ rows: [], pageTotal: 0, total: 0 }))
      expect(rows.length).assertEqual(0)
    })
    it('rejects incomplete data instead of sorting a partial catalog', 0, async () => {
      let rejected = false
      try {
        await loadInterviewCatalog((): Promise<IListData> => Promise.resolve<IListData>({ rows: [item('1', 1)], pageTotal: 1, total: 2 }))
      } catch (_) { rejected = true }
      expect(rejected).assertEqual(true)
    })
    it('rejects repeated pages instead of looping or claiming global order', 0, async () => {
      let rejected = false
      try {
        await loadInterviewCatalog((): Promise<IListData> => Promise.resolve<IListData>({ rows: [item('1', 1)], pageTotal: 2, total: 2 }))
      } catch (_) { rejected = true }
      expect(rejected).assertEqual(true)
    })
    it('propagates a later page failure', 0, async () => {
      let rejected = false
      try {
        await loadInterviewCatalog((page: number): Promise<IListData> => page === 1
          ? Promise.resolve<IListData>({ rows: [item('1', 1)], pageTotal: 2, total: 2 }) : Promise.reject(new Error('offline')))
      } catch (_) { rejected = true }
      expect(rejected).assertEqual(true)
    })
    it('stops a superseded request before requesting another page', 0, async () => {
      let current = true
      let calls = 0
      let rejected = false
      try {
        await loadInterviewCatalog((): Promise<IListData> => {
          calls++
          current = false
          return Promise.resolve<IListData>({ rows: [item('1', 1)], pageTotal: 2, total: 2 })
        }, () => current)
      } catch (_) { rejected = true }
      expect(rejected).assertEqual(true)
      expect(calls).assertEqual(1)
    })
  })
}
