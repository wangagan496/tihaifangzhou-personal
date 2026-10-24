export const MAX_PENDING_AUDIO_CLEANUPS: number = 50

export function appendPendingCleanup(paths: string[], path: string): string[] {
  const normalized = path.trim()
  if (!normalized) { return paths.slice() }
  const next: string[] = []
  for (let i = 0; i < paths.length; i++) {
    const current = paths[i]
    if (current && current.trim() && current !== normalized) {
      next.push(current)
    }
  }
  next.push(normalized)
  return next.length > MAX_PENDING_AUDIO_CLEANUPS
    ? next.slice(next.length - MAX_PENDING_AUDIO_CLEANUPS)
    : next
}
