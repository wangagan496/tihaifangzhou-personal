@Component
export struct AudioBoComp {
  @Prop @Watch('onChange') maxAmplitude: number
  @State per: number = 0
  // 动画效果
  onChange() {
    this.getUIContext().animateTo({ duration: 100 }, () => {
      if (this.maxAmplitude < 500) {
        this.per = 0
      } else if (this.maxAmplitude > 30000) {
        this.per = 1
      } else {
        this.per = this.maxAmplitude / 30000
      }
    })
  }

  build() {
    Row({ space: 5 }) {
      // 30个小条
      ForEach(Array.from({ length: 30 }), () => {
        Column()
          .layoutWeight(1)
          // 百分比*100*随机数
          .height(this.per * 100 * Math.random())
          .backgroundColor($r('app.color.common_blue'))
      })
    }
    .width('100%')
    .height(100)
  }
}