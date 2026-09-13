import { audioDB, InterviewAudioItem } from '../../common/utils/AudioDB'
import { auth } from '../../common/utils/Auth'
import { AudioItemComp } from './AudioItemComp'
import { AudioRecordComp } from './AudioRecordComp'
import { InputDialog } from './InputDialog'
import { AudioPlayer } from './AudioPlay'
import { fileIo } from '@kit.CoreFileKit'

@Component
export struct AudioView {
  @StorageProp('topHeight') topHeight: number = 0
  @State list: InterviewAudioItem[] = []
  @State currentItem: InterviewAudioItem | null = null
  @State isShow: boolean = false
  dialog = new CustomDialogController({
    builder: InputDialog({
      name: this.currentItem?.name,
      onSubmit: (name: string) => { this.renameAudio(name) }
    }),
    customStyle: true
  })

  aboutToAppear(): void {
    this.loadAudioData()
  }

  private loadAudioData(): void {
    audioDB.initStore().then((initialized) => {
      if (!initialized) {
        this.showToast('录音数据初始化失败')
        return
      }
      this.getList()
    }, () => this.showToast('录音数据初始化失败'))
  }

  private getList(): void {
    const userId = auth.getUser()?.id
    if (!userId) {
      this.list = []
      return
    }
    audioDB.query(userId).then((items) => { this.list = items }, () => { this.list = [] })
  }

  private renameAudio(name: string): void {
    const item = this.currentItem
    const trimmedName = name.trim()
    if (!item || !trimmedName) { return }
    item.name = trimmedName
    audioDB.update(item).then((updated) => {
      if (!updated) { this.showToast('重命名失败，请重试'); return }
      this.getList()
      this.dialog.close()
    }, () => this.showToast('重命名失败，请重试'))
  }

  private saveAudio(item: InterviewAudioItem): void {
    audioDB.insert(item).then((inserted) => {
      if (inserted) { this.getList(); return }
      this.showToast('录音保存失败')
    }, () => this.showToast('录音保存失败'))
  }

  private deleteAudio(item: InterviewAudioItem): void {
    if (item.id === null) { this.showToast('删除录音失败'); return }
    audioDB.delete(item.id).then((deleted) => {
      if (!deleted) { this.showToast('删除录音失败'); return }
      fileIo.unlinkSync(item.path)
      this.getList()
    }, () => this.showToast('删除录音失败'))
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message })
  }

  build() {
    Navigation() {
      Column() {
        Column() {
          List() {
            ForEach(this.list, (item: InterviewAudioItem) => {
              ListItem() { AudioItemComp({ item }) }
                .swipeAction({ end: this.ListItemSwiperBuilder(item) })
                .onClick(() => { this.currentItem = item; this.isShow = true })
            })
          }.width('100%').height('100%')
        }.width('100%').layoutWeight(1)
        AudioRecordComp({ onRecordEnd: (item: InterviewAudioItem) => { this.saveAudio(item) } })
      }.width('100%').height('100%')
    }.titleMode(NavigationTitleMode.Mini).title('音频').padding({ top: this.topHeight })
      .bindSheet($$this.isShow, this.audioPlayBuilder())
  }

  @Builder
  audioPlayBuilder() {
    Column() { AudioPlayer({ item: this.currentItem! }) }
  }

  @Builder
  ListItemSwiperBuilder(item: InterviewAudioItem) {
    Row() {
      Text('编辑').actionButton($r('app.color.common_blue')).onClick(() => { this.currentItem = item; this.dialog.open() })
      Text('删除').actionButton('#FF0033').onClick(() => { this.deleteAudio(item) })
    }.height('100%')
  }
}

@Extend(Text)
function actionButton(color: ResourceColor) {
  .width(80).aspectRatio(1).backgroundColor(color).textAlign(TextAlign.Center).fontColor($r('app.color.white'))
}
