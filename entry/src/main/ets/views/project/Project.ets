@Component
export default struct Project {
  @StorageProp('topHeight') topHeight: number = 0;

  build() {
    Column() {
      Text("Project");
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Yellow)
    .padding({ top: this.topHeight })

  }
}