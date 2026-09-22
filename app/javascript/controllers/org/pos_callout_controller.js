import { Controller } from '@hotwired/stimulus'

/* global document */

// Cookie name is shared with the read side in
// SharedBlocks::MainContent::Organized::Component#dismissed_pos_callout_organization_ids
const COOKIE_NAME = 'dismissed_pos_callout_organization_ids'
const COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365

// Connects to data-controller='org--pos-callout'
export default class extends Controller {
  static values = { organizationId: Number }

  close () {
    this.hide()
  }

  dismissForever () {
    this.persist()
    this.hide()
  }

  hide () {
    this.element.classList.add('tw:hidden')
  }

  persist () {
    const ids = new Set(this.storedIds)
    ids.add(String(this.organizationIdValue))
    document.cookie = `${COOKIE_NAME}=${[...ids].join(',')}; path=/; max-age=${COOKIE_MAX_AGE_SECONDS}; samesite=lax`
  }

  get storedIds () {
    const match = document.cookie.match(new RegExp(`(?:^|; )${COOKIE_NAME}=([^;]*)`))
    return match ? decodeURIComponent(match[1]).split(',').filter(Boolean) : []
  }
}
