@Component
export default struct Interview {
  @StorageProp('topHeight') topHeight: number = 0;

  build() {
    Column() {
      Text("Interview");
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Yellow)
    .padding({ top: this.topHeight })
  }
}