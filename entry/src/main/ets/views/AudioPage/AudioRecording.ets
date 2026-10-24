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

export type RecorderPhase = 'idle' | 'warmup' | 'recording' | 'stopping'
export type RecorderReaction = 'ignore' | 'finish' | 'abort'

// AVRecorder 状态回调的处理策略：error/released 放弃本次录音；系统触发的暂停或停止
// 在正式录音阶段按正常停止流程保存，热身阶段尚无有效内容则放弃；用户操作引起的切换忽略。
export function reactToRecorderState(phase: RecorderPhase, state: string, bySystem: boolean): RecorderReaction {
  if (phase === 'idle' || phase === 'stopping') { return 'ignore' }
  if (state === 'error' || (bySystem && state === 'released')) { return 'abort' }
  if (bySystem && (state === 'paused' || state === 'stopped')) {
    return phase === 'recording' ? 'finish' : 'abort'
  }
  return 'ignore'
}
