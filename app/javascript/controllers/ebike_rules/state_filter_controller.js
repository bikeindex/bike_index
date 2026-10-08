import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ebike-rules--state-filter'
// Narrows the state list to names matching the field, and opens the state a link's hash names
export default class extends Controller {
  static targets = ['field', 'count', 'state']

  connect () {
    this.allCount = this.countTarget.innerHTML
    const linked = this.stateTargets.find((state) => `#${state.id}` === window.location.hash)
    linked?.querySelector('[data-ui--collapse-target~="trigger"]')?.click()
  }

  filter () {
    const query = this.fieldTarget.value.trim().toLowerCase()
    const matches = this.stateTargets.filter((state) => {
      const match = state.dataset.name.toLowerCase().includes(query)
      collapse(match ? 'show' : 'hide', state)
      return match
    })
    if (query) {
      this.countTarget.textContent = this.countTarget.dataset.matchingTemplate.replace('__number__', matches.length)
    } else {
      this.countTarget.innerHTML = this.allCount
    }
  }
}
