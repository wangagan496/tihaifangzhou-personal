import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0000
const TAG: string = 'mylog'
const FORMAT: string = '%{public}s'

export class Logger {
  // debug info warn error
  static debug(...args: string[]) {
    hilog.debug(DOMAIN, TAG, FORMAT, ...args)
  }

  static info(...args: string[]) {
    hilog.info(DOMAIN, TAG, FORMAT, ...args)
  }

  static warn(...args: string[]) {
    hilog.warn(DOMAIN, TAG, FORMAT, ...args)
  }

  static error(...args: string[]) {
    hilog.error(DOMAIN, TAG, FORMAT, ...args)
  }
}
