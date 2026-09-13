import { auth } from './Auth'
import { contextManager } from './ContextManager'
import { studyCardRoute } from './StudyCardPolicy'

interface CardFavoritesParams { mode: string }

export function openPendingStudyCard(uiContext: UIContext): void {
  const action = AppStorage.get<string>('studyCardAction') || ''
  const route = studyCardRoute(action)
  const router = uiContext.getRouter()
  // loadContent's completion callback can run before the initial router page exists.
  // Index.onPageShow consumes the pending action once that page is actually ready.
  if (!route || !router.getState().name) { return }
  AppStorage.setOrCreate('studyCardAction', '')
  contextManager.UiCtx = uiContext
  if (action === 'questions') {
    if (router.getState().name === 'Index') { AppStorage.setOrCreate('homeTab', 0); return }
    router.replaceUrl({ url: route }).then(() => { router.clear(); AppStorage.setOrCreate('homeTab', 0) }, () => {})
  } else {
    const params: CardFavoritesParams = { mode: 'collect' }
    auth.checkAuth({ url: route, params: action === 'favorites' ? params : undefined })
  }
}
