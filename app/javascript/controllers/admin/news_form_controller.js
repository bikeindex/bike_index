import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--news-form'
//
// Replaces the initializeBlogInfoToggling the vendored admin bundle bound to #infoCheck:
// an info post is published at its most recent edit, so it has no publish date, author or
// canonical URL to set. The server renders the matching state, this only follows changes.
export default class extends Controller {
  static targets = ['infoKind', 'blogOnly', 'infoOnly']

  kindChanged () {
    const info = this.infoKindTarget.checked

    collapse(info ? 'hide' : 'show', this.blogOnlyTargets)
    collapse(info ? 'show' : 'hide', this.infoOnlyTargets)
  }
}
