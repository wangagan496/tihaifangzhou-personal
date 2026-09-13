export function studyCardRoute(action: string): string {
  switch (action) {
    case 'questions': return 'pages/Index'
    case 'favorites': return 'pages/MineQuestionsPage'
    case 'audio': return 'pages/AudioPage'
    default: return ''
  }
}
