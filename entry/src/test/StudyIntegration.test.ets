import { describe, expect, it } from '@ohos/hypium'
import { readableText, speechChunks } from '../main/ets/common/utils/ReadAloudPolicy'
import { AiScoreInput, AiScoreResult, scoreInputError, validScoreResult, validScoringUrl,
  feedbackEndpoint, feedbackInputError, recordsEndpoint } from '../main/ets/common/utils/AiScorePolicy'
import { studyCardRoute } from '../main/ets/common/utils/StudyCardPolicy'

export default function studyIntegrationTest() {
  describe('StudyIntegrationTest', () => {
    it('removesMarkupAndScriptsBeforeSpeech', 0, () => {
      expect(readableText('<style>hidden</style><p>你好&nbsp;鸿蒙</p><script>x()</script>&amp;'))
        .assertEqual('你好 鸿蒙 &')
      expect(speechChunks('<p> </p>').length).assertEqual(0)
    })
    it('segmentsLongAnswersWithoutLosingTextOrSplittingSurrogatePairs', 0, () => {
      const source = `${'文'.repeat(399)}😀${'答案。'.repeat(600)}`
      const chunks = speechChunks(source)
      expect(chunks.join('')).assertEqual(source)
      expect(chunks.every((chunk: string) => chunk.length > 0 && chunk.length <= 400)).assertTrue()
      expect(chunks[0].length).assertEqual(399)
    })
    it('rejectsEmptyAndOversizedScoringInput', 0, () => {
      const input: AiScoreInput = { question: '题目', answer: '回答', referenceAnswer: '' }
      expect(scoreInputError(input)).assertEqual('')
      input.answer = '  '
      expect(scoreInputError(input).length > 0).assertTrue()
      input.answer = '字'.repeat(20001)
      expect(scoreInputError(input).length > 0).assertTrue()
      input.answer = '回答'; input.question = ''
      expect(scoreInputError(input).length > 0).assertTrue()
    })
    it('derivesFeedbackEndpointOnlyFromTrustedScoringUrls', 0, () => {
      expect(feedbackEndpoint('https://scores.example.com/v1/scores')).assertEqual('https://scores.example.com/v1/feedback')
      expect(recordsEndpoint('https://scores.example.com/v1/scores')).assertEqual('https://scores.example.com/v1/records')
      expect(recordsEndpoint('http://127.0.0.1:3000/v1/scores', true)).assertEqual('http://127.0.0.1:3000/v1/records')
      expect(recordsEndpoint('http://127.0.0.1:3000/v1/scores')).assertEqual('')
      expect(feedbackEndpoint('http://127.0.0.1:3000/v1/scores', true)).assertEqual('http://127.0.0.1:3000/v1/feedback')
      expect(feedbackEndpoint('http://127.0.0.1:3000/v1/scores')).assertEqual('')
      expect(feedbackEndpoint('https://scores.example.com/v1/other')).assertEqual('')
      expect(feedbackInputError('  ')).assertEqual('请先填写反馈内容')
      expect(feedbackInputError('字'.repeat(4001)).includes('4000')).assertTrue()
      expect(feedbackInputError('页面返回后列表没刷新')).assertEqual('')
    })
    it('restrictsScoringToHttpsOrExplicitLoopbackDebugEndpoints', 0, () => {
      expect(validScoringUrl('')).assertFalse()
      expect(validScoringUrl('https://scores.example.com/v1/scores')).assertTrue()
      expect(validScoringUrl('https://user:secret@scores.example.com/v1/scores')).assertFalse()
      expect(validScoringUrl('https://scores.example.com/v1/scores?key=secret')).assertFalse()
      expect(validScoringUrl('https://scores.example.com:99999/v1/scores')).assertFalse()
      expect(validScoringUrl('https://-invalid.example/v1/scores')).assertFalse()
      expect(validScoringUrl('http://127.0.0.1:3000/v1/scores')).assertFalse()
      expect(validScoringUrl('http://127.0.0.1:3000/v1/scores', true)).assertTrue()
      expect(validScoringUrl('http://192.168.1.5:3000/v1/scores', true)).assertFalse()
      expect(validScoringUrl('//scores.example.com/v1/scores')).assertFalse()
    })
    it('acceptsZeroScoreAndRejectsMalformedOrOutOfRangeResults', 0, () => {
      const result: AiScoreResult = { score: 0, summary: '需要补充回答', strengths: [], improvements: ['补充例子'] }
      expect(validScoreResult(result)).assertTrue()
      result.score = 101
      expect(validScoreResult(result)).assertFalse()
      result.score = Number.NaN
      expect(validScoreResult(result)).assertFalse()
      result.score = 90; result.summary = ' '
      expect(validScoreResult(result)).assertFalse()
      result.summary = '完整'; result.improvements = ['']
      expect(validScoreResult(result)).assertFalse()
      expect(validScoreResult(JSON.parse('{"score":90,"summary":"完整"}') as AiScoreResult)).assertFalse()
      expect(validScoreResult(JSON.parse('{"score":"90","summary":"完整","strengths":[],"improvements":[]}') as AiScoreResult)).assertFalse()
    })
    it('allowsOnlyKnownCardDestinations', 0, () => {
      expect(studyCardRoute('questions')).assertEqual('pages/Index')
      expect(studyCardRoute('favorites')).assertEqual('pages/MineQuestionsPage')
      expect(studyCardRoute('audio')).assertEqual('pages/AudioPage')
      expect(studyCardRoute('pages/AccountSettingsPage')).assertEqual('')
      expect(studyCardRoute('')).assertEqual('')
    })
  })
}
