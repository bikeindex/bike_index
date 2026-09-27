import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='recovery-stories--stories'
export default class extends Controller {
  // application.js localizes times on load, which a load more's frame render isn't
  localize () {
    window.timeLocalizer?.localize()
  }
}
