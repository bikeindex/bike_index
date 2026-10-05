import { Controller } from '@hotwired/stimulus'
import { withCommas } from 'bikebook/replace_url'

// Lays the href's remaining models over the current URL as it's clicked, keeping URL state set
// since render. Not through the combobox's chip: chips load after the page, so an early click finds none
export default class extends Controller {
  remove () {
    const url = new URL(window.location)
    const remaining = new URL(this.element.href).searchParams.get('vehicle_models')
    remaining ? url.searchParams.set('vehicle_models', remaining) : url.searchParams.delete('vehicle_models')
    this.element.href = withCommas(url)
  }
}
