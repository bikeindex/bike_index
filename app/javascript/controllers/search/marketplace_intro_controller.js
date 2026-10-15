import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global document */

// Shared with Pages::Search::MarketplaceIntro::Component::COOKIE_NAME, which reads it
const COOKIE_NAME = 'marketplace_intro_dismissed'
const COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365

// Connects to data-controller='search--marketplace-intro'
export default class extends Controller {
  static targets = ['expanded', 'collapsed']

  hide () {
    this.persist(`true; max-age=${COOKIE_MAX_AGE_SECONDS}`)
    this.swap(this.expandedTarget, this.collapsedTarget)
  }

  show () {
    this.persist('; max-age=0')
    this.swap(this.collapsedTarget, this.expandedTarget)
  }

  persist (value) {
    document.cookie = `${COOKIE_NAME}=${value}; path=/; samesite=lax`
  }

  swap (from, to) {
    collapse('hide', from)
    collapse('show', to)
  }
}
