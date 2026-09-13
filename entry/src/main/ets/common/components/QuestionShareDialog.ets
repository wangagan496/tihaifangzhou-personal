import { ILoginDta } from '../../models/AccountModel'
import { QuestionDetail } from '../../pages/QuestionDetailPage'
import { componentSnapshot } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'

@CustomDialog
export struct QuestionShareDialog {
  item: QuestionDetail = {} as QuestionDetail
  contentType: 0 | 1 = 0
  @StorageProp('user') user: ILoginDta = {} as ILoginDta
  controller: CustomDialogController

  saveImage(): void {
    const context = this.getUIContext().getHostContext()
    if (!context) { return }
    const pixelMap = componentSnapshot.getSync('share')
    const imagePacker = image.createImagePacker()
    imagePacker.packToData(pixelMap, { format: 'image/jpeg', quality: 98 }).then((buffer) => {
      const imagePath = `${context.cacheDir}/${Date.now()}.jpeg`
      const file = fileIo.openSync(imagePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      fileIo.writeSync(file.fd, buffer)
      fileIo.closeSync(file.fd)
      imagePacker.release()
      pixelMap.release()
      const uri = fileUri.getUriFromPath(imagePath)
      const helper = photoAccessHelper.getPhotoAccessHelper(context)
      const request = photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, uri)
      helper.applyChanges(request).then(() => {
        this.controller.close()
        this.getUIContext().getPromptAction().showToast({ message: '保存成功' })
      }, () => this.getUIContext().getPromptAction().showToast({ message: '保存失败，请检查图库授权' }))
    }, () => {
      imagePacker.release()
      pixelMap.release()
      this.getUIContext().getPromptAction().showToast({ message: '保存图片失败' })
    })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 20 }) {
        Image($r('app.media.icon')).width(40).height(40)
        Text('题海方舟，搞定学习难题')
        Divider().strokeWidth(0.5).color($r('app.color.common_gray_border'))
        Text((this.contentType === 1 ? '真实面经：' : '大厂面试题：') + this.item.stem)
          .fontSize(12).maxLines(2).fontWeight(600).width('100%').lineHeight(24)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Column({ space: 20 }) {
          QRCode(this.item.id).width(160).height(160)
          Text(this.contentType === 1 ? '扫码阅读面经' : '扫码查看答案').fontSize(12).alignSelf(ItemAlign.Center)
        }.width('100%')
        Blank()
        Text('分享来自：' + (this.user.nickName || this.user.username || '题海方舟')).fontSize(12)
      }.id('share').padding(20).alignItems(HorizontalAlign.Start).width(300).height(500).backgroundColor('#fff')
      Row() {
        SaveButton({ icon: SaveIconStyle.FULL_FILLED, text: SaveDescription.SAVE_IMAGE, buttonType: ButtonType.Normal })
          .fontColor($r('app.color.white')).fontSize(14).padding(12).backgroundColor($r('app.color.common_blue'))
          .onClick((_event, result) => { if (result === SaveButtonOnClickResult.SUCCESS) { this.saveImage() } })
      }.borderRadius({ topLeft: 8 }).clip(true)
    }.borderRadius(8).clip(true)
  }
}
