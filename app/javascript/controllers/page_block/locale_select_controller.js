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
    // The locale the page already renders in without a param -- a preference or the browser's
    // language, not necessarily the default one, so the server hands it down on the body
    if (locale === document.body.dataset.implicitLocale) {
      url.searchParams.delete('locale')
    } else {
      url.searchParams.set('locale', locale)
    }
    window.location.href = url.pathname + url.search
  }
}
