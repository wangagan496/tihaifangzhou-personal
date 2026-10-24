import { describe, expect, it } from '@ohos/hypium'
import { appendPendingCleanup } from '../main/ets/common/utils/AudioCleanupPolicy'

export default function audioCleanupPolicyTest() {
  describe('AudioCleanupPolicyTest', () => {
    it('deduplicatesAndMovesLatestPathToTheEnd', 0, () => {
      const result = appendPendingCleanup(['/a.m4a', '/b.m4a'], '/a.m4a')

      expect(result.length).assertEqual(2)
      expect(result[0]).assertEqual('/b.m4a')
      expect(result[1]).assertEqual('/a.m4a')
    })

    it('ignoresBlankPaths', 0, () => {
      const result = appendPendingCleanup(['/a.m4a'], '  ')

      expect(result.length).assertEqual(1)
      expect(result[0]).assertEqual('/a.m4a')
    })
  })
}
