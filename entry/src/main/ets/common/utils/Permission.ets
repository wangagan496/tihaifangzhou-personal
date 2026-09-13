// 1、保存context 上下文
// 2、在permission类中写两个方法，一：用户授权，二：拉起设置授权
// 3、实例化导出
// 4、在页面中使用授权工具
import { abilityAccessCtrl, PermissionRequestResult, Permissions } from '@kit.AbilityKit'

class Permission {
  private isAllow: boolean = false

  requestPermissions(permissions: Permissions[]): Promise<boolean> {
    const mgr = abilityAccessCtrl.createAtManager()
    const ctx = AppStorage.get<Context>('context')
    if (!ctx) {
      return Promise.resolve(false)
    }
    return mgr.requestPermissionsFromUser(ctx, permissions).then((data: PermissionRequestResult): boolean => {
      this.isAllow = data.authResults.every(item => item === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED)
      return this.isAllow
    }, (): boolean => {
      this.isAllow = false
      return false
    })
  }

  onSettingPermissions(permissions: Permissions[]): Promise<boolean> {
    const mgr = abilityAccessCtrl.createAtManager()
    const ctx = AppStorage.get<Context>('context')
    if (!ctx) {
      return Promise.resolve(false)
    }
    return mgr.requestPermissionOnSetting(ctx, permissions).then((res): boolean => {
      return res.every(i => i === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED)
    }, (): boolean => {
      return false
    })
  }
}

export const permission = new Permission()
