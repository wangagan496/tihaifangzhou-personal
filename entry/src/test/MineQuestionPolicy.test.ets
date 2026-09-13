import { describe, expect, it } from '@ohos/hypium'
import { addMineQuestion, MineQuestionRecord, setMineQuestionFlag } from '../main/ets/common/utils/MineQuestionPolicy'

function item(id: string): MineQuestionRecord {
  return { id, stem: `question-${id}`, difficulty: 1, likeCount: 0, views: 0, readFlag: 0 }
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

    it('removesDisabledFlag', 0, () => {
      const result = setMineQuestionFlag([item('1'), item('2')], item('1'), false)
      expect(result.length).assertEqual(1)
      expect(result[0].id).assertEqual('2')
    })
  })
}
