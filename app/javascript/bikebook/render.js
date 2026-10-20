import { render } from 'lit-html'

// A template's DOM, rendered apart from any container lit would then own
export const fragmentOf = (template) => {
  const fragment = document.createDocumentFragment()
  render(template, fragment)
  return fragment
}

export const renderInto = (element, template) => element.replaceChildren(fragmentOf(template))

/* global CSS */

// `content` with each [data-permanent] node `live` holds the same of, by id and value, moved in for its own - keeping
// what it's loaded and how it's shown, as Turbo's data-turbo-permanent does
export const keepPermanent = (content, live) => {
  for (const node of content.querySelectorAll('[data-permanent][id]')) {
    const kept = live.querySelector(`#${CSS.escape(node.id)}`)
    if (kept && kept !== node && kept.dataset.permanent === node.dataset.permanent) node.replaceWith(kept)
  }
  return content
}
