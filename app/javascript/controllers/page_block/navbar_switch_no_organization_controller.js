import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="page-block--navbar-switch-no-organization"
//
// The account menu's row for leaving the organization behind. Inside the organization
// interface there's nowhere to stay, so it keeps the homepage it was rendered pointing at;
// anywhere else it holds the reader on the page they're on and only drops the organization.
// Which page that is, is the browser's to know -- UserServices::MenuItemsAccount builds the
// row from routes alone, with no request to ask.
export default class extends Controller {
  connect () {
    if (this.organizationView) return

    const url = new URL(window.location.href)
    url.searchParams.set('organization_id', 'false')
    this.element.href = url.toString()
  }

  // ApplicationHelper#body_tag renders the route the server resolved
  get organizationView () {
    return (document.body.dataset.pageRoute || '').startsWith('organized/')
  }
}
