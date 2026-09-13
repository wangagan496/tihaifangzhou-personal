import { auth, IRouterBackParams } from '../common/utils/Auth'
import { tgRequest } from '../common/utils/request'
import { ILoginBody, ILoginDta } from '../models/AccountModel'
import { router } from '@kit.ArkUI'
import { contextManager } from '../common/utils/ContextManager'

@Entry
@Component
struct LoginPage {
  @StorageLink('demoUsername') username: string = ''
  @StorageLink('demoPassword') password: string = ''
  @State isAgree: boolean = false
  @State isLoading: boolean = false
  routerParams: router.RouterOptions | undefined = undefined

  aboutToAppear(): void {
    contextManager.ctx = this.getUIContext().getHostContext()!
    contextManager.UiCtx = this.getUIContext()
    const params = this.getUIContext().getRouter().getParams()
    if (params) {
      this.routerParams = params as router.RouterOptions
    }
  }

  login(): void {
    const username = this.username.trim()
    const password = this.password
    if (!username || !password) {
      this.showToast('请填写用户名和密码')
      return
    }
    if (!this.isAgree) {
      this.showToast('请先阅读并同意用户协议和隐私政策')
      return
    }

    this.isLoading = true
    tgRequest<ILoginDta, ILoginBody>({
      url: '/hm/login',
      method: 'POST',
      data: { username, password }
    }).then((user) => {
      if (!user.username) {
        user.username = username
      }
      auth.setUser(user)
      const params = this.getUIContext().getRouter().getParams() as IRouterBackParams
      const navigation = params
        ? this.getUIContext().getRouter().replaceUrl({ url: params.backUrl, params: params.backParams })
        : this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' })
      navigation.then(() => {
        this.isLoading = false
        this.showToast('登录成功')
      }, () => {
        this.isLoading = false
        this.showToast('页面跳转失败，请重试')
      })
    }, () => {
      this.isLoading = false
      this.showToast('登录失败，请检查网络或账号信息')
    })
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      return
    }
  }

  build() {
    Column() {
      Column({ space: 10 }) {
        Image($r('app.media.icon')).height(55).aspectRatio(1)
        Text('题海方舟').fontSize(28).fontColor('#121826')
        Text('搞定学习难题，就用题海方舟').fontSize(14).fontColor('#6F6F6F')
      }.margin({ top: 170 })

      Column({ space: 20 }) {
        TextInput({ placeholder: '请输入账号', text: $$this.username })
          .backgroundColor(Color.White)
          .placeholderColor('#9AA4B2')
          .fontColor('#121826')
          .fontSize(16)
          .height(48)
          .padding({ left: 16, right: 16 })
          .width('90%')
          .border({ width: 1, color: '#D9E1EA' })
          .borderRadius(6)
        TextInput({ placeholder: '请输入密码', text: $$this.password })
          .type(InputType.Password)
          .backgroundColor(Color.White)
          .placeholderColor('#9AA4B2')
          .fontColor('#121826')
          .fontSize(16)
          .height(48)
          .padding({ left: 16, right: 16 })
          .width('90%')
          .border({ width: 1, color: '#D9E1EA' })
          .borderRadius(6)
        Row() {
          Checkbox().select($$this.isAgree).selectedColor('#3a9bfc')
          Text('已阅读并同意').fontSize(14).fontColor($r('app.color.ih_gray_color')).padding({ right: 4 })
          Text('用户协议').fontSize(14).padding({ right: 4 }).onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage', params: { sign: 'local' } })
          })
          Text('和').fontSize(14).fontColor($r('app.color.ih_gray_color')).padding({ right: 4 })
          Text('隐私政策').fontSize(14).onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPage', params: { sign: 'online' } })
          })
        }.width('90%')
        Button() {
          Row() {
            if (this.isLoading) {
              LoadingProgress().height(28).aspectRatio(1).color(Color.White)
            }
            Text('登录')
          }
        }.onClick(() => { this.login() })
          .borderRadius(4).width(328).height(45).fontColor(Color.White)
          .linearGradient({ angle: 135, colors: [['#3a9bfa', 0], ['#3a9bfc', 1]] })
      }.margin({ top: 50 })
    }.width('100%').height('100%')
  }
}
