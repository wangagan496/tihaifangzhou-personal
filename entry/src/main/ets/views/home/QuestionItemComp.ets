import { TgTag } from "./TgTag"
import { resolveInterviewIcon } from '../../common/utils/InterviewIcon'

export interface QuestionItem {
  id: string
  stem: string
  difficulty: number
  likeCount: number
  views: number
  readFlag: 0 | 1
  questionNo?: string
  content?: string
  subjectName?: string
  creatorName?: string
  creatorAvatar?: string
  createdAt?: string
}

export interface QuestionDetail {
  id: string
  stem: string
  difficulty: number
  likeCount: number
  views: number
  readFlag: 0 | 1
  answer: string
  collectFlag: 0 | 1
  likeFlag: 0 | 1
  stage: Array<string>
}

@Component
export struct QuestionItemComp {
  item: QuestionItem = {} as QuestionItem
  isInterview: boolean = false

  @Builder
  SplitBuilder() {
    Text('|')
      .width(30)
      .textAlign(TextAlign.Center)
      .fontColor('#C3C3C5')
      .fontSize(13)
  }

  @Builder
  TextBuilder(text: string) {
    Text(text)
      .fontColor('#C3C3C5')
      .fontSize(13)
  }

  build() {
    if (this.isInterview) {
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          Image(resolveInterviewIcon(this.item.stem, this.item.subjectName, this.item.creatorName))
            .width(34)
            .height(34)
            .aspectRatio(1)
            .objectFit(ImageFit.Contain)
            .backgroundColor('#EAF4FF')
            .borderRadius(17)
          Column({ space: 2 }) {
            Text(this.item.creatorName || '面经作者')
              .fontSize(13)
              .fontColor('#4C596A')
            Text(this.item.createdAt || this.item.subjectName || '面试经验')
              .fontSize(11)
              .fontColor('#9AA4B2')
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (this.item.readFlag === 1) {
            Text('已读')
              .fontSize(11)
              .fontColor('#2F9E66')
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor('#EAF8F0')
              .borderRadius(4)
          }
        }
        Text(this.item.stem)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#202A38')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row({ space: 16 }) {
          this.TextBuilder(`点赞 ${this.item.likeCount || 0}`)
          this.TextBuilder(`浏览 ${this.item.views || 0}`)
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor(Color.White)
      .borderRadius(8)
    } else {
      Column() {
        Row({ space: 5 }) {
          TgTag({ difficulty: this.item.difficulty })
          Text(this.item.stem)
            .fontSize(15)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .maxLines(1)
            .fontWeight(500)
        }.width('100%')

        Row() {
          this.TextBuilder(`点赞 ${this.item.likeCount || 0}`)
          this.SplitBuilder()
          this.TextBuilder(`浏览 ${this.item.views || 0}`)
          if (this.item.readFlag === 1) {
            this.SplitBuilder()
            this.TextBuilder('已看过')
          }
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .height(80)
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
  }
}
