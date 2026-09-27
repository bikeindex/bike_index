import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='memberships--new'
export default class extends Controller {
  static targets = ['plans', 'summary', 'join']

  update () {
    const level = this.element.querySelector('input[name="membership[level]"]:checked')
    const interval = this.element.querySelector('input[name="membership[set_interval]"]:checked')
    const labels = JSON.parse(level.dataset.labels)[interval.value]

    this.summaryTargets.forEach(element => { element.textContent = labels.summary })
    this.joinTargets.forEach(element => { element.textContent = labels.join })
  }

  scrollToPlans (event) {
    event.preventDefault()
    this.plansTarget.scrollIntoView({ behavior: 'smooth' })
  }
}
