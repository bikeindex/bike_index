import { Controller } from '@hotwired/stimulus'
import { urlParam, setUrlParam } from 'utils/url_param'

// Connects to data-controller='landing-pages--tabs'
// param: a query param that records the selected tab, so a reload returns to it
export default class extends Controller {
  static targets = ['button', 'panel']
  static values = { param: String }

  connect () {
    const button = this.paramValue && this.buttonTargets.find(btn => btn.dataset.tab === urlParam(this.paramValue))
    if (button) this.activate(button)
  }

  // Tab functionality
  select (event) {
    this.activate(event.currentTarget)
  }

  keydown (event) {
    const buttons = this.buttonTargets
    const currentIndex = buttons.indexOf(event.currentTarget)
    const nextIndex = {
      ArrowLeft: (currentIndex - 1 + buttons.length) % buttons.length,
      ArrowRight: (currentIndex + 1) % buttons.length,
      Home: 0,
      End: buttons.length - 1
    }[event.key]
    if (nextIndex === undefined) return

    event.preventDefault()
    this.activate(buttons[nextIndex])
    buttons[nextIndex].focus()
  }

  activate (button) {
    const tabName = button.dataset.tab

    // Remove active state from all buttons and panels (roving tabindex)
    this.buttonTargets.forEach(btn => {
      btn.classList.remove('active')
      btn.setAttribute('aria-selected', 'false')
      btn.setAttribute('tabindex', '-1')
    })
    this.panelTargets.forEach(panel => panel.classList.remove('active'))

    // Add active state to the selected button and corresponding panel
    button.classList.add('active')
    button.setAttribute('aria-selected', 'true')
    button.removeAttribute('tabindex')
    if (this.paramValue) setUrlParam(this.paramValue, tabName)
    const panel = this.panelTargets.find(p => p.id === `tab-${tabName}`)
    if (panel) {
      panel.classList.add('active')
      this.dispatch('activated', { target: panel })
    }
  }
}
