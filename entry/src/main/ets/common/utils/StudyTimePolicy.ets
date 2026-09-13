function normalizeIdentity(value: string | undefined): string {
  return value ? value.trim().toLowerCase() : ''
}

export function buildStudyTimeKeys(userId: string | undefined, username: string | undefined): string[] {
  const keys: string[] = []
  const normalizedUserId = normalizeIdentity(userId)
  const normalizedUsername = normalizeIdentity(username)
  if (normalizedUserId) {
    keys.push(`total:id:${normalizedUserId}`)
  }
  if (normalizedUsername) {
    keys.push(`total:username:${normalizedUsername}`)
  }
  return keys
}

export function normalizeStudyTime(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return 0
  }
  return Math.floor(value)
}

/** The API returns the accumulated duration in milliseconds; the app stores seconds. */
export function normalizeServerStudyTime(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return 0
  }
  return Math.floor(value / 1000)
}

/** Migrate totals written by the previous build, which persisted API milliseconds locally. */
export function normalizeStoredStudyTime(value: number | undefined): number {
  const normalized = normalizeStudyTime(value)
  if (normalized >= 1000000) {
    return Math.floor(normalized / 1000)
  }
  return normalized
}

export function resolveStudyTimeTotal(values: number[]): number {
  return values.reduce((total: number, value: number) => {
    return Math.max(total, normalizeStudyTime(value))
  }, 0)
}

export function addStudyTimeDuration(total: number, duration: number): number {
  return normalizeStudyTime(total) + normalizeStudyTime(duration)
}
