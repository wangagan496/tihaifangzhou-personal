export interface AuthBackParams {
  backUrl: string
  backParams: Object | undefined
}

export function hasLoginToken(token: string | undefined): boolean {
  return token !== undefined && token.length > 0
}

export function isUnauthorizedStatus(status: number | undefined): boolean {
  return status === 401
}

export function buildAuthBackParams(url: string, params: Object | undefined): AuthBackParams {
  return {
    backUrl: url,
    backParams: params
  }
}
