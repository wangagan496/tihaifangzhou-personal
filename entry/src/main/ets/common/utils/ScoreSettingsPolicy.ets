export function validServiceAccessCode(value: string): boolean {
  return /^[A-Za-z0-9_-]{32,256}$/.test(value)
}

export function scoreCredentialScope(owner: string, endpoint: string): string {
  if (!owner.trim() || !endpoint.trim()) { return '' }
  // Length-prefixing prevents collisions if an identifier contains delimiters.
  return `score-credential-v1:${owner.length}:${owner}:${endpoint.length}:${endpoint}`
}
