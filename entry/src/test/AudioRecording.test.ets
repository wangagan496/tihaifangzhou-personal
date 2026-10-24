import { describe, expect, it } from '@ohos/hypium'
import { AudioRecording, hasUsableAudioFile, reactToRecorderState } from '../main/ets/views/AudioPage/AudioRecording'

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

  describe('RecorderStatePolicyTest', () => {
    it('abortsOnErrorInAnyActivePhase', 0, () => {
      expect(reactToRecorderState('warmup', 'error', false)).assertEqual('abort')
      expect(reactToRecorderState('recording', 'error', true)).assertEqual('abort')
      expect(reactToRecorderState('recording', 'released', true)).assertEqual('abort')
    })

    it('savesSystemInterruptionOnlyAfterWarmup', 0, () => {
      expect(reactToRecorderState('recording', 'paused', true)).assertEqual('finish')
      expect(reactToRecorderState('recording', 'stopped', true)).assertEqual('finish')
      expect(reactToRecorderState('warmup', 'paused', true)).assertEqual('abort')
    })

    it('ignoresUserTransitionsAndOwnStopFlow', 0, () => {
      expect(reactToRecorderState('recording', 'started', false)).assertEqual('ignore')
      expect(reactToRecorderState('recording', 'stopped', false)).assertEqual('ignore')
      expect(reactToRecorderState('stopping', 'error', true)).assertEqual('ignore')
      expect(reactToRecorderState('stopping', 'stopped', true)).assertEqual('ignore')
      expect(reactToRecorderState('idle', 'error', true)).assertEqual('ignore')
    })
  })
}
