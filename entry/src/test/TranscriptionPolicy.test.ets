import { describe, expect, it } from '@ohos/hypium'
import { TranscriptAccumulator, canSaveTranscript, transcriptionPercent, transcriptionErrorMessage,
  recognitionEngineOptions, recognitionStreamOptions, choosePcmSegmentLength,
  PCM_MAX_SESSION_BYTES } from '../main/ets/common/utils/TranscriptionPolicy'

export default function transcriptionPolicyTest() {
  describe('TranscriptionPolicyTest', () => {
    it('configuresLongEngineSeparatelyFromExternalAudioInputMode', 0, () => {
      expect(recognitionEngineOptions()['recognizerMode']).assertEqual('long')
      expect(recognitionEngineOptions()['recognitionMode']).assertUndefined()
      expect(recognitionStreamOptions()['recognitionMode']).assertEqual(1)
      expect(recognitionStreamOptions()['maxAudioDuration']).assertEqual(1800000)
    })
    it('replacesInterimResultsInsteadOfDuplicatingThem', 0, () => {
      const result = new TranscriptAccumulator()
      result.add('学习', false, false)
      expect(result.add('学习鸿蒙', false, false)).assertEqual('学习鸿蒙')
      expect(result.result()).assertEqual('')
      result.add('学习鸿蒙开发。', true, false)
      expect(result.preview()).assertEqual('学习鸿蒙开发。')
    })
    it('segmentsBelowThePlatformLimitAndPrefersASilenceBoundary', 0, () => {
      const pcm = new Uint8Array(PCM_MAX_SESSION_BYTES)
      pcm.fill(64)
      expect(choosePcmSegmentLength(pcm, false)).assertEqual(PCM_MAX_SESSION_BYTES)
      const quietStart = PCM_MAX_SESSION_BYTES - 3 * 32000
      const quietEnd = PCM_MAX_SESSION_BYTES - 2 * 32000
      pcm.fill(0, quietStart, quietEnd)
      const boundary = choosePcmSegmentLength(pcm, false)
      expect(boundary > quietStart && boundary < quietEnd).assertTrue()
      expect(boundary % 2).assertEqual(0)
      expect(choosePcmSegmentLength(new Uint8Array(100), true)).assertEqual(100)
      expect(PCM_MAX_SESSION_BYTES < 60 * 32000).assertTrue()
    })
    it('preservesSentenceOrderAndLegitimateRepetitions', 0, () => {
      const result = new TranscriptAccumulator()
      result.add('你好。', true, false)
      result.add('你好。', true, false)
      result.add('再见。', false, true)
      expect(result.result()).assertEqual('你好。\n你好。\n再见。')
    })
    it('doesNotSaveUnfinalizedOrEmptySpeech', 0, () => {
      const result = new TranscriptAccumulator()
      result.add('未确定', false, false)
      expect(result.result()).assertEqual('')
      result.add(' ', true, true)
      expect(result.result()).assertEqual('')
    })
    it('validatesOwnershipKeysAndTranscriptSize', 0, () => {
      expect(canSaveTranscript(1, 'user', '文字')).assertTrue()
      expect(canSaveTranscript(0, 'user', '文字')).assertFalse()
      expect(canSaveTranscript(1, '', '文字')).assertFalse()
      expect(canSaveTranscript(1, 'user', ' ')).assertFalse()
      expect(canSaveTranscript(1, 'user', '字'.repeat(60001))).assertFalse()
    })
    it('boundsProgressForPartialPacketsAndInvalidTotals', 0, () => {
      expect(transcriptionPercent(640, 1000)).assertEqual(64)
      expect(transcriptionPercent(1280, 1000)).assertEqual(100)
      expect(transcriptionPercent(1, 0)).assertEqual(0)
      expect(transcriptionPercent(-1, 100)).assertEqual(0)
      expect(transcriptionPercent(Number.NaN, 100)).assertEqual(0)
    })
    it('usesSafeUserFacingErrorsWithoutEchoingNativePayloads', 0, () => {
      expect(transcriptionErrorMessage('private-file-or-transcript').includes('private')).assertFalse()
      expect(transcriptionErrorMessage('EARLY_END').includes('未保存')).assertTrue()
      expect(transcriptionErrorMessage('CANCELLED').includes('保留')).assertTrue()
    })
  })
}
