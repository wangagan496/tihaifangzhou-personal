import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct WebViewPage {
  @State message: string = 'Hello World';
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({
        src: $rawfile('index01.html'), // 填写网页地址
        controller: this.controller // 绑定控制器
      })
        .height('60%')
      Button('改变文本')
        .onClick(() => {
          this.controller.runJavaScript('changeText()')
        })

    }
    .height('100%')
    .width('100%')
  }
}