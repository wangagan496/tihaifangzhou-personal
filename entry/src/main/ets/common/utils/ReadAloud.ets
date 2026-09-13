import { textToSpeech } from '@kit.CoreSpeechKit'
import { speechChunks } from './ReadAloudPolicy'

export type ReadingPhase = 'idle' | 'preparing' | 'speaking' | 'error'

class ReadAloud {
  private generation: number = 0
  private engine?: textToSpeech.TextToSpeechEngine
  private rejectPending?: (error: Error) => void
  private update?: (phase: ReadingPhase, message: string) => void

  stop(): void {
    ++this.generation
    const update = this.update
    this.update = undefined
    this.rejectPending?.(new Error('CANCELLED'))
    this.rejectPending = undefined
    const engine = this.engine
    this.engine = undefined
    // Invalidate callbacks before stop: the platform can send onComplete before onStop.
    try { engine?.stop() } catch (_) {}
    try { engine?.shutdown() } catch (_) {}
    update?.('idle', '')
  }

  async start(text: string, update: (phase: ReadingPhase, message: string) => void): Promise<void> {
    this.stop()
    const generation = this.generation
    this.update = update
    const chunks = speechChunks(text)
    if (!chunks.length) { this.update = undefined; update('error', '没有可朗读的文字'); return }
    update('preparing', '正在准备离线朗读…')
    try {
      if (!canIUse('SystemCapability.AI.TextToSpeech')) { throw new Error('UNAVAILABLE') }
      const engine = await this.createEngine(generation)
      if (generation !== this.generation) {
        try { engine.shutdown() } catch (_) {}
        return
      }
      this.engine = engine
      for (let index = 0; index < chunks.length; index++) {
        if (generation !== this.generation) { return }
        await this.speak(engine, chunks[index], `read_${generation}_${Date.now()}_${index}`, generation)
      }
      if (generation === this.generation) { this.stop() }
    } catch (_) {
      if (generation !== this.generation) { return }
      this.stop()
      update('error', '离线朗读暂不可用，请检查设备语音服务后重试')
    }
  }

  private createEngine(generation: number): Promise<textToSpeech.TextToSpeechEngine> {
    return new Promise((resolve, reject) => {
      let settled = false
      const fail = (error: Error): void => {
        if (settled) { return }
        settled = true; clearTimeout(timer); this.rejectPending = undefined; reject(error)
      }
      const timer = setTimeout(() => fail(new Error('TIMEOUT')), 20000)
      this.rejectPending = fail
      try {
        textToSpeech.createEngine({ language: 'zh-CN', person: 0, online: 1 }).then((engine) => {
          if (settled || generation !== this.generation) {
            try { engine.shutdown() } catch (_) {}
            fail(new Error('CANCELLED')); return
          }
          settled = true; clearTimeout(timer); this.rejectPending = undefined; resolve(engine)
        }, () => fail(new Error('UNAVAILABLE')))
      } catch (_) { fail(new Error('UNAVAILABLE')) }
    })
  }

  private speak(engine: textToSpeech.TextToSpeechEngine, text: string, id: string,
    generation: number): Promise<void> {
    return new Promise((resolve, reject) => {
      let settled = false
      const finish = (error?: Error): void => {
        if (settled) { return }
        settled = true; clearTimeout(timer); this.rejectPending = undefined
        if (error) { reject(error) } else { resolve() }
      }
      const timer = setTimeout(() => finish(new Error('TIMEOUT')), 180000)
      this.rejectPending = (error: Error): void => finish(error)
      const current = (requestId: string): boolean => !settled && requestId === id && generation === this.generation
      try {
        engine.setListener({
          onStart: (requestId, response) => { if (current(requestId)) { this.update?.('speaking', '正在朗读') } },
          onComplete: (requestId, response) => { if (current(requestId) && response.type === 1) { finish() } },
          onStop: (requestId, response) => { if (current(requestId)) { finish(new Error('STOPPED')) } },
          onError: (requestId, code, message) => { if (current(requestId)) { finish(new Error('SPEECH_FAILED')) } }
        })
        engine.speak(text, { requestId: id })
      } catch (_) { finish(new Error('SPEECH_FAILED')) }
    })
  }
}

export const readAloud = new ReadAloud()
