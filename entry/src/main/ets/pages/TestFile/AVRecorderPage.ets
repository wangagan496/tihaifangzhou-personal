import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'
import { permission } from '../../common/utils/Permission'
import { promptAction } from '@kit.ArkUI'
import { Permissions } from '@kit.AbilityKit'
import { AudioBoComp } from '../../views/AudioPage/AudioBoComp'

/**
 * 音频录制与播放页面
 * 功能：实现录音、停止录音、播放录音、停止播放等功能，并实时显示录音振幅
 */
@Entry
@Component
struct AVRecorderPage {
  // 需要申请的权限列表（麦克风权限）
  permissions: Permissions[] = ['ohos.permission.MICROPHONE']
  // 权限申请失败时的提示框配置
  confirmConfig: promptAction.ShowDialogOptions = {
    title: "温馨提示",
    message: "未授权使用麦克风将无法使用该面试录音功能，是否前往设置进行授权？",
    buttons: [
      { text: '离开', color: $r('app.color.common_gray_01') },
      { text: '去授权', color: $r('app.color.common_blue') }
    ]
  }

  /**
   * 获取麦克风权限
   * 流程：先请求权限 -> 失败则弹窗提示 -> 用户选择去设置则再次请求 -> 仍失败则返回上一页
   */
  async getPermission() {
    try {
      // 第一次请求权限
      const isOk = await permission.requestPermissions(this.permissions)
      if (isOk) {
        return
      }
      // 权限被拒绝，显示提示框
      const confirm = await this.getUIContext().getPromptAction().showDialog(this.confirmConfig)
      if (confirm.index === 1) {
        // 用户点击"去授权"，跳转到系统设置页面请求权限
        const isAllow = await permission.onSettingPermissions(this.permissions)
        if (isAllow) {
          return
        }
      }
      // 用户拒绝授权或设置中仍未授权，返回上一页
      this.getUIContext().getRouter().back()
    } catch (e) {
      // 异常情况，显示提示并返回
      promptAction.openToast({ message: '未授权' })
        .then(() => {
          this.getUIContext().getRouter().back()
        })

    }
  }

  // 页面加载时请求权限
  aboutToAppear(): void {
    this.getPermission()
  }

  // 音频录制器实例
  avRecorder: media.AVRecorder | null = null
  // 文件描述符
  fd: number | null = null
  // 录音文件保存路径
  filePath: string = ''
  // 实时振幅值（用于驱动UI更新）
  @State maxAmplitude: number = 0
  // 定时器ID（用于周期性获取振幅）
  timerId: number | null = null

  /**
   * 开始播放录音
   * 使用AVPlayer播放之前录制的音频文件
   */
  async startPlay() {
    try {
      // 以只读模式打开录音文件
      const file = fileIo.openSync(this.filePath, fileIo.OpenMode.READ_ONLY)
      // 创建AVPlayer实例
      const avPlayer = await media.createAVPlayer()

      // 监听播放器状态变化
      avPlayer.on('stateChange', state => {
        if (state === 'initialized') {
          // 初始化完成后，准备播放
          avPlayer.prepare()
        } else if (state === 'prepared') {
          // 准备完成后，设置循环播放并开始播放
          avPlayer.loop = true
          this.total = avPlayer.duration // 获取音频总时长
          avPlayer.play()
        }
      })

      // 监听播放进度更新
      avPlayer.on('timeUpdate', (time) => {
        this.value = time // 更新当前播放时间
      })

      // 设置播放源为文件描述符
      avPlayer.url = `fd://${file.fd}`
      // 保存播放器实例以便后续控制
      this.avPlayer = avPlayer
    } catch (e) {
      // 播放异常处理
    }
  }

  /**
   * 停止播放
   * 停止播放器并释放资源
   */
  stopPlay() {
    if (this.avPlayer) {
      this.avPlayer.stop().then(() => {
        this.avPlayer?.release()
      })
    }
  }

  // 音频播放器实例
  avPlayer?: media.AVPlayer
  // 音频总时长（单位：毫秒）
  @State total: number = 0
  // 当前播放时间（单位：毫秒）
  @State value: number = 0

  /**
   * 开始录音
   * 创建录音器、配置参数、开始录制，并启动定时器实时获取振幅
   */
  async startRecord() {
    // 创建AVRecorder实例
    this.avRecorder = await media.createAVRecorder()

    // 配置音频录制参数
    let avProfile: media.AVRecorderProfile = {
      audioBitrate: 112000, // 音频比特率（码率）
      audioChannels: 2, // 音频声道数（立体声）
      audioCodec: media.CodecMimeType.AUDIO_AAC, // 音频编码格式（AAC）
      aacProfile: media.AacProfile.AAC_HE, // AAC编码扩展格式（高效AAC）
      audioSampleRate: 48000, // 音频采样率（48kHz）
      fileFormat: media.ContainerFormatType.CFT_MPEG_4A, // 封装格式（MPEG-4 Audio）
    };

    // 生成录音文件路径（缓存目录 + 时间戳.mp3）
    const ctx = AppStorage.get<Context>('context')
    let filePath = ctx?.cacheDir + '/' + Date.now() + '.mp3'
    this.filePath = filePath
    // 创建文件并获取文件描述符
    const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
    this.fd = file.fd

    // 配置录音器
    let avConfig: media.AVRecorderConfig = {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC, // 音频输入源（麦克风）
      profile: avProfile, // 音频参数配置
      url: 'fd://' + this.fd.toString(), // 输出文件路径（使用文件描述符）
    };

    // 准备录音器
    await this.avRecorder.prepare(avConfig)
    // 开始录音
    await this.avRecorder.start()

    // 启动定时器，每100ms获取一次最大振幅值
    this.timerId = setInterval(async () => {
      this.maxAmplitude = await this.avRecorder?.getAudioCapturerMaxAmplitude()!
    }, 100)
  }

  build() {
    Column({ space: 20 }) {
      // 开始录制按钮
      Button('录制')
        .onClick(() => {
          this.startRecord()
        })
      // 停止录制按钮
      Button('停止录制')
        .onClick(() => {
          this.avRecorder?.stop() // 停止录音
          this.avRecorder?.release() // 释放录音器资源
          fileIo.closeSync(this.fd) // 关闭文件描述符
          clearInterval(this.timerId) // 清除振幅获取定时器
        })
      // 振幅可视化组件（实时显示录音音量）
      AudioBoComp({ maxAmplitude: this.maxAmplitude })
      // 播放录音按钮
      Button('播放')
        .backgroundColor(Color.Red)
        .onClick(() => {
          this.startPlay()
        })
      // 停止播放按钮
      Button('停止播放')
        .backgroundColor(Color.Red)
        .onClick(() => {
          this.stopPlay()
        })
    }
    .height('100%')
    .width('100%')
  }
}
