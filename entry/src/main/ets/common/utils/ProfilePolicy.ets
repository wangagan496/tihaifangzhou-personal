import { ILoginDta } from '../../models/AccountModel'

export function mergeUserProfile(user: ILoginDta, avatar?: string, nickName?: string): ILoginDta {
  return {
    avatar: avatar === undefined ? user.avatar : avatar,
    clockinNumbers: user.clockinNumbers,
    id: user.id,
    nickName: nickName === undefined ? user.nickName : nickName,
    refreshToken: user.refreshToken,
    shareInfo: user.shareInfo,
    token: user.token,
    totalTime: user.totalTime,
    username: user.username
  }
}
