import { describe, expect, it } from '@ohos/hypium'
import {
  buildAuthBackParams,
  hasLoginToken,
  isUnauthorizedStatus,
  shouldAttachAuth
} from '../main/ets/common/utils/AuthPolicy'

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
      expect(isUnauthorizedStatus('401')).assertEqual(true)
      expect(isUnauthorizedStatus(403)).assertEqual(false)
      expect(isUnauthorizedStatus(500)).assertEqual(false)
      expect(isUnauthorizedStatus(undefined)).assertEqual(false)
    })

    it('keepsPublicQuestionRequestsIndependentFromStoredToken', 0, () => {
      expect(shouldAttachAuth('/hm/login')).assertEqual(false)
      expect(shouldAttachAuth('/hm/question/type?type=items')).assertEqual(false)
      expect(shouldAttachAuth('/hm/question/list?page=1')).assertEqual(false)
      expect(shouldAttachAuth('/hm/question/41319')).assertEqual(true)
      expect(shouldAttachAuth('/hm/studyInfo')).assertEqual(true)
    })
  })
}
