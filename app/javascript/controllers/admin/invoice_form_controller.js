import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--invoice-form'
//
// Replaces BinxAdminInvoices from the vendored admin bundle. Two behaviors:
//   1. Total the checked features, and derive the discount from the amount due.
//   2. An endless invoice has no coverage-ends date, so hide that field.
//
// The feature ids ride in a hidden field because the checkboxes are named
// individually — Rails only sees whichever the server rendered.
export default class extends Controller {
  static targets = [
    'feature',
    'oneTimeCount',
    'oneTimeCost',
    'recurringCount',
    'recurringCost',
    'totalCost',
    'discountCost',
    'amountDue',
    'featureIds',
    'isEndless',
    'endsAt'
  ]

  connect () {
    this.recalculate()
    this.toggleEndsAt()
  }

  recalculate () {
    const checked = this.featureTargets.filter(feature => feature.checked)
    const oneTime = checked.filter(feature => feature.dataset.recurring !== 'true')
    const recurring = checked.filter(feature => feature.dataset.recurring === 'true')

    const oneTimeCost = this.sum(oneTime)
    const recurringCost = this.sum(recurring)

    this.oneTimeCountTarget.textContent = oneTime.length
    this.recurringCountTarget.textContent = recurring.length
    this.oneTimeCostTarget.textContent = `${oneTimeCost}.00`
    this.recurringCostTarget.textContent = `${recurringCost}.00`
    this.totalCostTarget.textContent = `${oneTimeCost + recurringCost}.00`

    // A blank amount due reads as 0, the same as the vendored version's NaN did not
    const due = parseInt(this.amountDueTarget.value, 10) || 0
    this.discountCostTarget.textContent = `${due - (oneTimeCost + recurringCost)}.00`

    this.featureIdsTarget.value = checked.map(feature => feature.dataset.id).join(',')
  }

  toggleEndsAt () {
    collapse(this.isEndlessTarget.checked ? 'hide' : 'show', this.endsAtTarget)
  }

  sum (features) {
    return features.reduce((total, feature) => total + (parseInt(feature.dataset.amount, 10) || 0), 0)
  }
}
