import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { Hypium } from '@ohos/hypium'
import audioDBTest from '../test/AudioDB.test'
import transcriptionNativeTest from '../test/TranscriptionNative.test'
import { prepareDeviceTestContext } from './DeviceTestContext'

export default class TranscriptionTestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    await prepareDeviceTestContext()
    Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), () => {
      audioDBTest()
      transcriptionNativeTest()
    })
  }
}
