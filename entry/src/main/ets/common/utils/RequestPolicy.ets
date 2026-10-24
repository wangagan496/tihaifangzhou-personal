export interface RequestErrorEffects {
  showToast: boolean
  expireSession: boolean
}

export interface BackgroundRequestConfig {
  silent?: boolean
}

export function isBackgroundRequest(config: BackgroundRequestConfig | undefined): boolean {
  return config?.silent === true
}

export function shouldShowBusinessErrorToast(silent: boolean): boolean {
  return !silent
}

export function requestErrorEffects(silent: boolean, unauthorized: boolean): RequestErrorEffects {
  return {
    showToast: !silent,
    expireSession: !silent && unauthorized
  }
}
