import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'
import { replaceUrl } from 'bikebook/replace_url'

// So a ui--collapse that never loads can't leave a frame loop running
const COLLAPSE_WAIT_MS = 10000

// Connects to data-controller='ebike-rules--state-filter'
// Narrows the state list to names matching the field. A state's hash is in the URL while it's open,
// replacing rather than adding history, and opens and scrolls to it on load
export default class extends Controller {
  static targets = ['field', 'count', 'state', 'empty']

  connect () {
    this.allCount = this.countTarget.innerHTML
    const linked = this.stateTargets.find((state) => `#${state.id}` === window.location.hash)
    if (linked) this.open(linked)
  }

  // A state's ui--collapse registers whenever its lazily loaded module resolves, which isn't ordered against this
  // one, and until then its trigger's click does nothing - so it's waited for
  open (state, deadline = Date.now() + COLLAPSE_WAIT_MS) {
    if (!this.application.getControllerForElementAndIdentifier(state, 'ui--collapse')) {
      if (Date.now() < deadline) window.requestAnimationFrame(() => this.open(state, deadline))
      return
    }
    state.querySelector('[data-ui--collapse-target~="trigger"]').click()
    state.scrollIntoView({ block: 'start' })
  }

  // Runs after the trigger's own toggle, so aria-expanded is already the new state
  link ({ currentTarget, target }) {
    const trigger = target.closest('[data-ui--collapse-target~="trigger"]')
    if (!trigger) return

    const hash = `#${currentTarget.id}`
    const open = trigger.getAttribute('aria-expanded') === 'true'
    if (!open && window.location.hash !== hash) return

    const url = new URL(window.location.href)
    url.hash = open ? hash : ''
    replaceUrl(url)
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
