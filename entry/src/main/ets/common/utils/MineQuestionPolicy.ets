export interface MineQuestionRecord {
  id: string
  stem: string
  difficulty: number
  likeCount: number
  views: number
  readFlag: 0 | 1
}

export function addMineQuestion(
  list: MineQuestionRecord[],
  item: MineQuestionRecord,
  limit: number = 50
): MineQuestionRecord[] {
  return [item, ...list.filter((record: MineQuestionRecord) => record.id !== item.id)].slice(0, limit)
}

export function setMineQuestionFlag(
  list: MineQuestionRecord[],
  item: MineQuestionRecord,
  enabled: boolean,
  limit: number = 50
): MineQuestionRecord[] {
  if (enabled) {
    return addMineQuestion(list, item, limit)
  }
  return list.filter((record: MineQuestionRecord) => record.id !== item.id)
}
