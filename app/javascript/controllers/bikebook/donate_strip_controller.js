import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global document */

// Read by Pages::Bikebook::DonateStrip::Component#render?
const COOKIE_NAME = 'bikebook_donate_dismissed'
const MAX_AGE_SECONDS = 60 * 60 * 24 * 30

// Connects to data-controller='bikebook--donate-strip'
export default class extends Controller {
  dismiss () {
    document.cookie = `${COOKIE_NAME}=1; path=/bikebook; max-age=${MAX_AGE_SECONDS}; samesite=lax`
    collapse('hide', this.element)
  }
}
