import { describe, expect, it } from '@ohos/hypium'
import { scoreCredentialScope, validServiceAccessCode } from '../main/ets/common/utils/ScoreSettingsPolicy'
import { ScoreCredentialQueue } from '../main/ets/common/utils/ScoreCredentialQueue'

export default function scoreSettingsPolicyTest() {
  describe('ScoreSettingsPolicyTest', () => {
    it('requiresValidServiceCodesWithoutAcceptingWhitespaceOrHugeValues', 0, () => {
      expect(validServiceAccessCode('a'.repeat(32))).assertTrue()
      expect(validServiceAccessCode('b'.repeat(256))).assertTrue()
      expect(validServiceAccessCode('a'.repeat(31))).assertFalse()
      expect(validServiceAccessCode('a'.repeat(257))).assertFalse()
      expect(validServiceAccessCode('secret with spaces'.repeat(3))).assertFalse()
    })
    it('separatesAccountsAndServiceEndpoints', 0, () => {
      const first = scoreCredentialScope('user-a', 'https://one.example/v1/scores')
      expect(first === scoreCredentialScope('user-b', 'https://one.example/v1/scores')).assertFalse()
      expect(first === scoreCredentialScope('user-a', 'https://two.example/v1/scores')).assertFalse()
      expect(first).assertEqual(scoreCredentialScope('user-a', 'https://one.example/v1/scores'))
    })
    it('rejectsMissingScopeAndAvoidsDelimiterCollisions', 0, () => {
      expect(scoreCredentialScope('', 'endpoint')).assertEqual('')
      expect(scoreCredentialScope('user', ' ')).assertEqual('')
      expect(scoreCredentialScope('a:b', 'c') === scoreCredentialScope('a', 'b:c')).assertFalse()
    })
    it('ordersSlowSaveThenClearAndMakesReadersWaitForBoth', 0, async () => {
      const queue = new ScoreCredentialQueue()
      let release: () => void = (): void => {}
      const gate = new Promise<void>((resolve) => { release = resolve })
      let stored = ''
      const save = queue.run('same-scope', async () => { await gate; stored = 'old-code' })
      const clear = queue.run('same-scope', async () => { stored = '' })
      const read = queue.run('same-scope', async () => stored)
      release()
      await save; await clear
      expect(await read).assertEqual('')
    })
    it('preservesLatestSaveAndDoesNotBlockIndependentScopesOrFailures', 0, async () => {
      const queue = new ScoreCredentialQueue()
      let release: () => void = (): void => {}
      const gate = new Promise<void>((resolve) => { release = resolve })
      let stored = ''
      const first = queue.run('a', async () => { await gate; stored = 'first' })
      const second = queue.run('a', async () => { stored = 'second' })
      expect(await queue.run('b', async () => 'independent')).assertEqual('independent')
      release(); await first; await second
      expect(stored).assertEqual('second')
      const failed = queue.run<void>('a', async () => { throw new Error('synthetic failure') }).catch(() => {})
      const after = queue.run('a', async () => 'recovered')
      await failed
      expect(await after).assertEqual('recovered')
    })
  })
}
