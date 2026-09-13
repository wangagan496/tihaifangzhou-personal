import axios, { AxiosError, AxiosRequestConfig, AxiosResponse, InternalAxiosRequestConfig } from '@ohos/axios'
import { contextManager } from './ContextManager'
import { auth } from './Auth'
import { isUnauthorizedStatus } from './AuthPolicy'


// 创建 axios 实例，配置基础请求地址
export const instance = axios.create({
  baseURL: 'https://api-harmony-teach.itheima.net',
  timeout: 10000
})

// 请求拦截器：在请求发送前统一处理
// 统一请求入口：在这里注入 Token，业务页面不重复拼 Authorization。
instance.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  // 从全局存储获取用户信息（包含 token）
  const user = auth.getUser()
  if (user?.token) {
    // 如果存在 token，添加到请求头用于身份验证
    config.headers.Authorization = `Bearer ${user?.token}`
  }
  return config
})

// 响应拦截器：统一处理响应数据
// 1、响应成功：区分业务成功和业务失败
// 2、响应失败：判断状态码 401，删除 token，跳转登录页面
// 统一响应出口：业务码失败继续 reject；401 清理登录态并替换到登录页。
instance.interceptors.response.use(
  // 响应成功回调
  (res: AxiosResponse) => {
    // 判断业务状态码：10000 表示业务成功
    if (res.data.code === 10000) {
      return res
    } else {
      // 业务失败，显示错误提示
      contextManager.getUiCtx()?.getPromptAction().showToast({
        message: res.data.message
      })
      return Promise.reject(res)
    }
  },
  // 响应失败回调（网络错误、服务器错误等）
  (err: AxiosError) => {
    // 401 状态码表示 token 过期或无效
    if (isUnauthorizedStatus(err.response?.status)) {
      // 清除本地存储的用户信息
      auth.removeUser()
      // 跳转到登录页面
      contextManager.getUiCtx()?.getRouter().replaceUrl({
        url: 'pages/LoginPage'
      })
      // 显示提示信息
      contextManager.getUiCtx()?.getPromptAction().showToast({
        message: '登录已过期，请重新登录'
      })
    } else {
      // 显示其他错误信息
      contextManager.getUiCtx()?.getPromptAction().showToast({
        message: err.message
      })
    }

    return Promise.reject(err)
  })


// 统一响应数据结构接口
export interface IRes<T> {
  /** 请求成功标志（10000 表示成功） */
  code: number;

  /** 返回的数据 */
  data: T;

  /** 响应消息 */
  message: string;

  /** 请求是否成功 */
  success: boolean;
}

// 封装的请求函数：简化 API 调用，自动处理类型和响应数据
// T: 响应数据的类型，D: 请求数据的类型
export async function tgRequest<T = null, D = null>(config: AxiosRequestConfig) {
  // 发送请求并获取响应
  const res: AxiosResponse<IRes<T>> = await instance<null, AxiosResponse<IRes<T>>, D>(config)
  // 直接返回业务数据部分（res.data.data）
  return res.data.data
}

// 优化建议：
// 1、windowMananger 简化，使用 contextManager 替代
// 2、request 函数直接 return 响应数据，去除外层包装
// 3、修改之前发过的请求：登录接口、打卡接口需适配新的返回格式
