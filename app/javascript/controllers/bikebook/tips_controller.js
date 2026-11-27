import { Controller } from '@hotwired/stimulus'

// gone until the page loads again, through the empty state's in-page re-renders
let dismissed = false

// Connects to data-controller='bikebook--tips'
// The empty page's tips, until they're dismissed
export default class extends Controller {
  static targets = ['tips']

  tipsTargetConnected (tips) {
    tips.hidden = dismissed
  }

  dismiss () {
    dismissed = true
    this.tipsTarget.hidden = true
  }

  // for the search, which opens its own list, and its filter panel
  browse () {
    this.dispatch('browse')
  }

  filters () {
    this.dispatch('filters')
  }
}
