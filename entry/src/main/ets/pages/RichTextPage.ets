@Entry
@Component
struct RichTextPage {
  @State htmlContent: string = `
    <div style="padding: 20px;">
      <h1 style="color: #333; text-align: center;">鸿蒙开发面试指南</h1>

      <h2 style="color: #007DFF;">一、ArkTS基础</h2>
      <p>ArkTS是鸿蒙生态的应用开发语言，基于TypeScript扩展而来。</p>
      <ul>
        <li><strong>装饰器</strong>: @Component, @Entry, @State, @Prop等</li>
        <li><strong>状态管理</strong>: 组件内状态、跨组件状态、应用级状态</li>
        <li><strong>类型系统</strong>: 静态类型检查，更安全的代码</li>
      </ul>

      <h2 style="color: #007DFF;">二、UI开发</h2>
      <p>声明式UI开发范式，通过链式调用构建界面。</p>
      <ol>
        <li>布局容器：Column、Row、Stack、Flex</li>
        <li>基础组件：Text、Image、Button、TextInput</li>
        <li>列表组件：List、Grid、Swiper</li>
      </ol>

      <h2 style="color: #007DFF;">三、核心特性</h2>
      <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; width: 100%;">
        <tr style="background-color: #f0f0f0;">
          <th>特性</th>
          <th>说明</th>
          <th>难度</th>
        </tr>
        <tr>
          <td>生命周期</td>
          <td>aboutToAppear、aboutToDisappear</td>
          <td>⭐⭐</td>
        </tr>
        <tr>
          <td>自定义组件</td>
          <td>@Component装饰的struct</td>
          <td>⭐⭐⭐</td>
        </tr>
        <tr>
          <td>状态管理</td>
          <td>@State、@Link、@Provide等</td>
          <td>⭐⭐⭐⭐</td>
        </tr>
      </table>

      <h2 style="color: #007DFF;">四、示例代码</h2>
      <pre style="background-color: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto;"><code>@Entry
@Component
struct MyComponent {
  @State count: number = 0

  build() {
    Column() {
      Text('计数: ' + this.count)
      Button('点击')
        .onClick(() => {
          this.count++
        })
    }
  }
}</code></pre>

      <blockquote style="border-left: 4px solid #007DFF; padding-left: 15px; margin: 20px 0; color: #666;">
        <em>提示：掌握这些基础知识，就能开始鸿蒙应用开发了！</em>
      </blockquote>

      <p style="text-align: center; color: #999; margin-top: 30px;">
        <a href="#" style="color: #007DFF; text-decoration: none;">查看更多面试题 →</a>
      </p>
    </div>
  `;

  build() {
    Column() {
      Scroll() {
        RichText(this.htmlContent)
          .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#fafafa')
  }
}
