// Markup as lines a diff reads, with what legitimately differs between a component's render and
// its /bikebook template's made equal: comments, class order, random ids, and how Ruby and
// JSON.stringify print a whole float
/* global Node, NodeFilter */

window.canonicalHtml = (html) => {
  const template = document.createElement('template')
  template.innerHTML = html
  const ids = new Map()
  const lines = []
  const attribute = ({ name, value }) => {
    if (name === 'class') value = [...new Set(value.split(/\s+/).filter(Boolean))].sort().join(' ')
    // tooltip and option ids are random on both sides
    value = value.replace(/tooltip-[\da-f]{8}|[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}/g, (id) => {
      if (!ids.has(id)) ids.set(id, `id-${ids.size}`)
      return ids.get(id)
    })
    return `${name}="${value}"`
  }
  const walk = (node, depth) => {
    for (const child of node.childNodes) {
      const indent = '  '.repeat(depth)
      if (child.nodeType === Node.TEXT_NODE) {
        const text = child.textContent.replace(/\s+/g, ' ').trim()
        if (text) lines.push(`${indent}${text}`)
      } else if (child.nodeType === Node.ELEMENT_NODE) {
        lines.push(`${indent}<${child.localName} ${[...child.attributes].map(attribute).sort().join(' ')}>`)
        // Ruby writes a whole float as 135.0 where JSON.stringify writes 135
        if (child.matches('code.language-json')) lines.push(`${indent}  ${JSON.stringify(JSON.parse(child.textContent))}`)
        else walk(child.content ?? child, depth + 1)
      }
    }
  }
  // comments go, and the text they split joins up: lit-html marks where it inserts with them
  const comments = document.createTreeWalker(template.content, NodeFilter.SHOW_COMMENT)
  const marks = []
  while (comments.nextNode()) marks.push(comments.currentNode)
  marks.forEach((mark) => mark.remove())
  template.content.normalize()
  walk(template.content, 0)
  return lines.join('\n')
}
