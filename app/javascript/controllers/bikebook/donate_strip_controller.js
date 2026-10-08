import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global document */

const MAX_AGE_SECONDS = 60 * 60 * 24 * 30

// Connects to data-controller='bikebook--donate-strip'
export default class extends Controller {
  static values = { cookie: String }

  dismiss () {
    document.cookie = `${this.cookieValue}=1; path=/bikebook; max-age=${MAX_AGE_SECONDS}; samesite=lax`
    collapse('hide', this.element)
  }
}
