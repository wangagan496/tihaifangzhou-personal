import axios, { AxiosResponse } from '@ohos/axios'
import { AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL } from 'BuildProfile'
import { recordsEndpoint } from './AiScorePolicy'
import { MineQuestionRecord } from './MineQuestionPolicy'
import { scoreCredentialStore } from './ScoreCredentialStore'
import { validServiceAccessCode } from './ScoreSettingsPolicy'

type RecordKind = 'history' | 'collect' | 'like'

interface RecordsResponse { code: number; success: boolean; data: MineQuestionRecord[] }
interface RecordKey { id: string; contentType: number }

class RecordsClient {
  async pull(kind: RecordKind, ownerId: string): Promise<MineQuestionRecord[] | undefined> {
    const session = await this.session(ownerId)
    if (!session) { return undefined }
    try {
      const response: AxiosResponse<RecordsResponse> = await axios.get<RecordsResponse, AxiosResponse<RecordsResponse>, null>(
        `${session.base}/${kind}`, {
          timeout: 15000,
          headers: { Authorization: `Bearer ${session.accessCode}`, 'X-Owner-Id': ownerId, 'Content-Type': 'application/json' },
          maxRedirects: 0
        })
      if (response.status !== 200 || response.data?.code !== 10000 || response.data.success !== true ||
        !Array.isArray(response.data.data)) { return undefined }
      return response.data.data
    } catch (_) {
      return undefined
    }
  }

  async put(kind: RecordKind, ownerId: string, item: MineQuestionRecord): Promise<void> {
    const session = await this.session(ownerId)
    if (!session) { return }
    try {
      await axios.put(`${session.base}/${kind}`, item, {
        timeout: 15000,
        headers: { Authorization: `Bearer ${session.accessCode}`, 'X-Owner-Id': ownerId, 'Content-Type': 'application/json' },
        maxRedirects: 0
      })
    } catch (_) {
      return
    }
  }

  async remove(kind: RecordKind, ownerId: string, item: MineQuestionRecord): Promise<void> {
    const session = await this.session(ownerId)
    if (!session) { return }
    try {
      const body: RecordKey = { id: item.id, contentType: item.contentType || 0 }
      await axios.delete(`${session.base}/${kind}`, {
        timeout: 15000,
        headers: { Authorization: `Bearer ${session.accessCode}`, 'X-Owner-Id': ownerId, 'Content-Type': 'application/json' },
        data: body,
        maxRedirects: 0
      })
    } catch (_) {
      return
    }
  }

  private async session(ownerId: string): Promise<RecordSession | undefined> {
    const base = recordsEndpoint(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)
    if (!base || !ownerId.trim()) { return undefined }
    const credential = await scoreCredentialStore.read(ownerId, AI_SCORING_URL)
    if (credential.state !== 'ready' || !validServiceAccessCode(credential.accessCode)) { return undefined }
    const session: RecordSession = { base, accessCode: credential.accessCode }
    return session
  }
}

interface RecordSession {
  base: string
  accessCode: string
}

export const recordsClient = new RecordsClient()
