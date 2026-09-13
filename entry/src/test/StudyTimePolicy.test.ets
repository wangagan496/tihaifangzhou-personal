import { describe, expect, it } from '@ohos/hypium'
import {
  addStudyTimeDuration,
  buildStudyTimeKeys,
  normalizeServerStudyTime,
  normalizeStoredStudyTime,
  resolveStudyTimeTotal
} from '../main/ets/common/utils/StudyTimePolicy'

export default function studyTimePolicyTest() {
  describe('StudyTimePolicyTest', () => {
    it('buildsStableKeysForUserIdAndUsername', 0, () => {
      const keys = buildStudyTimeKeys(' User-1 ', ' DemoUser ')

      expect(keys[0]).assertEqual('total:id:user-1')
      expect(keys[1]).assertEqual('total:username:demouser')
    })

    it('keepsLocalTotalWhenServerReturnsZeroAfterLogin', 0, () => {
      const total = resolveStudyTimeTotal([0, 321, 0])

      expect(total).assertEqual(321)
    })

    it('usesNewerServerTotalWhenItIsLarger', 0, () => {
      const total = resolveStudyTimeTotal([180, 240])

      expect(total).assertEqual(240)
    })

    it('addsOnlyValidWholeSeconds', 0, () => {
      expect(addStudyTimeDuration(120, 9.8)).assertEqual(129)
      expect(addStudyTimeDuration(120, -5)).assertEqual(120)
    })

    it('convertsServerMillisecondsToSeconds', 0, () => {
      expect(normalizeServerStudyTime(56320516)).assertEqual(56320)
    })

    it('migratesLegacyMillisecondTotals', 0, () => {
      expect(normalizeStoredStudyTime(56320516)).assertEqual(56320)
      expect(normalizeStoredStudyTime(56320)).assertEqual(56320)
    })
  })
}
