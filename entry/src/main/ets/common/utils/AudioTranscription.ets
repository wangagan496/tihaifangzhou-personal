import { speechRecognizer } from '@kit.CoreSpeechKit'
import { fileIo } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { decodeToPcm, cancelDecode } from 'libaudiopcm.so'
import { PCM_BYTES_PER_SECOND, PCM_PACKET_BYTES, TranscriptAccumulator, transcriptionPercent,
  recognitionEngineOptions, recognitionStreamOptions, PCM_MAX_SESSION_BYTES, MAX_TRANSCRIPT_LENGTH,
  choosePcmSegmentLength } from './TranscriptionPolicy'

export interface TranscriptionProgress {
  phase: 'preparing' | 'recognizing'
  percent: number
  partial: string
}

let sequence: number = 0

export class AudioTranscriptionJob {
  private readonly id: string = `asr_${Date.now()}_${++sequence}`
  private cancelled: boolean = false
  private finished: boolean = false
  private engine?: speechRecognizer.SpeechRecognitionEngine
  private rejectSession?: (error: Error) => void
  private feedingTask?: Promise<void>
  private sessionId: string = this.id
  private readonly maxSegmentBytes: number

  constructor(maxSegmentBytes: number = PCM_MAX_SESSION_BYTES) {
    if (!Number.isSafeInteger(maxSegmentBytes) || maxSegmentBytes < PCM_PACKET_BYTES ||
      maxSegmentBytes > PCM_MAX_SESSION_BYTES || maxSegmentBytes % PCM_PACKET_BYTES !== 0) {
      throw new Error('AUDIO_ARGUMENT')
    }
    this.maxSegmentBytes = maxSegmentBytes
  }

  cancel(): void {
    this.cancelled = true
    try { cancelDecode(this.id) } catch (_) {}
    try { this.engine?.cancel(this.sessionId) } catch (_) {}
    this.rejectSession?.(new Error('CANCELLED'))
  }

  private ensureActive(): void {
    if (this.cancelled) { throw new Error('CANCELLED') }
  }

  async run(source: string, cacheDir: string, update: (progress: TranscriptionProgress) => void): Promise<string> {
    const destination = `${cacheDir}/${this.id}.pcm`
    let file: fileIo.File | undefined = undefined
    try {
      this.ensureActive()
      if (!canIUse('SystemCapability.AI.SpeechRecognizer')) { throw new Error('ENGINE_UNAVAILABLE') }
      update({ phase: 'preparing', percent: 0, partial: '' })
      this.engine = await this.createEngine()
      this.ensureActive()
      const bytes = await decodeToPcm(source, destination, this.id)
      this.ensureActive()
      if (bytes <= 0 || bytes % 2 !== 0) { throw new Error('AUDIO_EMPTY') }
      file = await fileIo.open(destination, fileIo.OpenMode.READ_ONLY)
      this.ensureActive()
      const stat = await fileIo.stat(destination)
      if (stat.size !== bytes) { throw new Error('AUDIO_FILE') }
      const parts: string[] = []
      let consumed = 0
      let carry = new Uint8Array(0)
      let partIndex = 0
      while (consumed < bytes) {
        this.ensureActive()
        const length = Math.min(this.maxSegmentBytes, bytes - consumed)
        const buffer = await this.readSegment(file.fd, length, carry)
        const boundary = choosePcmSegmentLength(buffer, consumed + length === bytes)
        carry = buffer.slice(boundary)
        this.sessionId = `${this.id}_part_${++partIndex}`
        const completed = parts.join('\n')
        const text = await this.recognize(this.engine, buffer.subarray(0, boundary), this.sessionId, (progress) => {
          const sent = consumed + boundary * progress.percent / 100
          update({ phase: 'recognizing', percent: transcriptionPercent(sent, bytes),
            partial: [completed, progress.partial].filter((value) => value.length > 0).join('\n') })
        })
        await this.feedingTask
        this.ensureActive()
        if (text) { parts.push(text) }
        consumed += boundary
        if (parts.join('\n').length > MAX_TRANSCRIPT_LENGTH) { throw new Error('TEXT_TOO_LONG') }
      }
      const result = parts.join('\n').trim()
      if (!result) { throw new Error('NO_SPEECH') }
      return result
    } finally {
      this.finished = true
      this.rejectSession = undefined
      try { this.engine?.shutdown() } catch (_) {}
      this.engine = undefined
      // A recognition callback can complete while an asynchronous file read is still in flight.
      await this.feedingTask
      if (file) { try { await fileIo.close(file) } catch (_) {} }
      try { await fileIo.unlink(destination) } catch (_) {}
    }
  }

  private createEngine(): Promise<speechRecognizer.SpeechRecognitionEngine> {
    return new Promise((resolve, reject) => {
      let settled = false
      const fail = (error: Error): void => {
        if (settled) { return }
        settled = true
        clearTimeout(timer)
        this.rejectSession = undefined
        reject(error)
      }
      const timer = setTimeout(() => fail(new Error('ENGINE_TIMEOUT')), 20000)
      this.rejectSession = fail
      try {
        speechRecognizer.createEngine({ language: 'zh-CN', online: 1, extraParams: recognitionEngineOptions() }).then((engine) => {
          if (settled || this.cancelled || this.finished) {
            try { engine.shutdown() } catch (_) {}
            fail(new Error('CANCELLED'))
            return
          }
          settled = true
          clearTimeout(timer)
          this.rejectSession = undefined
          resolve(engine)
        }, (error: BusinessError) => {
          hilog.warn(0x0000, 'AudioTranscription', 'Offline engine creation failed: %{public}d', error.code)
          fail(new Error(error.code === 1002200006 ? 'ENGINE_BUSY' : 'ENGINE_UNAVAILABLE'))
        })
      } catch (_) { fail(new Error('ENGINE_UNAVAILABLE')) }
    })
  }

  private async readSegment(fd: number, length: number, carry: Uint8Array): Promise<Uint8Array> {
    const segment = new Uint8Array(length)
    segment.set(carry)
    let offset = carry.length
    while (offset < length) {
      const buffer = new ArrayBuffer(Math.min(65536, length - offset))
      const read = await fileIo.read(fd, buffer)
      this.ensureActive()
      if (read <= 0) { throw new Error('AUDIO_FILE') }
      segment.set(new Uint8Array(buffer, 0, read), offset)
      offset += read
    }
    return segment
  }

  private recognize(engine: speechRecognizer.SpeechRecognitionEngine, pcm: Uint8Array, sessionId: string,
    update: (progress: TranscriptionProgress) => void): Promise<string> {
    const bytes = pcm.length
    return new Promise((resolve, reject) => {
      const transcript = new TranscriptAccumulator()
      let settled = false
      let feeding = false
      let inputEnded = false
      let sent = 0
      let percent = -1
      const finish = (error?: Error): void => {
        if (settled) { return }
        settled = true
        clearTimeout(timer)
        clearTimeout(startTimer)
        this.rejectSession = undefined
        if (this.cancelled) { error = new Error('CANCELLED') }
        if (error) { reject(error); return }
        if (!inputEnded) { reject(new Error('EARLY_END')); return }
        const result = transcript.result()
        resolve(result)
      }
      const timer = setTimeout(() => finish(new Error('RECOGNITION_TIMEOUT')),
        Math.ceil(bytes / PCM_BYTES_PER_SECOND * 6000) + 60000)
      const startTimer = setTimeout(() => finish(new Error('ENGINE_TIMEOUT')), 10000)
      this.rejectSession = (error: Error): void => finish(error)
      const feed = async (): Promise<void> => {
        if (feeding) { return }
        feeding = true
        clearTimeout(startTimer)
        try {
          while (sent < bytes && !settled) {
            this.ensureActive()
            const packet = new Uint8Array(PCM_PACKET_BYTES)
            const wanted = Math.min(PCM_PACKET_BYTES, bytes - sent)
            packet.set(pcm.subarray(sent, sent + wanted))
            if (settled) { return }
            engine.writeAudio(sessionId, packet)
            sent += wanted
            const next = transcriptionPercent(sent, bytes)
            if (next !== percent) {
              percent = next
              update({ phase: 'recognizing', percent, partial: transcript.preview() })
            }
            // The system API consumes 40 ms PCM packets, including zero padding on the final packet.
            await new Promise<void>((done) => { setTimeout(done, 40) })
          }
          if (!settled) {
            this.ensureActive()
            inputEnded = true
            engine.finish(sessionId)
          }
        } catch (error) { finish(error as Error) }
      }
      const listener: speechRecognizer.RecognitionListener = {
        onStart: (id: string): void => {
          if (id === sessionId && !settled) { this.feedingTask = feed() }
        },
        onEvent: (_sessionId: string, _code: number, _message: string): void => {},
        onResult: (id: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          if (id !== sessionId || settled || this.cancelled) { return }
          try {
            const partial = transcript.add(result.result, result.isFinal, result.isLast)
            update({ phase: 'recognizing', percent: transcriptionPercent(sent, bytes), partial })
            // Wait for onComplete before reusing the engine for a new, uniquely identified segment.
          } catch (error) { finish(error as Error) }
        },
        onComplete: (id: string): void => { if (id === sessionId) { finish() } },
        onError: (id: string, code: number): void => {
          if (id === sessionId) {
            hilog.warn(0x0000, 'AudioTranscription', 'Offline recognition failed: %{public}d session=%{public}s sent=%{public}d/%{public}d ended=%{public}s',
              code, sessionId, sent, bytes, inputEnded.toString())
            finish(new Error(code === 1002200006 ? 'ENGINE_BUSY' : 'RECOGNITION_FAILED'))
          }
        }
      }
      try {
        engine.setListener(listener)
        engine.startListening({
          sessionId,
          audioInfo: { audioType: 'pcm', sampleRate: 16000, soundChannel: 1, sampleBit: 16 },
          extraParams: recognitionStreamOptions()
        })
      } catch (_) { finish(new Error('RECOGNITION_FAILED')) }
    })
  }
}
