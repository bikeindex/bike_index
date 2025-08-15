import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='search--result-view-select'
export default class extends Controller {
  connect () {
    console.log('app/javascript/controllers/search/result_view_select_controller.js - connected to:')
    console.log(this.element)
  }
}
