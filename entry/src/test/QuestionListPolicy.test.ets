import { describe, it, expect } from '@ohos/hypium'
import {
  matchesQuestionKeyword,
  mergeUniqueQuestions
} from '../main/ets/common/utils/QuestionListPolicy'
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

    it('matches interview title or author', 0, () => {
      const item: QuestionItem = {
        id: '3',
        stem: '鸿蒙开发面试',
        creatorName: '黑马前端',
        difficulty: 1,
        likeCount: 0,
        views: 1,
        readFlag: 0
      }
      expect(matchesQuestionKeyword(item, '鸿蒙')).assertEqual(true)
      expect(matchesQuestionKeyword(item, '黑马前端')).assertEqual(true)
      expect(matchesQuestionKeyword(item, '不存在的作者')).assertEqual(false)
    })
  })
}
