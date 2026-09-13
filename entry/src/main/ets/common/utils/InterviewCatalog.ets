import { IListData } from '../../models/HomeModels'
import { QuestionItem } from '../../views/home/QuestionItemComp'
import { matchesQuestionKeyword, mergeUniqueQuestions } from './QuestionListPolicy'

export type InterviewPageLoader = (page: number, pageSize: number) => Promise<IListData>

// The current list API ignores interview sort. Only a COMPLETE catalog can be
// sorted locally without misrepresenting a single server page as global order.
export async function loadInterviewCatalog(loadPage: InterviewPageLoader,
  isCurrent: () => boolean = () => true): Promise<QuestionItem[]> {
  const pageSize = 500
  const maxPages = 100
  let pageTotal = 1
  let expectedTotal = 0
  let rows: QuestionItem[] = []
  for (let page = 1; page <= pageTotal; page++) {
    if (!isCurrent()) { throw new Error('Interview request superseded') }
    const result = await loadPage(page, pageSize)
    if (!isCurrent()) { throw new Error('Interview request superseded') }
    if (!Number.isInteger(result.pageTotal) || result.pageTotal < 0 || result.pageTotal > maxPages ||
      !Number.isInteger(result.total) || result.total < 0 || result.total > maxPages * pageSize) {
      throw new Error('Invalid interview pagination metadata')
    }
    if (page === 1) {
      pageTotal = Math.max(1, result.pageTotal)
      expectedTotal = result.total
    }
    const merged = mergeUniqueQuestions(rows, result.rows)
    if (page > 1 && merged.length === rows.length) {
      throw new Error('Interview pagination made no progress')
    }
    rows = merged
  }
  if (rows.length < expectedTotal) { throw new Error('Incomplete interview catalog') }
  return rows
}

function count(value: number): number {
  return Number.isFinite(value) ? value : 0
}

function createdTime(item: QuestionItem): number {
  const time = Date.parse(item.createdAt || '')
  return Number.isFinite(time) ? time : 0
}

export function selectInterviewPage(catalog: QuestionItem[], keyword: string, sort: number,
  page: number, pageSize: number): IListData {
  const rows = catalog.filter((item: QuestionItem) => matchesQuestionKeyword(item, keyword))
  rows.sort((left: QuestionItem, right: QuestionItem): number => {
    const popularity = sort === 21 ? count(right.views) - count(left.views) :
      sort === 30 ? count(right.likeCount) - count(left.likeCount) : 0
    if (popularity !== 0) { return popularity }
    const date = createdTime(right) - createdTime(left)
    if (date !== 0) { return date }
    const id = Number(right.id) - Number(left.id)
    if (Number.isFinite(id) && id !== 0) { return id }
    return left.id === right.id ? 0 : left.id > right.id ? -1 : 1
  })
  return {
    rows: rows.slice((page - 1) * pageSize, page * pageSize),
    total: rows.length,
    pageTotal: Math.ceil(rows.length / pageSize)
  }
}
