import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { decodeToPcm, cancelDecode } from 'libaudiopcm.so'
import { AudioTranscriptionJob } from '../../../main/ets/common/utils/AudioTranscription'
import { auth } from '../../../main/ets/common/utils/Auth'
import { AudioDB, InterviewAudioItem } from '../../../main/ets/common/utils/AudioDB'
import { getDeviceTestContext } from '../testrunner/DeviceTestContext'

async function mainContext(): Promise<common.UIAbilityContext> {
  return getDeviceTestContext()
}
async function fixture(context: common.UIAbilityContext, name: string): Promise<string> {
  const test = context.getApplicationContext().createModuleContext('entry_test')
  const bytes = await test.resourceManager.getRawFileContent(name)
  const path = `${context.cacheDir}/fixture_${Date.now()}_${name}`
  const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
  try { fileIo.writeSync(file.fd, bytes.buffer) } finally { fileIo.closeSync(file) }
  return path
}
function remove(path: string): void { try { fileIo.unlinkSync(path) } catch (_) {} }
function exists(path: string): boolean { try { return fileIo.accessSync(path) } catch (_) { return false } }

export default function transcriptionNativeTest() {
  describe('TranscriptionNativeTest', () => {
    it('decodesExistingAacRecordingsWithoutChangingOriginal', 0, async () => {
      const context = await mainContext()
      const input = await fixture(context, 'transcription_fixture.m4a')
      const output = `${context.cacheDir}/decoded_${Date.now()}.pcm`
      const originalSize = fileIo.statSync(input).size
      try {
        const bytes = await decodeToPcm(input, output, `decode_test_${Date.now()}`)
        expect(bytes > 32000).assertTrue()
        expect(bytes % 2).assertEqual(0)
        expect(fileIo.statSync(output).size).assertEqual(bytes)
        expect(fileIo.statSync(input).size).assertEqual(originalSize)
      } finally { remove(input); remove(output) }
    })
    it('cancelsNativeDecodeAndRemovesOnlyItsTemporaryOutput', 0, async () => {
      const context = await mainContext()
      const input = await fixture(context, 'transcription_fixture.m4a')
      const output = `${context.cacheDir}/cancel_${Date.now()}.pcm`
      const id = `cancel_test_${Date.now()}`
      try {
        const pending = decodeToPcm(input, output, id)
        cancelDecode(id)
        let code = ''
        try { await pending } catch (error) { code = (error as Error).message }
        expect(code).assertEqual('CANCELLED')
        expect(exists(input)).assertTrue()
        expect(exists(output)).assertFalse()
      } finally { remove(input); remove(output) }
    })
    it('recognizesSyntheticMandarinOfflineAndCleansPcmCache', 0, async () => {
      const context = await mainContext()
      const input = await fixture(context, 'transcription_fixture.m4a')
      const job = new AudioTranscriptionJob()
      let finalProgress = 0
      try {
        const result = await job.run(input, context.cacheDir, (progress) => { finalProgress = progress.percent })
        expect(result.length > 5).assertTrue()
        expect(result.includes('学习') || result.includes('录音') || result.includes('文字')).assertTrue()
        expect(finalProgress).assertEqual(100)
        expect(fileIo.listFileSync(context.cacheDir).filter((name) => name.startsWith('asr_') && name.endsWith('.pcm')).length).assertEqual(0)
        hilog.info(0, 'TranscriptionNativeTest', 'Synthetic Mandarin recognized; characters=%{public}d', result.length)
      } finally { job.cancel(); remove(input) }
    })
    it('reportsSilenceWithoutInventingATranscript', 0, async () => {
      const context = await mainContext()
      const input = await fixture(context, 'transcription_silence.m4a')
      const job = new AudioTranscriptionJob()
      try {
        let code = ''
        try { await job.run(input, context.cacheDir, () => {}) } catch (error) { code = (error as Error).message }
        expect(code).assertEqual('NO_SPEECH')
      } finally { job.cancel(); remove(input) }
    })
    it('processesConsecutiveSessionsWithoutUsingACompletedSession', 0, async () => {
      const context = await mainContext()
      const input = await fixture(context, 'transcription_fixture.m4a')
      const job = new AudioTranscriptionJob(5 * 32000)
      try {
        const result = await job.run(input, context.cacheDir, () => {})
        expect(result.length > 10).assertTrue()
      } finally { job.cancel(); remove(input) }
    })
    it('recognizesAFileLongerThanTheShortSpeechLimit', 0, async () => {
      const context = await mainContext()
      const input = await fixture(context, 'transcription_long.m4a')
      const job = new AudioTranscriptionJob()
      const timeout = setTimeout(() => job.cancel(), 300000)
      let finalProgress = 0
      try {
        const result = await job.run(input, context.cacheDir, (progress) => { finalProgress = progress.percent })
        expect(result.length > 70).assertTrue()
        expect(finalProgress).assertEqual(100)
        hilog.info(0, 'TranscriptionNativeTest', 'Long synthetic Mandarin recognized; characters=%{public}d', result.length)
      } finally { clearTimeout(timeout); job.cancel(); remove(input) }
    })
    it('cancelsAnActiveRecognitionWithoutReturningPartialSuccess', 0, async () => {
      const context = await mainContext()
      const input = await fixture(context, 'transcription_fixture.m4a')
      const job = new AudioTranscriptionJob()
      try {
        let code = ''
        try {
          await job.run(input, context.cacheDir, (progress) => {
            if (progress.phase === 'recognizing' && progress.percent >= 5) { job.cancel() }
          })
        } catch (error) { code = (error as Error).message }
        expect(code).assertEqual('CANCELLED')
        expect(fileIo.listFileSync(context.cacheDir).filter((name) => name.startsWith('asr_') && name.endsWith('.pcm')).length).assertEqual(0)
      } finally { job.cancel(); remove(input) }
    })
    if (String(abilityDelegatorRegistry.getArguments().parameters['-s prepareUi']) === 'true') {
      it('preparesAnExplicitlyRequestedSyntheticUiFixture', 0, async () => {
        const context = await mainContext()
        const userId = auth.getUser()?.id
        expect(!!userId).assertTrue()
        if (!userId) { return }
        const input = await fixture(context, 'transcription_fixture.m4a')
        const destination = `${context.filesDir}/transcription_ui_${Date.now()}.m4a`
        fileIo.copyFileSync(input, destination)
        remove(input)
        const db = new AudioDB()
        expect(await db.initStore()).assertTrue()
        const item: InterviewAudioItem = { id: null, user_id: userId, name: '转写验收：合成中文语音', path: destination,
          duration: 14000, size: fileIo.statSync(destination).size, create_time: Date.now() }
        expect(await db.insert(item)).assertTrue()
        hilog.info(0, 'TranscriptionNativeTest', 'Synthetic UI fixture prepared for the current account')
      })
    }
  })
}
