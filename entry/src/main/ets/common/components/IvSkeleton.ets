@Preview
@Component
export struct IvSkeleton {
  @State translageX: string = '-100%' // 定义闪电效果的位置
  widthValue: number = 28
  heightValue: number = 100
  bgColor: ResourceStr = 'rgba(0,0,0,0.5)'

  build() {
    Stack() {
      // 背景效果
      Text()
        .height(this.heightValue)
        .width(this.widthValue)
        .backgroundColor(this.bgColor)
        .borderRadius(5)
      // 闪电效果
      Text()
        .borderRadius(5)
        .height(this.heightValue)
        .width(this.widthValue)
        .translate({ x: this.translageX })// 控制闪电位置
        .onAppear(() => {
          // 当组件加载后，触发此函数，将translate的x轴位置改变到100%
          this.translageX = '100%'
        })
        .animation({
          duration: 1500, // 1.5秒内完成闪电动画
          iterations: -1  // 无限闪动动画
        })
        .linearGradient({
          // 闪电效果
          angle: 90,
          colors: [
            ['rgba(255,255,255,0)', 0],
            [$r('app.color.common_blue_bg'), 0.5],
            ['rgba(255,255,255,0)', 1]
          ]
        })

    }

  }
}