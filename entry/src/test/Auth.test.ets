import { describe, expect, it } from '@ohos/hypium'
import { buildAuthBackParams, hasLoginToken, isUnauthorizedStatus } from '../main/ets/common/utils/AuthPolicy'

class QuestionParams {
  id: string = 'question-100'
}

export default function authTest() {
  describe('AuthPolicyTest', () => {
    it('rejectsMissingOrEmptyToken', 0, () => {
      expect(hasLoginToken(undefined)).assertEqual(false)
      expect(hasLoginToken('')).assertEqual(false)
    })

    it('acceptsNonEmptyToken', 0, () => {
      expect(hasLoginToken('token-value')).assertEqual(true)
    })

    it('preservesProtectedRouteForLoginReturn', 0, () => {
      const params = new QuestionParams()
      const result = buildAuthBackParams('pages/QuestionDetailPage', params)

      expect(result.backUrl).assertEqual('pages/QuestionDetailPage')
      expect(result.backParams).assertEqual(params)
    })

    it('recognizesOnly401AsExpiredLogin', 0, () => {
      expect(isUnauthorizedStatus(401)).assertEqual(true)
      expect(isUnauthorizedStatus(403)).assertEqual(false)
      expect(isUnauthorizedStatus(500)).assertEqual(false)
      expect(isUnauthorizedStatus(undefined)).assertEqual(false)
    })
  })
}
