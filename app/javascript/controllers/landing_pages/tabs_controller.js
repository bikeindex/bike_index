import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-pages--tabs'
export default class extends Controller {
  static targets = ['button', 'panel']

  // Tab functionality
  select (event) {
    this.activate(event.currentTarget)
  }

  keydown (event) {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return

    event.preventDefault()
    const buttons = this.buttonTargets
    const currentIndex = buttons.indexOf(event.currentTarget)
    let nextIndex
    if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + buttons.length) % buttons.length
    else if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % buttons.length
    else if (event.key === 'Home') nextIndex = 0
    else nextIndex = buttons.length - 1

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
