import axios, { AbortController, AxiosError, AxiosResponse } from '@ohos/axios'
import { AiScoreInput, AiScoreResult, scoreInputError, validScoreResult, validScoringUrl } from './AiScorePolicy'
import { validServiceAccessCode } from './ScoreSettingsPolicy'

interface ScoreResponse { code: number; success: boolean; data: AiScoreResult }

export function scoringConfigured(endpoint: string, allowLocal: boolean = false): boolean {
  return validScoringUrl(endpoint, allowLocal)
}

export class AiScoringJob {
  private cancellation: AbortController = new AbortController()
  private readonly endpoint: string
  private readonly allowLocal: boolean
  constructor(endpoint: string, allowLocal: boolean = false) { this.endpoint = endpoint; this.allowLocal = allowLocal }

  cancel(): void { this.cancellation.abort() }

  async run(input: AiScoreInput, accessCode: string): Promise<AiScoreResult> {
    if (!scoringConfigured(this.endpoint, this.allowLocal)) { throw new Error('NOT_CONFIGURED') }
    if (scoreInputError(input)) { throw new Error('INVALID_INPUT') }
    if (!validServiceAccessCode(accessCode)) { throw new Error('UNAUTHORIZED') }
    try {
      const response: AxiosResponse<ScoreResponse> = await axios.post<ScoreResponse, AxiosResponse<ScoreResponse>, AiScoreInput>(this.endpoint, input, {
        timeout: 60000,
        signal: this.cancellation.signal,
        headers: { Authorization: `Bearer ${accessCode}`, 'Content-Type': 'application/json' },
        // Dedicated service access code only; classroom login tokens never enter this request.
        maxRedirects: 0
      })
      if (response.status !== 200 || response.data?.code !== 10000 || response.data.success !== true ||
        !validScoreResult(response.data.data)) { throw new Error('INVALID_RESPONSE') }
      return response.data.data
    } catch (error) {
      if (axios.isCancel(error)) { throw new Error('CANCELLED') }
      if ((error as Error).message === 'INVALID_RESPONSE') { throw new Error('INVALID_RESPONSE') }
      const status = (error as AxiosError).response?.status
      if (status === 401) { throw new Error('UNAUTHORIZED') }
      if (status === 429) { throw new Error('RATE_LIMITED') }
      if (status === 503) { throw new Error('SERVICE_NOT_READY') }
      if (status === 504) { throw new Error('TIMEOUT') }
      throw new Error('REQUEST_FAILED')
    }
  }
}
