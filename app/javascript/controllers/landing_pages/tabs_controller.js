import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-pages--tabs'
export default class extends Controller {
  static targets = ['button', 'panel']

  // Tab functionality
  select (event) {
    const tabName = event.currentTarget.dataset.tab

    // Remove active class from all buttons and panels
    this.buttonTargets.forEach(btn => btn.classList.remove('active'))
    this.panelTargets.forEach(panel => panel.classList.remove('active'))

    // Add active class to clicked button and corresponding panel
    event.currentTarget.classList.add('active')
    const panel = this.panelTargets.find(p => p.id === `tab-${tabName}`)
    if (panel) panel.classList.add('active')
  }
}
