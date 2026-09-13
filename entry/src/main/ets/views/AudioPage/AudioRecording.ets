// Result produced by the recorder before it is attached to a user or database row.
export interface AudioRecording {
  path: string
  duration: number
  size: number
  createTime: number
}

// 文件大小是录音是否真正落盘的可靠信号；振幅会因设备路由和用户音量变化。
export function hasUsableAudioFile(recording: AudioRecording): boolean {
  return recording.path.trim().length > 0 && recording.size > 0
}
