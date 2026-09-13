export function readableText(html: string): string {
  return html.replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ').replace(/&lt;/gi, '<').replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"').replace(/&#39;|&apos;/gi, "'").replace(/&amp;/gi, '&')
    .replace(/\s+/g, ' ').trim()
}

export function speechChunks(text: string): string[] {
  const chunks: string[] = []
  let remaining = readableText(text)
  while (remaining.length > 0) {
    let end = Math.min(400, remaining.length)
    if (end < remaining.length) {
      const head = remaining.substring(0, end)
      const pause = Math.max(head.lastIndexOf('。'), head.lastIndexOf('！'), head.lastIndexOf('？'),
        head.lastIndexOf('；'), head.lastIndexOf('，'), head.lastIndexOf(' '))
      if (pause >= 200) { end = pause + 1 }
      const code = remaining.charCodeAt(end - 1)
      if (code >= 0xD800 && code <= 0xDBFF) { end-- }
    }
    chunks.push(remaining.substring(0, end))
    remaining = remaining.substring(end)
  }
  return chunks
}
