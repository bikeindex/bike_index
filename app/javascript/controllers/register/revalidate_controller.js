import { Controller } from '@hotwired/stimulus'

/* global window */

// Connects to data-controller='register--revalidate'
// The step shown depends on server state, so a back/forward restore must
// re-fetch - the controller sends Cache-Control: no-store, but Safari's
// bfcache restores pages regardless, so reload on a persisted pageshow.
export default class extends Controller {
  connect () {
    this.onPageshow = (event) => {
      if (event.persisted) window.location.reload()
    }
    window.addEventListener('pageshow', this.onPageshow)
  }

  disconnect () {
    window.removeEventListener('pageshow', this.onPageshow)
  }
}
