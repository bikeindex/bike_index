import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='lexxy'
// Lazily loads the Lexxy editor bundle only on pages that use it (it's large). Importing the
// module registers the <lexxy-editor> custom element, upgrading any already in the DOM.
export default class extends Controller {
  connect () {
    import('lexxy')
  }
}
