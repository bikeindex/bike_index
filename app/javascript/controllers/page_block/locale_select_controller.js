import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='page-block--locale-select'
// The footer is one cached fragment for every page, so the form carries no action and submits
// to whatever URL the browser is on. Rebuilding that URL here keeps the page's own params,
// which a GET submit would drop.
export default class extends Controller {
  submit (event) {
    event.preventDefault()
    const locale = event.currentTarget.querySelector('[name="locale"]').value
    const url = new URL(window.location.href)
    url.searchParams.set('locale', locale)
    window.location.href = url.pathname + url.search
  }
}
