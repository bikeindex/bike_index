import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--json-display'
// Highlights the JSON the component rendered as plain text. Client-side so the tokens
// carry classes rather than the inline colors a server-side highlighter bakes in --
// that's what lets the theme in json_display.css answer to dark mode.
export default class extends Controller {
  // import() rather than a static import: this controller is preloaded on every page
  // (importmap-rails preloads pin_all_from), and a preload fetches the whole dependency
  // graph -- so a static import would pull highlight.js onto pages with no JSON on them.
  async connect () {
    const code = this.element.querySelector('pre code')
    if (!code) return

    const hljs = await this.constructor.highlighter()
    if (!this.element.isConnected) return

    hljs.highlightElement(code)
  }

  static highlighter () {
    this.highlighterPromise ||= Promise.all([
      import('highlight.js/lib/core'),
      import('highlight.js/lib/languages/json')
    ]).then(([core, json]) => {
      core.default.registerLanguage('json', json.default)
      return core.default
    })

    return this.highlighterPromise
  }
}
