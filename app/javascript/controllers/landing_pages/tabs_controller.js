import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-pages--tabs'
export default class extends Controller {
  static targets = ['button', 'panel']

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
    const panel = this.panelTargets.find(p => p.id === `tab-${tabName}`)
    if (panel) panel.classList.add('active')
  }
}
