import { asset } from '@kit.AssetStoreKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { scoreCredentialScope, validServiceAccessCode } from './ScoreSettingsPolicy'
import { ScoreCredentialQueue } from './ScoreCredentialQueue'

// Page lifecycles cannot cancel native writes. Serialize across store instances so
// an older save cannot restore a credential after a later update or clear.
const credentialQueue = new ScoreCredentialQueue()

export type ScoreConnectionState = 'loading' | 'ready' | 'missing' | 'unavailable'
export interface ScoreCredential { state: ScoreConnectionState; accessCode: string }

export class ScoreCredentialStore {
  private async queryFor(owner: string, endpoint: string): Promise<asset.AssetMap> {
    const scope = scoreCredentialScope(owner, endpoint)
    if (!scope) { throw new Error('INVALID_SCOPE') }
    const md = cryptoFramework.createMd('SHA256')
    await md.update({ data: new util.TextEncoder().encodeInto(scope) })
    const digest = await md.digest()
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, digest.data)
    return query
  }

  async status(owner: string, endpoint: string): Promise<ScoreConnectionState> {
    if (!scoreCredentialScope(owner, endpoint)) { return 'missing' }
    return credentialQueue.run(scoreCredentialScope(owner, endpoint), () => this.statusDirect(owner, endpoint))
  }

  private async statusDirect(owner: string, endpoint: string): Promise<ScoreConnectionState> {
    try {
      const query = await this.queryFor(owner, endpoint)
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ATTRIBUTES)
      const result = await asset.query(query)
      return result.length > 0 ? 'ready' : 'missing'
    } catch (error) { return (error as BusinessError).code === asset.ErrorCode.NOT_FOUND ? 'missing' : 'unavailable' }
  }

  async read(owner: string, endpoint: string): Promise<ScoreCredential> {
    if (!scoreCredentialScope(owner, endpoint)) { return { state: 'missing', accessCode: '' } }
    return credentialQueue.run(scoreCredentialScope(owner, endpoint), () => this.readDirect(owner, endpoint))
  }

  private async readDirect(owner: string, endpoint: string): Promise<ScoreCredential> {
    try {
      const query = await this.queryFor(owner, endpoint)
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
      const result = await asset.query(query)
      if (!result.length) { return { state: 'missing', accessCode: '' } }
      const bytes = result[0].get(asset.Tag.SECRET) as Uint8Array
      const code = util.TextDecoder.create('utf-8').decodeToString(bytes)
      if (!validServiceAccessCode(code)) { return { state: 'unavailable', accessCode: '' } }
      return { state: 'ready', accessCode: code }
    } catch (error) {
      return { state: (error as BusinessError).code === asset.ErrorCode.NOT_FOUND ? 'missing' : 'unavailable', accessCode: '' }
    }
  }

  async save(owner: string, endpoint: string, accessCode: string): Promise<boolean> {
    if (!validServiceAccessCode(accessCode) || !scoreCredentialScope(owner, endpoint)) { return false }
    return credentialQueue.run(scoreCredentialScope(owner, endpoint), () => this.saveDirect(owner, endpoint, accessCode))
  }

  private async saveDirect(owner: string, endpoint: string, accessCode: string): Promise<boolean> {
    try {
      const attributes = await this.queryFor(owner, endpoint)
      attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(accessCode))
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED)
      attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
      attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER)
      await asset.add(attributes)
      const saved = await this.readDirect(owner, endpoint)
      return saved.state === 'ready' && saved.accessCode === accessCode
    } catch (_) { return false }
  }

  async clear(owner: string, endpoint: string): Promise<boolean> {
    if (!scoreCredentialScope(owner, endpoint)) { return false }
    return credentialQueue.run(scoreCredentialScope(owner, endpoint), () => this.clearDirect(owner, endpoint))
  }

  private async clearDirect(owner: string, endpoint: string): Promise<boolean> {
    try { await asset.remove(await this.queryFor(owner, endpoint)) }
    catch (error) { if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) { return false } }
    return await this.statusDirect(owner, endpoint) === 'missing'
  }
}

export const scoreCredentialStore = new ScoreCredentialStore()
