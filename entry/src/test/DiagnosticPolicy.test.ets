import { describe, expect, it } from '@ohos/hypium'
import {
  createDiagnosticRecord,
  DiagnosticRecord,
  mergeDiagnosticRecords,
  readDiagnosticHistory
} from '../main/ets/common/utils/DiagnosticPolicy'

function event(time: number, name: string = 'APP_FREEZE', pid: number = 123): DiagnosticRecord {
  return { name, time, pid, foreground: true }
}

export default function diagnosticPolicyTest() {
  describe('DiagnosticPolicyTest', () => {
    it('acceptsOnlySupportedSystemFaultNames', 0, () => {
      expect(createDiagnosticRecord('APP_FREEZE', 1000, 12)?.name).assertEqual('APP_FREEZE')
      expect(createDiagnosticRecord('APP_CRASH', 1000, 12)?.name).assertEqual('APP_CRASH')
      expect(createDiagnosticRecord('user_login', 1000, 12)).assertUndefined()
    })

    it('rejectsInvalidTimesAndNormalizesUnavailableProcessIds', 0, () => {
      expect(createDiagnosticRecord('APP_FREEZE', 0, 12)).assertUndefined()
      expect(createDiagnosticRecord('APP_FREEZE', 0.1, 12)).assertUndefined()
      expect(createDiagnosticRecord('APP_FREEZE', Number.NaN, 12)).assertUndefined()
      expect(createDiagnosticRecord('APP_FREEZE', Number.POSITIVE_INFINITY, 12)).assertUndefined()
      expect(createDiagnosticRecord('APP_FREEZE', 1000.9, -1)?.pid).assertEqual(0)
      expect(createDiagnosticRecord('APP_FREEZE', 1000.9, 12)?.time).assertEqual(1000)
    })

    it('deduplicatesReplayedEventsWithoutCombiningDifferentFaults', 0, () => {
      const merged = mergeDiagnosticRecords([event(1000)], [event(1000), event(1000, 'APP_CRASH'), event(1000, 'APP_FREEZE', 456)])
      expect(merged.length).assertEqual(3)
    })

    it('keepsTheNewestTwentyRegardlessOfDeliveryOrder', 0, () => {
      const events: DiagnosticRecord[] = []
      for (let i = 1; i <= 25; i++) { events.push(event(i)) }
      const merged = mergeDiagnosticRecords(events, [event(2), event(26)])
      expect(merged.length).assertEqual(20)
      expect(merged[0].time).assertEqual(26)
      expect(merged[19].time).assertEqual(7)
      expect(events.length).assertEqual(25)
    })

    it('discardsCorruptOrOversizedStoredData', 0, () => {
      expect(readDiagnosticHistory('{broken').length).assertEqual(0)
      expect(readDiagnosticHistory('{"events":[]}').length).assertEqual(0)
      expect(readDiagnosticHistory(' '.repeat(16385)).length).assertEqual(0)
      expect(readDiagnosticHistory('[null,0,"text",{}, {"name":"APP_FREEZE","time":"1000"}]').length).assertEqual(0)
    })

    it('neverRetainsRawPayloadFieldsFromStoredEvents', 0, () => {
      const history = readDiagnosticHistory('[{"name":"APP_FREEZE","time":1000,"pid":12,"foreground":false,"params":{"token":"fixture-only"},"external_log":["private-path"],"stack":"private-stack"}]')
      expect(history.length).assertEqual(1)
      const saved = JSON.stringify(history)
      expect(saved.includes('fixture-only')).assertFalse()
      expect(saved.includes('private-path')).assertFalse()
      expect(saved.includes('private-stack')).assertFalse()
      expect(history[0].foreground).assertFalse()
    })
  })
}
