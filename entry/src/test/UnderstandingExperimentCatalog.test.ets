import { describe, expect, it } from '@ohos/hypium'
import { listKeyExperiment, understandingExperimentFor } from '../main/ets/common/utils/UnderstandingExperimentCatalog'

export default function understandingExperimentCatalogTest() {
  describe('UnderstandingExperimentCatalog', () => {
    it('selects an experiment only for the matching concept', 0, () => {
      const experiment = understandingExperimentFor('ForEach 列表为什么需要 key')
      expect(experiment?.title).assertEqual(listKeyExperiment.title)
      expect(understandingExperimentFor('什么是状态管理')).assertEqual(undefined)
    })

    it('keeps the experiment question-specific', 0, () => {
      const experiment = understandingExperimentFor('列表如何排序')
      expect(experiment).assertEqual(undefined)
    })

    it('doesNotMatchEnglishSubstringsInsideOtherWords', 0, () => {
      expect(understandingExperimentFor('List keyboard shortcut')).assertEqual(undefined)
      expect(understandingExperimentFor('ArrayList key')).assertEqual(undefined)
      expect(understandingExperimentFor('listener key')).assertEqual(undefined)
    })

    it('matchesEnglishTermsAsCompleteWords', 0, () => {
      expect(understandingExperimentFor('List item identity uses a stable key')?.title)
        .assertEqual(listKeyExperiment.title)
      expect(understandingExperimentFor('ForEach uses a key to preserve list state')?.title)
        .assertEqual(listKeyExperiment.title)
    })
  })
}
