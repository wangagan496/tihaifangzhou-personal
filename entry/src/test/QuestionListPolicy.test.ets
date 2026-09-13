import { describe, it, expect } from '@ohos/hypium'
import { mergeUniqueQuestions } from '../main/ets/common/utils/QuestionListPolicy'
import { QuestionItem } from '../main/ets/views/home/QuestionItemComp'

export default function questionListPolicyTest() {
  describe('QuestionListPolicy', () => {
    it('removes duplicate rows while preserving order', 0, () => {
      const first: QuestionItem = { id: '1', stem: 'A', difficulty: 1, likeCount: 0, views: 1, readFlag: 0 }
      const second: QuestionItem = { id: '2', stem: 'B', difficulty: 1, likeCount: 0, views: 2, readFlag: 0 }
      const result = mergeUniqueQuestions([first], [first, second, second])
      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('1')
      expect(result[1].id).assertEqual('2')
    })
  })
}
