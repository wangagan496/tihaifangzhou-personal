export interface AiScoreInput {
  question: string
  answer: string
  referenceAnswer: string
}

export interface AiScoreResult {
  score: number
  summary: string
  strengths: string[]
  improvements: string[]
}

export function scoreInputError(input: AiScoreInput): string {
  if (!input.question.trim()) { return '请填写面试题目' }
  if (!input.answer.trim()) { return '请填写或核对回答文字' }
  if (input.question.length > 2000 || input.answer.length > 20000 || input.referenceAnswer.length > 20000) {
    return '题目最多 2000 字，回答和参考答案各最多 20000 字，请精简后提交'
  }
  return ''
}

export function feedbackEndpoint(scoreUrl: string, allowLocal: boolean = false): string {
  if (!validScoringUrl(scoreUrl, allowLocal) || !scoreUrl.endsWith('/v1/scores')) { return '' }
  return `${scoreUrl.slice(0, scoreUrl.length - '/v1/scores'.length)}/v1/feedback`
}

export function recordsEndpoint(scoreUrl: string, allowLocal: boolean = false): string {
  if (!validScoringUrl(scoreUrl, allowLocal) || !scoreUrl.endsWith('/v1/scores')) { return '' }
  return `${scoreUrl.slice(0, scoreUrl.length - '/v1/scores'.length)}/v1/records`
}

export function feedbackInputError(content: string): string {
  const value = content.trim()
  if (!value) { return '请先填写反馈内容' }
  if (value.length > 4000) { return '反馈最多 4000 字，请精简后提交' }
  return ''
}

export function validScoringUrl(endpoint: string, allowLocal: boolean = false): boolean {
  // Fixed API path; forbid credentials, query strings, fragments and encoded host tricks.
  const match = /^(https):\/\/([A-Za-z0-9.-]+)(?::([0-9]{1,5}))?\/v1\/scores$/.exec(endpoint)
  if (match) {
    const host = match[2]
    const validHost = host.length <= 253 && host.split('.').every((label: string) =>
      label.length > 0 && label.length <= 63 && /^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(label))
    return validHost && (!match[3] || (Number(match[3]) >= 1 && Number(match[3]) <= 65535))
  }
  const local = /^http:\/\/127\.0\.0\.1:([0-9]{1,5})\/v1\/scores$/.exec(endpoint)
  return allowLocal && !!local && Number(local[1]) >= 1 && Number(local[1]) <= 65535
}

function validFeedback(items: string[]): boolean {
  if (!Array.isArray(items) || items.length > 10) { return false }
  return items.every((item: string) => typeof item === 'string' && item.trim().length > 0 && item.length <= 2000)
}

export function validScoreResult(value: AiScoreResult): boolean {
  return !!value && typeof value.score === 'number' && Number.isFinite(value.score) &&
    value.score >= 0 && value.score <= 100 && typeof value.summary === 'string' &&
    value.summary.trim().length > 0 && value.summary.length <= 4000 &&
    validFeedback(value.strengths) && validFeedback(value.improvements)
}
