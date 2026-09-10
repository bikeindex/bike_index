import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--json-display'
export default class extends Controller {
  // import() rather than a static import: this controller is preloaded on every page
  // (importmap-rails preloads pin_all_from), and a preload fetches the whole dependency
  // graph -- so a static import would pull highlight.js onto pages with no JSON on them.
  async connect () {
    const [hljs, json] = await Promise.all([
      import('highlight.js/lib/core'),
      import('highlight.js/lib/languages/json')
    ])

    hljs.default.registerLanguage('json', json.default)
    hljs.default.highlightElement(this.element.querySelector('pre code'))
  }
}
