import { describe, expect, it } from '@ohos/hypium'
import { addMineQuestion, MineQuestionRecord, setMineQuestionFlag } from '../main/ets/common/utils/MineQuestionPolicy'

function item(id: string): MineQuestionRecord {
  return { id, stem: `question-${id}`, difficulty: 1, likeCount: 0, views: 0, readFlag: 0 }
}

function interviewItem(id: string): MineQuestionRecord {
  return {
    id,
    stem: `interview-${id}`,
    difficulty: 0,
    likeCount: 0,
    views: 0,
    readFlag: 0,
    contentType: 1,
    questionNo: `M${id}`
  }
}

export default function mineQuestionPolicyTest() {
  describe('MineQuestionPolicyTest', () => {
    it('deduplicatesAndPutsLatestHistoryFirst', 0, () => {
      const result = addMineQuestion([item('1'), item('2')], item('2'))
      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('2')
      expect(result[1].id).assertEqual('1')
    })

    it('limitsHistorySize', 0, () => {
      const result = addMineQuestion([item('1'), item('2')], item('3'), 2)
      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('3')
    })

    it('keepsQuestionAndInterviewWithSameId', 0, () => {
      const result = addMineQuestion([item('1')], interviewItem('1'))
      expect(result.length).assertEqual(2)
      expect(result[0].contentType).assertEqual(1)
      expect(result[1].contentType || 0).assertEqual(0)
    })

    it('removesDisabledFlag', 0, () => {
      const result = setMineQuestionFlag([item('1'), item('2')], item('1'), false)
      expect(result.length).assertEqual(1)
      expect(result[0].id).assertEqual('2')
    })

    it('removesOnlyMatchingContentType', 0, () => {
      const result = setMineQuestionFlag([item('1'), interviewItem('1')], interviewItem('1'), false)
      expect(result.length).assertEqual(1)
      expect(result[0].contentType || 0).assertEqual(0)
    })
  })
}
