import { audioDB, InterviewAudioItem } from '../../common/utils/AudioDB'
import { auth } from '../../common/utils/Auth'
import { AudioItemComp } from './AudioItemComp'
import { AudioRecordComp } from './AudioRecordComp'
import { InputDialog } from './InputDialog'
import { AudioPlayer } from './AudioPlay'
import { fileIo } from '@kit.CoreFileKit'
import { AudioRecording } from './AudioRecording'
import dayjs from 'dayjs'

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

  private saveAudio(recording: AudioRecording): void {
    const user = auth.getUser()
    if (!user?.id) {
      this.removeAudioFile(recording.path)
      this.showToast('录音保存失败')
      return
    }
    const item: InterviewAudioItem = {
      id: null,
      user_id: user.id,
      name: dayjs().format('YYYY-MM-DD HH:mm:ss'),
      path: recording.path,
      duration: recording.duration,
      size: recording.size,
      create_time: recording.createTime
    }
    audioDB.insert(item).then((inserted) => {
      if (inserted) {
        this.getList()
        this.showToast('录音保存成功')
        return
      }
      this.removeAudioFile(recording.path)
      this.showToast('录音保存失败')
    }, () => {
      this.removeAudioFile(recording.path)
      this.showToast('录音保存失败')
    })
  }

  private removeAudioFile(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_) {
      // The file may already have been removed after an incomplete recording.
    }
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
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      return
    }
  }

  build() {
    Navigation() {
      Column() {
        Column() {
          List({ space: 8 }) {
            ForEach(this.list, (item: InterviewAudioItem) => {
              ListItem() { AudioItemComp({ item }) }
                .swipeAction({ end: this.ListItemSwiperBuilder(item) })
                .onClick(() => { this.currentItem = item; this.isShow = true })
            })
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        }.width('100%').layoutWeight(1)
        AudioRecordComp({ onRecordEnd: (recording: AudioRecording) => this.saveAudio(recording) })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FA')
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
