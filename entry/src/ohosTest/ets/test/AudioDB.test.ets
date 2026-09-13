import { describe, expect, it } from '@ohos/hypium'
import { getDeviceTestContext } from '../testrunner/DeviceTestContext'
import { AudioDB, InterviewAudioItem } from '../../../main/ets/common/utils/AudioDB'

export default function audioDBTest() {
  describe('AudioDBIntegrationTest', () => {
    it('crudAndUserIsolation', 0, async () => {
      AppStorage.setOrCreate('context', getDeviceTestContext())

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
      if (insertedId !== null) {
        expect(await db.saveTranscript(insertedId, userId, '第一段文字')).assertTrue()
        expect(await db.getTranscript(insertedId, otherUserId)).assertEqual('')
        expect(await db.saveTranscript(insertedId, otherUserId, '越权写入')).assertFalse()
        expect(await db.getTranscript(insertedId, userId)).assertEqual('第一段文字')
        expect(await db.saveTranscript(insertedId, userId, '更新后的文字')).assertTrue()
      }
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
        expect(await db.getTranscript(insertedId, userId)).assertEqual('')
        expect(await db.saveTranscript(insertedId, userId, '迟到的转写结果')).assertFalse()
      }
      const deletedList = await db.query(userId)
      expect(deletedList.length).assertEqual(0)
    })
  })
}
