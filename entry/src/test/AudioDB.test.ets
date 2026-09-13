import { describe, expect, it } from '@ohos/hypium'
import { AudioDB, InterviewAudioItem } from '../main/ets/common/utils/AudioDB'

function createAudioItem(): InterviewAudioItem {
  return {
    id: null,
    user_id: 'unit-test-user',
    name: 'unit-test-audio',
    path: '/data/storage/el2/base/files/unit-test.m4a',
    duration: 10,
    size: 100,
    create_time: 1000
  }
}

export default function audioDBTest() {
  describe('AudioDBGuardTest', () => {
    it('writeOperationsFailSafelyBeforeInitialization', 0, async () => {
      const db = new AudioDB()

      expect(await db.insert(createAudioItem())).assertEqual(false)
      expect(await db.update(createAudioItem())).assertEqual(false)
      expect(await db.delete(1)).assertEqual(false)
    })

    it('queryReturnsEmptyListBeforeInitialization', 0, async () => {
      const db = new AudioDB()
      const result = await db.query('unit-test-user')

      expect(result.length).assertEqual(0)
    })
  })
}
