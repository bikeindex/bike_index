import { Controller } from '@hotwired/stimulus'
import hljs from 'highlight.js/lib/core'
import json from 'highlight.js/lib/languages/json'

hljs.registerLanguage('json', json)

// Connects to data-controller='ui--json-display'
// Highlights the JSON the component rendered as plain text. Client-side so the tokens
// carry classes rather than the inline colors a server-side highlighter bakes in --
// that's what lets the theme in bike_index_components.css answer to dark mode.
export default class extends Controller {
  connect () {
    const code = this.element.querySelector('pre code')
    if (!code || code.dataset.highlighted) return

    hljs.highlightElement(code)
  }
}
