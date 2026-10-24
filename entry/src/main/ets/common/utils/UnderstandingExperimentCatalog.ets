/**
 * A question-specific understanding experiment.
 *
 * Experiments are deliberately authored per concept. The page should not
 * pretend that one generic answer template can explain every question.
 */
export interface UnderstandingExperimentSpec {
  title: string
  scenario: string
  prompt: string
  hint: string
  passExplanation: string
}

export const listKeyExperiment: UnderstandingExperimentSpec = {
  title: '列表状态为什么需要稳定 key',
  scenario: '列表里 A 已经展开了。现在准备在顶部插入 X：你希望 A 继续展开，但程序怎么认出原来的 A？一起试一试。',
  prompt: '插入或排序后，原来展开的 A 应该跟着哪里？',
  hint: '下标表示位置，id 表示这一项是谁。插入和排序会改变哪一个？',
  passExplanation: '位置会变化，但 A 的身份没有变化。稳定的 id 让列表状态继续跟着 A。'
}

/**
 * Return an experiment only when the question content really matches it.
 * This keeps unrelated questions from receiving a misleading interaction.
 */
export function understandingExperimentFor(stem: string): UnderstandingExperimentSpec | undefined {
  const text = stem.toLowerCase()
  const mentionsList = /\bforeach\b/.test(text) || /\blist\b/.test(text) || text.includes('列表') ||
    text.includes('列表项')
  const mentionsKey = /\bkey\b/.test(text) || text.includes('标识') || text.includes('下标')
  return mentionsList && mentionsKey ? listKeyExperiment : undefined
}
