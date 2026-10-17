import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

const STORAGE_KEY = 'stolen-report-donation-strip-dismissed'

// Connects to data-controller='stolen-report--donation-strip'
// Dismissed for the rest of the session, across every page that shows it
export default class extends Controller {
  connect () {
    if (dismissed()) collapse('hide', this.element, 0)
  }

  dismiss () {
    try { window.sessionStorage.setItem(STORAGE_KEY, 'true') } catch {}
    collapse('hide', this.element)
  }
}

function dismissed () {
  try { return window.sessionStorage.getItem(STORAGE_KEY) === 'true' } catch { return false }
}
