import { describe, expect, it } from '@ohos/hypium'
import { mergeUserProfile } from '../main/ets/common/utils/ProfilePolicy'
import { ILoginDta } from '../main/ets/models/AccountModel'

function user(): ILoginDta {
  return {
    avatar: 'old-avatar',
    clockinNumbers: 3,
    id: 'user-1',
    nickName: '旧昵称',
    refreshToken: 'refresh-token',
    shareInfo: 'share-info',
    token: 'token',
    totalTime: 120,
    username: 'demo'
  }
}

export default function profilePolicyTest() {
  describe('ProfilePolicyTest', () => {
    it('returnsANewUserWithUpdatedAvatar', 0, () => {
      const current = user()
      const updated = mergeUserProfile(current, 'new-avatar')
      expect(updated === current).assertEqual(false)
      expect(updated.avatar).assertEqual('new-avatar')
      expect(updated.token).assertEqual(current.token)
    })

    it('updatesNicknameWithoutDroppingAvatar', 0, () => {
      const updated = mergeUserProfile(user(), undefined, '新昵称')
      expect(updated.nickName).assertEqual('新昵称')
      expect(updated.avatar).assertEqual('old-avatar')
    })
  })
}
