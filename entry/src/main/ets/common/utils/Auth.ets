import { ILoginDta } from '../../models/AccountModel';
import { contextManager } from './ContextManager';
import { promptAction, router } from '@kit.ArkUI';
import { buildAuthBackParams, hasLoginToken } from './AuthPolicy';

// 1、mine页面判断是否登录，登录了就显示用户信息，没有登录就显示未登录，点击跳转登录页
// 2、用户数据持久化工具类，封装了AppStorage和PersistentStorage，对原来存用户数据取用户数据的操作进行替换
class Auth {
  // 初始化用户信息,确保信息能够持久化
  initUser(): void {
    PersistentStorage.persistProp('user', {})
  }

  // 保存或修改用户信息
  setUser(user: ILoginDta): void {
    AppStorage.set('user', user)
  }

  // 获取用户信息
  getUser(): ILoginDta | undefined {
    return AppStorage.get<ILoginDta>('user')
  }

  // 移除用户信息
  removeUser(): void {
    AppStorage.set('user', {})
  }

  // 1、checkAuth函数，检查用户是否登录
  // 登录：直接跳转页面
  // 未登录：将参数携带到登录页面
  // 2、登录页面，登录成功后，将参数从登录页面取出，跳转页面，登录页面使用replaceUrl跳转
  // 3、原来url参数为LoginPage的，修改为目标页面
  // 4、使用getRouter跳转的都改为checkAuth，参数直接传递到checkAuth
  // 受保护页面统一从这里进入：未登录时保存目标路由，登录成功后再回跳。
  checkAuth(options: router.RouterOptions): Promise<void> {
    const user = this.getUser();
    if (!hasLoginToken(user?.token)) {
      return this.navigateToLogin(options, '请先登录')
    }
    return contextManager.UiCtx?.getRouter().pushUrl(options).then((): void => {}, (): void => {}) || Promise.resolve()
  }

  private navigateToLogin(options: router.RouterOptions, message: string): Promise<void> {
    const backParams = buildAuthBackParams(options.url, options.params)
    return promptAction.openToast({ message: message }).then(() => {
      return contextManager.UiCtx?.getRouter().pushUrl({
        url: 'pages/LoginPage',
        params: backParams
      })
    }, (): void => {}).then((): void => {}, (): void => {})
  }
}

// 创建Auth实例
export const auth = new Auth();

export interface IRouterBackParams {
  backUrl: string,
  backParams: object | undefined
}
