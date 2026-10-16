import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global document */

// Shared with Pages::Search::MarketplaceIntro::Component::COOKIE_NAME, which reads it
const COOKIE_NAME = 'marketplace_intro_dismissed'
const COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365

// Connects to data-controller='search--marketplace-intro'
export default class extends Controller {
  static targets = ['expanded', 'collapsed', 'heading', 'showButton']

  hide () {
    this.persist(`true; max-age=${COOKIE_MAX_AGE_SECONDS}`)
    this.swap(this.expandedTarget, this.collapsedTarget)
    // The clicked button is gone, so focus would otherwise fall back to the page
    this.showButtonTarget.focus()
  }

  show () {
    this.persist('; max-age=0')
    this.swap(this.collapsedTarget, this.expandedTarget)
    this.headingTarget.focus()
  }

  // A search moves focus nowhere, and leaves the cookie alone - it isn't a dismissal
  collapse () {
    if (!this.expandedTarget.checkVisibility()) return

    this.swap(this.expandedTarget, this.collapsedTarget)
  }

  persist (value) {
    document.cookie = `${COOKIE_NAME}=${value}; path=/; samesite=lax`
  }

  swap (from, to) {
    collapse('hide', from)
    collapse('show', to)
  }
}
