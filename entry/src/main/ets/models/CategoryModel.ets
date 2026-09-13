export interface IQuestionTypeTag {
  tagName: string
  nameColor?: string
  borderColor?: string
}

export interface IQuestionType {
  id: number // 分类的id
  name: string // 分类的名称
  icon?: string
  describeInfo?: string
  tags?: IQuestionTypeTag[]
  displayNewestFlag: 0 | 1 //  1：表示一个新分类
}
