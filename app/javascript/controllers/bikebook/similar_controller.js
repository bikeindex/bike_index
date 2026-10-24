import { Controller } from '@hotwired/stimulus'
import { replaceUrl } from 'bikebook/replace_url'
import { PRESETS, presetOf, weightsFrom, weightsParam } from 'bikebook/similarity'

// Connects to data-controller='bikebook--similar'
// The similar models' weights and whether they include the model's maker's others, kept in the URL as they change, which
// the page rescores them by in place, once it's scored them on their section first opening.
// The model has no slider for a group it lists nothing in, whose weight a strategy sets and a slider leaves. A strategy's
// input events don't bubble, so they show each slider's value without rescoring for each
export default class extends Controller {
  static targets = ['weight', 'strategy', 'sameManufacturer', 'otherPropulsion']
  static values = { vehicle: String, scored: Boolean }

  load () {
    if (!this.scoredValue) this.dispatch('open')
  }

  // a preset's, as Custom can be clicked only while it's chosen
  strategy ({ target }) {
    const { weights } = PRESETS[target.value]
    for (const input of this.weightTargets) {
      input.value = weights[input.name]
      input.dispatchEvent(new Event('input'))
    }
    this.#apply(weights)
  }

  change () {
    this.#apply(weightsFrom(new URL(window.location.href).searchParams.get('weights')))
  }

  // Custom can be chosen only while weights off every preset choose it
  #apply (unslid) {
    const weights = { ...unslid, ...Object.fromEntries(this.weightTargets.map(({ name, value }) => [name, Number(value)])) }
    const preset = presetOf(weights, this.weightTargets.map(({ name }) => name))
    for (const radio of this.strategyTargets) {
      radio.checked = radio.value === preset
      if (radio.value === 'custom') {
        radio.disabled = preset !== 'custom'
        radio.disabled ? radio.labels[0].setAttribute('aria-disabled', 'true') : radio.labels[0].removeAttribute('aria-disabled')
      }
    }
    const sameManufacturer = this.sameManufacturerTarget.checked
    const otherPropulsion = this.hasOtherPropulsionTarget && this.otherPropulsionTarget.checked
    const url = new URL(window.location.href)
    const param = weightsParam(weights)
    param ? url.searchParams.set('weights', param) : url.searchParams.delete('weights')
    sameManufacturer ? url.searchParams.set('same_manufacturer', '1') : url.searchParams.delete('same_manufacturer')
    otherPropulsion ? url.searchParams.set('other_propulsion', '1') : url.searchParams.delete('other_propulsion')
    replaceUrl(url)
    this.dispatch('change', { detail: { vehicle: this.vehicleValue, settings: { weights, sameManufacturer, otherPropulsion } } })
  }
}
