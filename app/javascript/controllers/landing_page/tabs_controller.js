import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-page--tabs'
export default class extends Controller {
  static targets = ['button', 'panel']

  select (event) {
    const tabName = event.currentTarget.dataset.tab

    this.buttonTargets.forEach(btn => btn.classList.remove('active'))
    this.panelTargets.forEach(panel => panel.classList.remove('active'))

    event.currentTarget.classList.add('active')
    const panel = this.panelTargets.find(p => p.id === `tab-${tabName}`)
    if (panel) panel.classList.add('active')
  }
}
