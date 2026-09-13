import { abilityDelegatorRegistry } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'

let context: common.UIAbilityContext | undefined = undefined

export async function prepareDeviceTestContext(): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const monitor: abilityDelegatorRegistry.AbilityMonitor = { abilityName: 'EntryAbility' }
  await delegator.addAbilityMonitor(monitor)
  try {
    await delegator.startAbility({ bundleName: 'com.mine.myapplication', abilityName: 'EntryAbility' })
    const ability = await delegator.waitAbilityMonitor(monitor, 10000)
    context = ability.context
    AppStorage.setOrCreate('context', context)
  } finally { await delegator.removeAbilityMonitor(monitor) }
}

export function getDeviceTestContext(): common.UIAbilityContext {
  if (!context) { throw new Error('Device test context is not prepared') }
  return context
}
