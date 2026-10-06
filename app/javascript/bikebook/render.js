import { render } from 'lit-html'

// A template's DOM, rendered apart from any container lit would then own
export const fragmentOf = (template) => {
  const fragment = document.createDocumentFragment()
  render(template, fragment)
  return fragment
}

export const renderInto = (element, template) => element.replaceChildren(fragmentOf(template))
