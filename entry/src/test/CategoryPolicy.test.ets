import { describe, expect, it } from '@ohos/hypium'
import { parseQuestionCategories } from '../main/ets/common/utils/CategoryPolicy'

function rejects(json: string): boolean {
  try { parseQuestionCategories(JSON.parse(json) as Object); return false } catch (_) { return true }
}

export default function categoryPolicyTest() {
  describe('CategoryPolicyTest', () => {
    it('rejectsTheQuestionObjectThatCrashedForEach', 0, () => {
      expect(rejects('{"id":"fixture-question","stem":"Wrong endpoint shape"}')).assertTrue()
      expect(rejects('null')).assertTrue()
      expect(rejects('"wrong"')).assertTrue()
      expect(rejects('123')).assertTrue()
    })
    it('rejectsInvalidEntriesAndDuplicateIdentities', 0, () => {
      expect(rejects('[null]')).assertTrue()
      expect(rejects('[{"id":"1","name":"分类"}]')).assertTrue()
      expect(rejects('[{"id":0,"name":"分类"}]')).assertTrue()
      expect(rejects('[{"id":1,"name":" "}]')).assertTrue()
      expect(rejects('[{"id":1,"name":{} }]')).assertTrue()
      expect(rejects('[{"id":1,"name":"A"},{"id":1,"name":"B"}]')).assertTrue()
    })
    it('acceptsEmptyAndValidCategoriesWithoutMutatingInput', 0, () => {
      expect(parseQuestionCategories([]).length).assertEqual(0)
      const source = JSON.parse('[{"id":1,"name":"A"},{"id":2,"name":"B","displayNewestFlag":1}]') as Object
      const result = parseQuestionCategories(source)
      expect(result.length).assertEqual(2)
      expect(result[0].displayNewestFlag).assertEqual(0)
      expect(result[1].displayNewestFlag).assertEqual(1)
      expect(JSON.stringify(source).includes('"displayNewestFlag":0')).assertFalse()
    })
  })
}
