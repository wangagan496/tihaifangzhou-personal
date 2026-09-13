import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { systemShare } from '@kit.ShareKit'

export async function shareMineApp(context: common.UIAbilityContext): Promise<boolean> {
  if (!context) {
    return false
  }

  const shareData = new systemShare.SharedData({
    utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
    content: '题海方舟：一起刷题、记录学习时长，提升面试准备效率。',
    title: '推荐题海方舟',
    description: 'HarmonyOS NEXT 学习应用'
  })
  const controller = new systemShare.ShareController(shareData)
  try {
    await controller.show(context, { anchor: 'mineShareButton' })
    return true
  } catch (_) {
    return false
  }
}
