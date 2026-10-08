import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ebike-rules--state-filter'
// Narrows the state list to names matching the field. A state's hash is in the URL while it's open,
// replacing rather than adding history, and opens and scrolls to it on load
export default class extends Controller {
  static targets = ['field', 'count', 'state', 'empty']

  connect () {
    this.allCount = this.countTarget.innerHTML
    const linked = this.stateTargets.find((state) => `#${state.id}` === window.location.hash)
    if (!linked) return

    // each state's ui--collapse connects after this, its ancestor
    window.requestAnimationFrame(() => {
      linked.querySelector('[data-ui--collapse-target~="trigger"]').click()
      linked.scrollIntoView({ block: 'start' })
    })
  }

  // Runs after the trigger's own toggle, so aria-expanded is already the new state
  link ({ currentTarget, target }) {
    const trigger = target.closest('[data-ui--collapse-target~="trigger"]')
    if (!trigger) return

    const hash = `#${currentTarget.id}`
    const open = trigger.getAttribute('aria-expanded') === 'true'
    if (!open && window.location.hash !== hash) return

    const { pathname, search } = window.location
    window.history.replaceState(window.history.state, '', `${pathname}${search}${open ? hash : ''}`)
  }

  filter () {
    const query = this.fieldTarget.value.trim().toLowerCase()
    const matches = this.stateTargets.filter((state) => {
      const match = state.dataset.name.toLowerCase().includes(query)
      collapse(match ? 'show' : 'hide', state)
      return match
    })
    this.emptyTarget.classList.toggle('tw:hidden', matches.length > 0)
    if (query) {
      this.countTarget.textContent = this.countTarget.dataset.matchingTemplate.replace('__number__', matches.length)
    } else {
      this.countTarget.innerHTML = this.allCount
    }
  }
}
