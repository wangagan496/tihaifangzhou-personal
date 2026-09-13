export interface QuestionDetail {
  id: string
  questionNo?: string
  stem: string
  difficulty: number
  likeCount: number
  views: number
  readFlag: 0 | 1
  answer?: string
  content?: string
  collectFlag: 0 | 1
  likeFlag: 0 | 1
  stage?: Array<string>
  creatorName?: string
  creatorAvatar?: string
  createdAt?: string
}
