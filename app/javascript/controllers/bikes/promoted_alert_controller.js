import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bikes--promoted-alert'
// The purchase button names the plan picked, and the preview shows the photo picked
export default class extends Controller {
  static targets = ['purchaseText', 'previewImage']

  update () {
    const plan = this.element.querySelector('input[name="theft_alert_plan_id"]:checked')
    if (plan && this.hasPurchaseTextTarget) this.purchaseTextTarget.textContent = plan.dataset.purchaseText

    const image = this.element.querySelector('input[name="selected_bike_image_id"]:checked')
    if (image && this.hasPreviewImageTarget) this.previewImageTarget.src = image.dataset.imageUrl
  }
}
