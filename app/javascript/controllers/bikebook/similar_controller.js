import { Controller } from '@hotwired/stimulus'
import { replaceUrl } from 'bikebook/replace_url'
import { PRESETS, presetOf, settingsFrom, weightsFrom, weightsParam } from 'bikebook/similarity'

// Connects to data-controller='bikebook--similar'
// The similar models' weights and settings, kept in the URL as they change, which
// the page rescores them by in place, once it's scored them on their section first opening.
// A group the model lists nothing in has a disabled slider that's no weight target, so its weight stays the URL's or a
// strategy's. A strategy's input events don't bubble, so they show each slider's value without rescoring for each
export default class extends Controller {
  static targets = ['weight', 'strategy', 'setting']
  static values = { vehicle: String, size: Number, scored: Boolean }

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
    const url = new URL(window.location.href)
    const params = { weights: weightsParam(weights), ...Object.fromEntries(this.settingTargets.map(({ name, checked }) => [name, checked && '1'])) }
    for (const [name, value] of Object.entries(params)) value ? url.searchParams.set(name, value) : url.searchParams.delete(name)
    replaceUrl(url)
    this.dispatch('change', { detail: { vehicle: this.vehicleValue, settings: settingsFrom(url.searchParams, this.sizeValue) } })
  }
}
