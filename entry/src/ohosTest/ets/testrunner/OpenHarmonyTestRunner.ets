import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit'
import { Hypium } from '@ohos/hypium'
import testsuite from '../test/List.test'
import { prepareDeviceTestContext } from './DeviceTestContext'

// The standard runner filename also identifies this project as a source-based device-test layout to Hvigor.
export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {}
  async onRun(): Promise<void> {
    const delegator = abilityDelegatorRegistry.getAbilityDelegator()
    await prepareDeviceTestContext()
    Hypium.hypiumTest(delegator, abilityDelegatorRegistry.getArguments(), testsuite)
  }
}
