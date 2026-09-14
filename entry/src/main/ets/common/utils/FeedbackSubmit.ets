import axios, { AxiosError, AxiosResponse } from '@ohos/axios'
import { feedbackEndpoint, feedbackInputError } from './AiScorePolicy'
import { validServiceAccessCode } from './ScoreSettingsPolicy'

interface FeedbackResponse { code: number; success: boolean; data: FeedbackReceipt; message: string }
interface FeedbackReceipt { id: string }
interface FeedbackBody { content: string }

export class FeedbackJob {
  private readonly endpoint: string
  private readonly allowLocal: boolean
  constructor(endpoint: string, allowLocal: boolean = false) {
    this.endpoint = endpoint
    this.allowLocal = allowLocal
  }

  async run(content: string, accessCode: string): Promise<string> {
    const url = feedbackEndpoint(this.endpoint, this.allowLocal)
    if (!url) { throw new Error('NOT_CONFIGURED') }
    if (feedbackInputError(content)) { throw new Error('INVALID_INPUT') }
    if (!validServiceAccessCode(accessCode)) { throw new Error('UNAUTHORIZED') }
    try {
      const response: AxiosResponse<FeedbackResponse> = await axios.post<FeedbackResponse, AxiosResponse<FeedbackResponse>, FeedbackBody>(
        url, { content: content.trim() }, {
          timeout: 15000,
          headers: { Authorization: `Bearer ${accessCode}`, 'Content-Type': 'application/json' },
          maxRedirects: 0
        })
      if (response.status !== 200 || response.data?.code !== 10000 || response.data.success !== true ||
        typeof response.data.data?.id !== 'string' || response.data.data.id.length === 0) {
        throw new Error('INVALID_RESPONSE')
      }
      return response.data.data.id
    } catch (error) {
      if ((error as Error).message === 'INVALID_RESPONSE') { throw new Error('INVALID_RESPONSE') }
      const status = (error as AxiosError).response?.status
      if (status === 401) { throw new Error('UNAUTHORIZED') }
      if (status === 429) { throw new Error('RATE_LIMITED') }
      throw new Error('REQUEST_FAILED')
    }
  }
}
