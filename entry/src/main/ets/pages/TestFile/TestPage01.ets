import { componentSnapshot } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'

@Entry
@Component
struct TestPage01 {
  @State
  img: PixelMap | null = null

  build() {
    Column() {
      Column() {
        Image($r('app.media.icon'))
          .width(200)
          .height(200)
        Button('点我截图')
          .onClick(() => {
            this.img = componentSnapshot.getSync('img')
          })
        SaveButton()
          .backgroundColor($r('app.color.common_blue'))
          .onClick(async () => {
            // 1、打包图片
            const packer = image.createImagePacker()
            const arrayBuffer = await packer.packToData(this.img, { format: 'image/jpeg', quality: 100 })
            // 2、将图片写入缓存目录
            const ctx = this.getUIContext().getHostContext()
            const cacheDir = ctx?.cacheDir
            const path = `${cacheDir}/${Date.now()}.jpeg`
            const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
            fileIo.writeSync(file.fd, arrayBuffer)
            fileIo.closeSync(file.fd)
            // 3、保存图片
            try {
              const uri = fileUri.getUriFromPath(path) // 将本地文件路径转换为URI格式
              const helper = photoAccessHelper.getPhotoAccessHelper(ctx) // 获取相册访问助手实例
              const request = photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(ctx, uri) // 创建图片资源变更请求
              helper.applyChanges(request) // 应用变更请求,将图片保存到系统相册
              this.getUIContext().getPromptAction().showToast({ message: '保存成功' })
            } catch (e) {
              console.error(e)
            }
          })
      }
      .layoutWeight(1)
      .border({ width: 2, color: Color.Pink })
      .backgroundColor(Color.Orange)
      .width('100%')
      .id('img')

      Row() {
        Image(this.img)
          .width('80%')
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
  }
}

