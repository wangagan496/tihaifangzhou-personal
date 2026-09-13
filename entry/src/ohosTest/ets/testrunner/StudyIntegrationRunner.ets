import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { prepareDeviceTestContext, getDeviceTestContext } from './DeviceTestContext'
import { readAloud, ReadingPhase } from '../../../main/ets/common/utils/ReadAloud'
import { AiScoringJob, scoringConfigured } from '../../../main/ets/common/utils/AiScoring'
import { AiScoreInput } from '../../../main/ets/common/utils/AiScorePolicy'

export default class StudyIntegrationRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    let win: window.Window | undefined = undefined
    let orientation: window.Orientation | undefined = undefined
    let failure = ''
    try {
      await prepareDeviceTestContext()
      win = await window.getLastWindow(getDeviceTestContext())
      let started = false
      let failed = false
      await readAloud.start('这是题海方舟的离线朗读验收。', (phase: ReadingPhase) => {
        if (phase === 'speaking') { started = true }
        if (phase === 'error') { failed = true }
      })
      if (!started || failed) { throw new Error('Native TTS did not complete speech') }
      await delegator.print('TTS_NATIVE_COMPLETE=PASS')
      let lateSpeech = false
      const pending = readAloud.start('取消后不应继续朗读。', (phase: ReadingPhase) => {
        if (phase === 'speaking') { lateSpeech = true }
      })
      readAloud.stop()
      await pending
      await new Promise<void>((done) => setTimeout(done, 1500))
      if (lateSpeech) { throw new Error('TTS started after cancellation') }
      await delegator.print('TTS_CANCEL_DURING_PREPARE=PASS')
      const fixture: AiScoreInput = {
        question: '如何防止异步请求的旧结果覆盖新页面？',
        answer: '为每次请求分配递增序号，只接受当前序号的结果，离页时取消请求并使序号失效。', referenceAnswer: ''
      }
      if (scoringConfigured('')) { throw new Error('Empty scoring path must be disabled') }
      let blocked = false
      try { await new AiScoringJob('').run(fixture, '') } catch (error) {
        blocked = (error as Error).message === 'NOT_CONFIGURED'
      }
      if (!blocked) { throw new Error('Unconfigured scoring must fail closed') }
      await delegator.print('AI_UNCONFIGURED_NO_REQUEST=PASS')
      orientation = win.getPreferredOrientation()
      const layout = abilityDelegatorRegistry.getArguments().parameters['-s layout']
      if (layout === 'landscape') { await win.setPreferredOrientation(window.Orientation.LANDSCAPE) }
      await win.getUIContext().getRouter().pushUrl({ url: 'pages/AiScorePage', params: fixture })
      await delegator.print('AI_SCORE_LAYOUT_READY')
      await new Promise<void>((done) => setTimeout(done, 25000))
    } catch (error) { failure = (error as Error).message }
    finally {
      readAloud.stop()
      if (win && orientation !== undefined) {
        try { await win.setPreferredOrientation(orientation) } catch (_) { failure = 'Orientation restoration failed' }
      }
    }
    await delegator.finishTest(failure || 'Study integration checks completed', failure ? 1 : 0)
  }
}
