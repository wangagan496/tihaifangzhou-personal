import { webview } from '@kit.ArkWeb'

/*
 * 1、创建一个webview页面
 * 2、设置webview的src属性为html文件路径或者url
 * 3、设置webview的controller属性为webview.WebviewController
 * 4、在aboutToAppear生命周期中接收路由参数，判断是本地的html文件还是外链的url
 *
 * */
@Entry
@Component
export default struct PrivacyPage {
  controller = new webview.WebviewController()
  url: string | Resource = ''

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as object
    if (params) {
      if (params['sign'] === 'local') {
        this.url = $rawfile('index.html')
      } else if (params['sign'] === 'online') {
        this.url = 'https://developer.huawei.com/consumer/cn/agreement/'
      }
    }
  }

  build() {
    Column() {
      Web({
        src: this.url,
        controller: this.controller
      })
    }
  }
}