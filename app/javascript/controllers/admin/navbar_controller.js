import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--navbar'
//
// The admin navbar's page picker has no form to submit - picking a page navigates to
// its path. The combobox also reports a selection when it closes untouched, which
// carries a blank value.
export default class extends Controller {
  navigate (event) {
    const path = event.detail.value
    if (path) window.location.href = path
  }
}
