import { IQuestionType } from '../../models/CategoryModel'

// Request generics do not validate JSON. Reject malformed payloads before ArkUI
// ForEach receives them; an empty array remains a valid, distinct empty result.
export function parseQuestionCategories(value: Object | null | undefined): IQuestionType[] {
  if (!Array.isArray(value)) { throw new Error('Invalid category list') }
  const items = value as IQuestionType[]
  const ids = new Set<number>()
  const result: IQuestionType[] = []
  for (const item of items) {
    if (!item || typeof item !== 'object' || !Number.isSafeInteger(item.id) || item.id <= 0 ||
      typeof item.name !== 'string' || !item.name.trim() || ids.has(item.id)) {
      throw new Error('Invalid category item')
    }
    ids.add(item.id)
    result.push({ id: item.id, name: item.name, icon: item.icon, describeInfo: item.describeInfo,
      tags: item.tags, displayNewestFlag: item.displayNewestFlag === 1 ? 1 : 0 })
  }
  return result
}
