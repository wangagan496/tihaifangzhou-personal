import { AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL } from 'BuildProfile'
import { auth } from '../common/utils/Auth'
import { ILoginDta } from '../models/AccountModel'
import { scoringConfigured } from '../common/utils/AiScoring'
import { scoreCredentialStore, ScoreConnectionState } from '../common/utils/ScoreCredentialStore'
import { validServiceAccessCode } from '../common/utils/ScoreSettingsPolicy'

@Entry
@Component
struct ScoreSettingsPage {
  @StorageProp('topHeight') topHeight: number = 0
  @StorageProp('user') @Watch('accountChanged') user: ILoginDta = {} as ILoginDta
  @State state: ScoreConnectionState = 'loading'
  @State newCode: string = ''
  @State busy: boolean = false
  @State message: string = ''
  private owner: string = ''
  private generation: number = 0
  private active: boolean = false

  aboutToAppear(): void { this.active = true; this.owner = auth.getUser()?.id || '' }
  onPageShow(): void { this.load() }
  onPageHide(): void { this.newCode = ''; this.generation++; this.busy = false }
  aboutToDisappear(): void { this.active = false; this.newCode = ''; this.generation++ }

  private current(generation: number): boolean {
    return this.active && generation === this.generation && this.owner === (auth.getUser()?.id || '')
  }
  private accountChanged(): void {
    this.newCode = ''; this.message = ''; this.busy = false
    this.owner = auth.getUser()?.id || ''
    this.load()
  }
  private async load(): Promise<void> {
    const generation = ++this.generation
    this.state = 'loading'
    const state = await scoreCredentialStore.status(this.owner, AI_SCORING_URL)
    if (this.current(generation)) { this.state = state }
  }
  private async save(): Promise<void> {
    if (this.busy) { return }
    if (!auth.getUser()?.token || !this.owner) { this.message = '请先登录后再配置'; return }
    if (!scoringConfigured(AI_SCORING_URL, AI_SCORING_ALLOW_LOCAL)) { this.message = '当前版本尚未设置评分服务地址'; return }
    const code = this.newCode.trim()
    if (!validServiceAccessCode(code)) { this.message = '请输入有效的服务访问码（32–256 位字母、数字、下划线或连字符）'; return }
    const generation = ++this.generation
    this.busy = true; this.message = ''
    const saved = await scoreCredentialStore.save(this.owner, AI_SCORING_URL, code)
    if (!this.current(generation)) { return }
    this.busy = false
    if (saved) {
      this.newCode = ''; this.state = 'ready'; this.message = '已安全保存，下次评分将自动使用。尚未验证远端服务是否可用'
    } else { this.message = '保存未成功，请解锁设备后重试'; this.load() }
  }
  private async clear(): Promise<void> {
    if (this.busy || !this.owner) { return }
    const generation = ++this.generation
    this.busy = true
    try {
      const choice = await this.getUIContext().getPromptAction().showDialog({ title: '清除评分连接配置？',
        message: '下次评分前需要重新配置。不会删除题目、录音或文字稿。',
        buttons: [{ text: '取消', color: '#64748B' }, { text: '清除配置', color: '#D94838' }] })
      if (!this.current(generation) || choice.index !== 1) { return }
      const cleared = await scoreCredentialStore.clear(this.owner, AI_SCORING_URL)
      if (!this.current(generation)) { return }
      this.newCode = ''
      if (cleared) { this.state = 'missing'; this.message = '连接配置已清除' }
      else { this.message = '清除未成功，请稍后重试' }
    } catch (_) { if (this.current(generation)) { this.message = '操作未完成，请重试' } }
    finally { if (this.current(generation)) { this.busy = false } }
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: 20 }) {
          Text('一次配置，后续直接评分').fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
          Text('连接配置仅用于当前账号和当前服务，保存在此设备。不会同步到云端。')
            .fontSize(14).lineHeight(22).fontColor($r('app.color.common_gray_03'))
          Column({ space: 8 }) {
            Text('当前服务').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.black'))
            Text(AI_SCORING_URL || '当前版本尚未设置服务地址').fontSize(14).lineHeight(22)
              .wordBreak(WordBreak.BREAK_ALL).fontColor($r('app.color.common_gray_03'))
          }.width('100%').alignItems(HorizontalAlign.Start)
          Divider()
          Text(this.state === 'loading' ? '正在读取配置…' : this.state === 'ready' ? '连接配置已保存' :
            this.state === 'missing' ? '尚未配置' : '暂时无法读取安全存储，请解锁设备后重试')
            .id('scoreSettingsState').fontSize(16).fontColor($r('app.color.black'))
          Text(this.state === 'ready' ? '更新服务访问码' : '服务访问码')
            .fontSize(16).fontColor($r('app.color.black'))
          TextInput({ text: this.newCode, placeholder: this.state === 'ready' ? '已保存；需要更换时输入新值' : '输入你的评分服务访问码' })
            .id('scoreSettingsAccessCode').type(InputType.Password).height(48).enabled(!this.busy)
            .accessibilityText('评分服务访问码').onChange((value) => { this.newCode = value; this.message = '' })
          Text('填写后端配置中的 API_ACCESS_TOKEN，不要填写百炼 API Key。已保存的访问码不会在这里显示。')
            .fontSize(13).lineHeight(21).fontColor($r('app.color.common_gray_03'))
          if (this.message) {
            Text(this.message).id('scoreSettingsMessage').fontSize(14).lineHeight(22).fontColor($r('app.color.common_gray_03'))
          }
          Button(this.busy ? '处理中…' : '保存配置').id('saveScoreSettings').width('100%').height(48)
            .enabled(!this.busy && this.state !== 'loading' && this.newCode.trim().length > 0)
            .onClick(() => this.save())
          if (this.state === 'ready' || this.state === 'unavailable') {
            Button('清除连接配置').id('clearScoreSettings').width('100%').height(48)
              .backgroundColor(Color.Transparent).fontColor($r('app.color.common_gray_03'))
              .enabled(!this.busy).onClick(() => this.clear())
          }
        }.padding(20).width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%').align(Alignment.TopStart).backgroundColor($r('app.color.white'))
    }.title('评分服务配置').titleMode(NavigationTitleMode.Mini).mode(NavigationMode.Stack).padding({ top: this.topHeight })
  }
}
