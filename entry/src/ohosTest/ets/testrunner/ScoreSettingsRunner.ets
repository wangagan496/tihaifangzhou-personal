import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { prepareDeviceTestContext, getDeviceTestContext } from './DeviceTestContext'
import { ScoreCredentialStore } from '../../../main/ets/common/utils/ScoreCredentialStore'
import { AiScoreInput } from '../../../main/ets/common/utils/AiScorePolicy'

const OWNER = '__score_settings_native_acceptance_v1__'
const ENDPOINT = 'https://score-settings-test.invalid/v1/scores'
const CODE = 'synthetic-native-settings-code-not-a-real-secret'

export default class ScoreSettingsRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    const args = abilityDelegatorRegistry.getArguments().parameters
    const store = new ScoreCredentialStore()
    let failure = ''
    let win: window.Window | undefined = undefined
    let orientation: window.Orientation | undefined = undefined
    try {
      await prepareDeviceTestContext()
      if (args['-s stage'] === 'save') {
        if (!await store.clear(OWNER, ENDPOINT)) { throw new Error('Test-scope cleanup failed') }
        if (!await store.save(OWNER, ENDPOINT, CODE)) { throw new Error('Native secure save failed') }
        if (await store.status(OWNER, ENDPOINT) !== 'ready') { throw new Error('Saved status missing') }
        await delegator.print('SECURE_ASSET_SAVE=PASS')
      } else if (args['-s stage'] === 'read') {
        const loaded = await store.read(OWNER, ENDPOINT)
        if (loaded.state !== 'ready' || loaded.accessCode !== CODE) { throw new Error('Credential did not survive process restart') }
        if ((await store.read(`${OWNER}_other`, ENDPOINT)).state !== 'missing' ||
          (await store.read(OWNER, `${ENDPOINT}/other`)).state !== 'missing') { throw new Error('Credential scope isolation failed') }
        await delegator.print('SECURE_ASSET_RESTART_AND_SCOPE=PASS')
        const replacement = `${CODE}-updated`
        if (!await store.save(OWNER, ENDPOINT, replacement) || (await store.read(OWNER, ENDPOINT)).accessCode !== replacement) {
          throw new Error('Credential replacement failed')
        }
        if (!await store.clear(OWNER, ENDPOINT) || (await store.read(OWNER, ENDPOINT)).state !== 'missing') {
          throw new Error('Credential clear failed')
        }
        await delegator.print('SECURE_ASSET_UPDATE_AND_CLEAR=PASS')
        const pendingSave = store.save(OWNER, ENDPOINT, CODE)
        const pendingClear = new ScoreCredentialStore().clear(OWNER, ENDPOINT)
        const pendingRead = store.read(OWNER, ENDPOINT)
        if (!await pendingSave || !await pendingClear || (await pendingRead).state !== 'missing') {
          throw new Error('Overlapping save and clear order failed')
        }
        const firstSave = store.save(OWNER, ENDPOINT, CODE)
        const secondSave = new ScoreCredentialStore().save(OWNER, ENDPOINT, replacement)
        if (!await firstSave || !await secondSave || (await store.read(OWNER, ENDPOINT)).accessCode !== replacement) {
          throw new Error('Overlapping saves did not preserve latest value')
        }
        await store.clear(OWNER, ENDPOINT)
        await delegator.print('SECURE_ASSET_OPERATION_ORDER=PASS')
      } else {
        // Ability creation precedes WindowStage/router readiness on cold launches.
        for (let attempt = 0; attempt < 80; attempt++) {
          try {
            const candidate = await window.getLastWindow(getDeviceTestContext())
            if (candidate.getUIContext().getRouter().getState().name) { win = candidate; break }
          } catch (_) {}
          await new Promise<void>((done) => setTimeout(done, 100))
        }
        if (!win) { throw new Error('Initial router window not ready') }
        // Allow startup requests (including an expired-login redirect) to settle
        // before opening fixture pages; a marker must describe the visible page.
        await new Promise<void>((done) => setTimeout(done, 2500))
        orientation = win.getPreferredOrientation()
        if (args['-s layout'] === 'landscape') { await win.setPreferredOrientation(window.Orientation.LANDSCAPE) }
        const fixture: AiScoreInput = { question: '如何防止旧请求覆盖新页面？', answer: '用请求序号过滤旧响应，离页时取消。', referenceAnswer: '' }
        await win.getUIContext().getRouter().pushUrl({ url: 'pages/AiScorePage', params: fixture })
        await new Promise<void>((done) => setTimeout(done, 1000))
        if (win.getUIContext().getRouter().getState().name !== 'AiScorePage') { throw new Error('Score fixture page not visible') }
        await delegator.print('SCORE_CLEAN_PAGE_READY')
        await new Promise<void>((done) => setTimeout(done, 12000))
        await win.getUIContext().getRouter().pushUrl({ url: 'pages/ScoreSettingsPage' })
        await new Promise<void>((done) => setTimeout(done, 1000))
        if (win.getUIContext().getRouter().getState().name !== 'ScoreSettingsPage') { throw new Error('Settings fixture page not visible') }
        await delegator.print('SCORE_SETTINGS_PAGE_READY')
        await new Promise<void>((done) => setTimeout(done, 16000))
        win.getUIContext().getRouter().back()
        await new Promise<void>((done) => setTimeout(done, 1000))
        if (win.getUIContext().getRouter().getState().name !== 'AiScorePage') { throw new Error('Score page not restored') }
        await delegator.print('SCORE_RETURN_DRAFT_READY')
        await new Promise<void>((done) => setTimeout(done, 8000))
      }
    } catch (error) { failure = (error as Error).message }
    finally {
      if (failure || args['-s stage'] === 'read') { await store.clear(OWNER, ENDPOINT) }
      if (win && orientation !== undefined) {
        try { await win.setPreferredOrientation(orientation) } catch (_) { failure = 'Orientation restore failed' }
      }
    }
    await delegator.finishTest(failure || 'Score settings verification completed; no model calls', failure ? 1 : 0)
  }
}
