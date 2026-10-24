import { describe, expect, it } from '@ohos/hypium'
import { relationalStore } from '@kit.ArkData'
import { getDeviceTestContext } from '../testrunner/DeviceTestContext'
import {
  AudioDB,
  InterviewAudioItem,
  readAudioItem,
  readResultSetRows
} from '../../../main/ets/common/utils/AudioDB'

const RESULT_SET_DB = 'audio_result_set_test.db'

async function openResultSetStore(): Promise<relationalStore.RdbStore> {
  const store = await relationalStore.getRdbStore(getDeviceTestContext(), {
    name: RESULT_SET_DB,
    securityLevel: relationalStore.SecurityLevel.S1
  })
  await store.executeSql(`CREATE TABLE IF NOT EXISTS interview_audio (
    id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, name TEXT NOT NULL, path TEXT NOT NULL,
    duration INTEGER NOT NULL, size INTEGER NOT NULL, create_time INTEGER NOT NULL)`)
  await store.executeSql('DELETE FROM interview_audio')
  await store.insert('interview_audio', {
    user_id: 'result-set-user', name: 'a', path: '/tmp/a.m4a', duration: 1, size: 2, create_time: 3
  })
  await store.insert('interview_audio', {
    user_id: 'result-set-user', name: 'b', path: '/tmp/b.m4a', duration: 4, size: 5, create_time: 6
  })
  return store
}

function queryAll(store: relationalStore.RdbStore, columns?: string[]): Promise<relationalStore.ResultSet> {
  const predicates = new relationalStore.RdbPredicates('interview_audio')
  predicates.orderByAsc('id')
  return columns ? store.query(predicates, columns) : store.query(predicates)
}

function resultSetCloseTest() {
  describe('AudioDBResultSetCloseTest', () => {
    it('closesResultSetAfterSuccessfulAndFailedReads', 0, async () => {
      const store = await openResultSetStore()
      try {
        const normal = await queryAll(store)
        const rows = readResultSetRows(normal, readAudioItem)
        expect(rows.length).assertEqual(2)
        expect(rows[1].name).assertEqual('b')
        expect(normal.isClosed).assertTrue()

        // 第一行读完后在第二行抛错，验证中途失败也会关闭。
        const failing = await queryAll(store)
        let mapperError = ''
        try {
          readResultSetRows(failing, (row: relationalStore.ResultSet): string => {
            if (row.rowIndex === 1) {
              throw new Error('MAPPER_FAILED')
            }
            return row.getString(row.getColumnIndex('name'))
          })
        } catch (e) {
          mapperError = (e as Error).message
        }
        expect(mapperError).assertEqual('MAPPER_FAILED')
        expect(failing.isClosed).assertTrue()

        // 只投影 id 列，readAudioItem 读取缺失列时由 RDB 抛出真实错误。
        const projected = await queryAll(store, ['id'])
        let readFailed = false
        try {
          readResultSetRows(projected, readAudioItem)
        } catch (_) {
          readFailed = true
        }
        expect(readFailed).assertTrue()
        expect(projected.isClosed).assertTrue()
      } finally {
        await store.close()
        await relationalStore.deleteRdbStore(getDeviceTestContext(), RESULT_SET_DB)
      }
    })
  })
}

export default function audioDBTest() {
  resultSetCloseTest()
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
      expect(await db.update(updatedItem, otherUserId)).assertEqual(false)
      if (insertedId !== null) {
        expect(await db.delete(insertedId, otherUserId)).assertEqual(false)
      }
      expect((await db.query(userId)).length).assertEqual(1)

      expect(await db.update(updatedItem, userId)).assertEqual(true)

      const updatedList = await db.query(userId)
      expect(updatedList.length).assertEqual(1)
      expect(updatedList[0].name).assertEqual('renamed-audio')

      if (insertedId !== null) {
        expect(await db.delete(insertedId, userId)).assertEqual(true)
        expect(await db.getTranscript(insertedId, userId)).assertEqual('')
        expect(await db.saveTranscript(insertedId, userId, '迟到的转写结果')).assertFalse()
      }
      const deletedList = await db.query(userId)
      expect(deletedList.length).assertEqual(0)
    })
  })
}
