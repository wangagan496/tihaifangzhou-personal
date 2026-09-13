import { describe, expect, it } from '@ohos/hypium'
import { AudioRecording, hasUsableAudioFile } from '../main/ets/views/AudioPage/AudioRecording'

function recording(size: number, path: string = '/data/storage/el2/base/files/record.m4a'): AudioRecording {
  return { path, duration: 1000, size, createTime: 1 }
}

export default function audioRecordingTest() {
  describe('AudioRecordingGuardTest', () => {
    it('acceptsAFileEvenWhenInputAmplitudeWasQuiet', 0, () => {
      expect(hasUsableAudioFile(recording(1))).assertTrue()
    })

    it('rejectsMissingOrEmptyFiles', 0, () => {
      expect(hasUsableAudioFile(recording(0))).assertFalse()
      expect(hasUsableAudioFile(recording(100, ''))).assertFalse()
    })
  })
}
