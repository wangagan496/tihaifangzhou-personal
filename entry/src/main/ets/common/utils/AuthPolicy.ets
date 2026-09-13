export interface AuthBackParams {
  backUrl: string
  backParams: Object | undefined
}

export function hasLoginToken(token: string | undefined): boolean {
  return token !== undefined && token.length > 0
}

export function isUnauthorizedStatus(status: number | string | undefined): boolean {
  return Number(status) === 401
}

export function shouldAttachAuth(url: string | undefined): boolean {
  if (!url) {
    return true
  }
  const path = url.split('?')[0]
  return !(
    path.endsWith('/hm/login') ||
    path.endsWith('/hm/question/type') ||
    path.endsWith('/hm/question/list')
  )
}

export function buildAuthBackParams(url: string, params: Object | undefined): AuthBackParams {
  return {
    backUrl: url,
    backParams: params
  }
}
