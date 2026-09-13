import { QuestionItem } from '../../views/home/QuestionItemComp'

export function questionKey(item: QuestionItem): string {
  if (item.id) {
    return `id:${item.id}`
  }
  return `content:${item.questionNo || ''}:${item.stem || ''}`
}

export function mergeUniqueQuestions(current: QuestionItem[], incoming: QuestionItem[]): QuestionItem[] {
  const result = current.slice()
  const keys = new Set<string>(result.map((item: QuestionItem) => questionKey(item)))
  incoming.forEach((item: QuestionItem) => {
    const key = questionKey(item)
    if (!keys.has(key)) {
      keys.add(key)
      result.push(item)
    }
  })
  return result
}
