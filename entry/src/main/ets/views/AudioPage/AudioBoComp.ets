@Component
export struct AudioBoComp {
  @Prop @Watch('onChange') maxAmplitude: number
  @Prop active: boolean = false
  @State per: number = 0
  private readonly barScales: number[] = [0.35, 0.55, 0.8, 0.5, 0.95, 0.65, 0.4, 0.75, 0.55, 0.9, 0.45, 0.7, 0.5, 0.85, 0.6, 0.4, 0.8, 0.55, 0.9, 0.45, 0.7, 0.5, 0.85, 0.6, 0.4, 0.75, 0.55, 0.9, 0.5, 0.7]
  // 动画效果
  onChange() {
    this.getUIContext().animateTo({ duration: 100 }, () => {
      if (this.maxAmplitude < 20) {
        this.per = 0
      } else if (this.maxAmplitude > 20000) {
        this.per = 1
      } else {
        this.per = (this.maxAmplitude - 20) / 19980
      }
    })
  }

  build() {
    Row({ space: 5 }) {
      ForEach(this.barScales, (scale: number) => {
        Column()
          .layoutWeight(1)
          .height(this.active ? Math.max(6, this.per * 76 * scale) : 6)
          .borderRadius(3)
          .backgroundColor(this.active ? $r('app.color.common_blue') : '#D8E1EA')
      })
    }
    .width('100%')
    .height(76)
    .alignItems(VerticalAlign.Center)
  }
}
