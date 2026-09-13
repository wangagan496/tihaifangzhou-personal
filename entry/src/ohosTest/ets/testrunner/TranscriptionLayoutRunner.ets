import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { prepareDeviceTestContext, getDeviceTestContext } from './DeviceTestContext'
import { AudioDB } from '../../../main/ets/common/utils/AudioDB'
import { auth } from '../../../main/ets/common/utils/Auth'

export default class TranscriptionLayoutRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    let win: window.Window | undefined = undefined
    let orientation: window.Orientation | undefined = undefined
    let errorMessage = ''
    try {
      await prepareDeviceTestContext()
      const context = getDeviceTestContext()
      for (let attempt = 0; attempt < 50; attempt++) {
        try {
          win = await window.getLastWindow(context)
          if (win.getUIContext().getRouter().getState().name) { break }
        } catch (_) {}
        await new Promise<void>((done) => setTimeout(done, 100))
      }
      if (!win) { throw new Error('Main window unavailable') }
      const id = Number(abilityDelegatorRegistry.getArguments().parameters['-s audioId'])
      const userId = auth.getUser()?.id || ''
      const db = new AudioDB()
      if (!await db.initStore()) { throw new Error('DB initialization failed') }
      const item = await db.find(id, userId)
      if (!item || item.name !== '转写验收：合成中文语音') { throw new Error('Synthetic fixture required') }
      orientation = win.getPreferredOrientation()
      await win.getUIContext().getRouter().pushUrl({ url: 'pages/AudioTranscriptPage', params: { audioId: id } })
      await win.setPreferredOrientation(window.Orientation.LANDSCAPE)
      await new Promise<void>((done) => setTimeout(done, 1000))
      const rect = win.getWindowProperties().windowRect
      if (rect.width <= rect.height) { throw new Error('Landscape window unavailable') }
      await delegator.print('TRANSCRIPTION_LANDSCAPE_READY')
      // Keep this test-only window available for the external HDC layout and pixel inspection.
      await new Promise<void>((done) => setTimeout(done, 20000))
    } catch (error) { errorMessage = (error as Error).message }
    finally {
      try {
        if (win && orientation !== undefined) { await win.setPreferredOrientation(orientation) }
      } catch (_) { errorMessage = 'Display restoration failed' }
    }
    await delegator.finishTest(errorMessage || 'Landscape window inspected and original orientation restored', errorMessage ? 1 : 0)
  }
}
