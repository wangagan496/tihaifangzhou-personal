import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { AudioDB, InterviewAudioItem } from '../../../main/ets/common/utils/AudioDB'

export default function audioDBTest() {
  describe('AudioDBIntegrationTest', () => {
    it('crudAndUserIsolation', 0, async () => {
      const testAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
      AppStorage.setOrCreate('context', testAbility.context)

      const db = new AudioDB()
      const userId = `audio-db-test-${Date.now()}`
      const otherUserId = `${userId}-other`
      const item: InterviewAudioItem = {
        id: null,
        user_id: userId,
        name: 'integration-audio',
        path: `/data/storage/el2/base/files/${userId}.m4a`,
        duration: 30,
        size: 300,
        create_time: Date.now()
      }

      expect(await db.initStore()).assertEqual(true)
      expect(await db.insert(item)).assertEqual(true)

      const otherUserList = await db.query(otherUserId)
      expect(otherUserList.length).assertEqual(0)

      const insertedList = await db.query(userId)
      expect(insertedList.length).assertEqual(1)
      expect(insertedList[0].user_id).assertEqual(userId)

      const insertedId = insertedList[0].id
      const updatedItem: InterviewAudioItem = {
        id: insertedId,
        user_id: userId,
        name: 'renamed-audio',
        path: insertedList[0].path,
        duration: insertedList[0].duration,
        size: insertedList[0].size,
        create_time: insertedList[0].create_time
      }
      expect(await db.update(updatedItem)).assertEqual(true)

      const updatedList = await db.query(userId)
      expect(updatedList.length).assertEqual(1)
      expect(updatedList[0].name).assertEqual('renamed-audio')

      if (insertedId !== null) {
        expect(await db.delete(insertedId)).assertEqual(true)
      }
      const deletedList = await db.query(userId)
      expect(deletedList.length).assertEqual(0)
    })
  })
}
