import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='legacy-form-well--address-record'
export default class extends Controller {
  static targets = ['country', 'state', 'region']
  static values = { usId: String }

  connect () {
    this.updateRegionFieldOnCountryChange()
  }

  updateRegionFieldOnCountryChange () {
    console.log('changed')
    this.countryTarget.addEventListener('change', (event) => {
      if (event.target.value === this.usIdValue) {
        // Show the state select
        collapse('hide', this.regionTarget)
        collapse('show', this.stateTarget)
      } else {
        // Show the region string field
        collapse('show', this.regionTarget)
        collapse('hide', this.stateTarget)
        // Set state select value to empty, it overrides region string
        this.stateTarget.value = ''
      }
    })
  }
}
