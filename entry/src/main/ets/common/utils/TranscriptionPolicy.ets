export const PCM_BYTES_PER_SECOND: number = 32000
export const PCM_PACKET_BYTES: number = 1280
export const MAX_TRANSCRIPTION_MS: number = 30 * 60 * 1000
export const MAX_TRANSCRIPT_LENGTH: number = 60000
// Keep each offline request short as well as below writeAudio's 60-second limit.
// Longer requests can lose their session while the emulator's offline engine is still processing.
export const PCM_MAX_SESSION_BYTES: number = 15 * PCM_BYTES_PER_SECOND

export function choosePcmSegmentLength(pcm: Uint8Array, isLast: boolean): number {
  const end = Math.min(pcm.length - pcm.length % 2, PCM_MAX_SESSION_BYTES)
  if (isLast || end < PCM_MAX_SESSION_BYTES) { return end }
  const begin = Math.max(0, end - 5 * PCM_BYTES_PER_SECOND)
  let quietStart = -1
  let boundary = end
  for (let offset = begin; offset + 640 <= end; offset += 640) {
    let sum = 0
    for (let i = offset; i < offset + 640; i += 2) {
      const unsigned = pcm[i] | pcm[i + 1] << 8
      sum += Math.abs(unsigned >= 32768 ? unsigned - 65536 : unsigned)
    }
    if (sum / 320 < 450) {
      if (quietStart < 0) { quietStart = offset }
      if (offset + 640 - quietStart >= 3200) {
        boundary = Math.floor((quietStart + offset + 640) / 4) * 2
      }
    } else { quietStart = -1 }
  }
  return boundary
}

export function recognitionEngineOptions(): Record<string, Object> {
  const options: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'long' }
  return options
}

export function recognitionStreamOptions(): Record<string, Object> {
  const options: Record<string, Object> = { 'recognitionMode': 1, 'maxAudioDuration': MAX_TRANSCRIPTION_MS }
  return options
}

export class TranscriptAccumulator {
  private sentences: string[] = []
  private partial: string = ''

  add(text: string, isFinal: boolean, isLast: boolean): string {
    const value = text.trim()
    if (isFinal || isLast) {
      if (value) { this.sentences.push(value) }
      this.partial = ''
    } else {
      this.partial = value
    }
    const result = this.preview()
    if (result.length > MAX_TRANSCRIPT_LENGTH) { throw new Error('TEXT_TOO_LONG') }
    return result
  }

  preview(): string { return this.sentences.concat(this.partial ? [this.partial] : []).join('\n') }
  result(): string { return this.sentences.join('\n').trim() }
}

export function transcriptionPercent(sent: number, total: number): number {
  if (!Number.isFinite(sent) || !Number.isFinite(total) || total <= 0) { return 0 }
  return Math.max(0, Math.min(100, Math.floor(sent * 100 / total)))
}

export function canSaveTranscript(audioId: number, userId: string, text: string): boolean {
  return Number.isSafeInteger(audioId) && audioId > 0 && userId.trim().length > 0 &&
    text.trim().length > 0 && text.length <= MAX_TRANSCRIPT_LENGTH
}

export function transcriptionErrorMessage(code: string): string {
  switch (code) {
    case 'CANCELLED': return '已取消转写，原录音和已有文字均已保留'
    case 'ENGINE_UNAVAILABLE': return '此设备的中文离线识别引擎暂不可用，请检查系统语音资源后重试'
    case 'ENGINE_BUSY': return '系统语音识别正在被占用，请稍后重试'
    case 'ENGINE_TIMEOUT': return '语音识别引擎启动超时，请稍后重试'
    case 'AUDIO_FILE': return '录音文件不存在或无法读取'
    case 'AUDIO_FORMAT': return '暂不支持此录音的音频格式'
    case 'AUDIO_TOO_LONG': return '目前支持转写 30 分钟以内的录音'
    case 'AUDIO_EMPTY': return '录音中没有可处理的音频'
    case 'AUDIO_WRITE': return '无法创建转写缓存，请检查设备剩余空间'
    case 'AUDIO_BUSY': return '音频处理正在收尾，请稍后重试'
    case 'AUDIO_TIMEOUT': return '音频解码超时，请重试'
    case 'AUDIO_DECODE': case 'AUDIO_BUFFER': return '录音解码失败，原文件已保留'
    case 'NO_SPEECH': return '未识别到有效中文语音，请确认录音内容清晰后重试'
    case 'EARLY_END': return '识别提前结束，未保存不完整结果，请重试'
    case 'RECOGNITION_TIMEOUT': return '转写超时，未保存不完整结果，请重试'
    case 'TEXT_TOO_LONG': return '转写文字超过当前保存上限'
    default: return '转写失败，原录音和已有文字均已保留，请重试'
  }
}
