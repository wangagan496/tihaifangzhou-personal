export interface Tag {
  text: ResourceStr
  color: ResourceColor
}

@Component
export struct TgTag {
  text: string = ''
  difficulty: number = 1  // 源于服务器返回 1-2星是简单，3-4星是一般，5星是困难

  getTag(): Tag {
    if (this.difficulty === 3 || this.difficulty === 4) {
      return { text: '一般', color: $r('app.color.common_blue') }
    } else if (this.difficulty === 5) {
      return { text: '困难', color: $r('app.color.common_blue') }
    }
    return { text: this.text ? this.text : '简单', color: $r('app.color.common_green') }
  }

  build() {
    Text(this.getTag().text)
      .fontColor(this.getTag().color)
      .fontSize($r('app.float.common_font10'))
      .padding({ left: $r('app.float.common_space4'), right: $r('app.float.common_space4')})
      .constraintSize({ minWidth: $r('app.float.hd_tag_width') })
      .height($r('app.float.hd_tag_height'))
      .backgroundColor($r('app.color.common_gray_bg'))
      .borderRadius($r('app.float.hd_tag_radius'))
      .textAlign(TextAlign.Center)
  }
}