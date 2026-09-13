import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { prepareDeviceTestContext } from './DeviceTestContext'
import { AiScoringJob } from '../../../main/ets/common/utils/AiScoring'
import { AiScoreInput } from '../../../main/ets/common/utils/AiScorePolicy'

export default class BackendIntegrationRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    let failure = ''
    try {
      await prepareDeviceTestContext()
      const input: AiScoreInput = { question: '集成测试题目', answer: '合成测试回答，不含个人数据', referenceAnswer: '' }
      const result = await new AiScoringJob('http://127.0.0.1:3001/v1/scores', true)
        .run(input, 'test-only-native-integration-access-code')
      if (result.score !== 73 || !result.summary.startsWith('测试夹具')) { throw new Error('Unexpected fixture response') }
      await delegator.print('ARKTS_TO_FASTIFY_HTTP=PASS (synthetic fixture, not real AI)')
      let rejected = false
      try {
        await new AiScoringJob('http://127.0.0.1:3001/v1/scores', true)
          .run(input, 'incorrect-test-access-code-long-enough')
      } catch (error) { rejected = (error as Error).message === 'UNAUTHORIZED' }
      if (!rejected) { throw new Error('Incorrect service code was not rejected') }
      await delegator.print('ARKTS_BACKEND_AUTH_REJECTION=PASS')
    } catch (error) { failure = (error as Error).message }
    await delegator.finishTest(failure || 'Native backend integration completed without model calls', failure ? 1 : 0)
  }
}
