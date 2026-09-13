import axios, { AxiosError, AxiosResponse } from '@ohos/axios'
import { describe, expect, it } from '@ohos/hypium'

interface AuthErrorResponse {
  success: boolean
  code: number
  message: string
}

const authClient = axios.create({
  baseURL: 'https://api-harmony-teach.itheima.net',
  timeout: 10000
})

export default function authServerTest() {
  describe('AuthServerIntegrationTest', () => {
    it('rejectsMalformedTokenWith401', 0, () => {
      return authClient<null, AxiosResponse<AuthErrorResponse>, null>({
        url: '/hm/userInfo',
        headers: {
          Authorization: 'Bearer invalid-token-for-live-integration-test'
        }
      }).then((response: AxiosResponse<AuthErrorResponse>): void => {
        expect(response.status).assertEqual(401)
      }, (error: AxiosError<AuthErrorResponse, null>): void => {
        expect(error.response?.status).assertEqual(401)
        expect(error.response?.data.code).assertEqual(401)
      })
    })
  })
}
