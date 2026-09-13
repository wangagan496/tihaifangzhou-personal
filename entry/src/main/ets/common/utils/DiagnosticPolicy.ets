export interface DiagnosticRecord {
  name: string
  time: number
  pid: number
  foreground?: boolean
}

export const DIAGNOSTIC_HISTORY_LIMIT: number = 20

export function createDiagnosticRecord(name: string, time: number, pid: number,
  foreground?: boolean): DiagnosticRecord | undefined {
  const timestamp = Math.floor(time)
  if ((name !== 'APP_CRASH' && name !== 'APP_FREEZE') || !Number.isSafeInteger(timestamp) || timestamp <= 0) {
    return undefined
  }
  return {
    name,
    time: timestamp,
    pid: Number.isSafeInteger(pid) && pid >= 0 ? pid : 0,
    foreground
  }
}

export function mergeDiagnosticRecords(previous: DiagnosticRecord[], incoming: DiagnosticRecord[]): DiagnosticRecord[] {
  const records: Map<string, DiagnosticRecord> = new Map()
  for (const item of previous.concat(incoming)) {
    if (!item || typeof item !== 'object' || typeof item.name !== 'string' || typeof item.time !== 'number') {
      continue
    }
    // Rebuild a strict allowlist: never persist raw event params, stacks, paths or account data.
    const record = createDiagnosticRecord(item.name, item.time, item.pid,
      typeof item.foreground === 'boolean' ? item.foreground : undefined)
    if (record) {
      records.set(`${record.name}:${record.time}:${record.pid}`, record)
    }
  }
  return Array.from(records.values()).sort((left, right) => right.time - left.time).slice(0, DIAGNOSTIC_HISTORY_LIMIT)
}

export function readDiagnosticHistory(serialized: string): DiagnosticRecord[] {
  if (!serialized || serialized.length > 16384) {
    return []
  }
  try {
    const records = JSON.parse(serialized) as DiagnosticRecord[]
    return Array.isArray(records) ? mergeDiagnosticRecords([], records) : []
  } catch (_) {
    return []
  }
}
