import { describe, expect, it } from '@ohos/hypium'
import { isBackgroundRequest, requestErrorEffects, shouldShowBusinessErrorToast } from '../main/ets/common/utils/RequestPolicy'

export default function requestPolicyTest() {
  describe('RequestPolicyTest', () => {
    it('identifiesBackgroundBusinessErrorsAsSilent', 0, () => {
      expect(isBackgroundRequest({ silent: true })).assertEqual(true)
      expect(isBackgroundRequest({ silent: false })).assertEqual(false)
      expect(isBackgroundRequest(undefined)).assertEqual(false)
      expect(shouldShowBusinessErrorToast(true)).assertEqual(false)
    })

    it('silencesBackgroundNetworkAndUnauthorizedSideEffects', 0, () => {
      const networkFailure = requestErrorEffects(true, false)
      const unauthorized = requestErrorEffects(true, true)

      expect(networkFailure.showToast).assertEqual(false)
      expect(networkFailure.expireSession).assertEqual(false)
      expect(unauthorized.showToast).assertEqual(false)
      expect(unauthorized.expireSession).assertEqual(false)
    })

    it('preservesVisibleRequestEffects', 0, () => {
      const networkFailure = requestErrorEffects(false, false)
      const unauthorized = requestErrorEffects(false, true)

      expect(shouldShowBusinessErrorToast(false)).assertEqual(true)
      expect(networkFailure.showToast).assertEqual(true)
      expect(networkFailure.expireSession).assertEqual(false)
      expect(unauthorized.showToast).assertEqual(true)
      expect(unauthorized.expireSession).assertEqual(true)
    })
  })
}
