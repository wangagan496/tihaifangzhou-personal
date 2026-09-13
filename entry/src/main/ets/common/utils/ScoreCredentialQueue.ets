export class ScoreCredentialQueue {
  private pending: Map<string, Promise<void>> = new Map()

  run<T>(scope: string, action: () => Promise<T>): Promise<T> {
    const previous = this.pending.get(scope) || Promise.resolve()
    const result = previous.then(action)
    const settled = result.then((): void => {}, (): void => {})
    this.pending.set(scope, settled)
    settled.then(() => {
      if (this.pending.get(scope) === settled) { this.pending.delete(scope) }
    })
    return result
  }
}
