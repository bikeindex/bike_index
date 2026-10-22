import { Controller } from '@hotwired/stimulus'
import { html, nothing, render } from 'lit-html'
import { loadCatalog } from 'bikebook/catalog'
import { withFigures } from 'bikebook/cycle_drawings'
import { chosenSizes } from 'bikebook/sizes'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { cycleDrawing } from 'bikebook/templates/vehicles/cycle_drawing'

const catalogs = new Map()
// one catalog, and its worker, for every drawing on the page
const catalogAt = (manifestUrl) => catalogs.get(manifestUrl) ?? catalogs.set(manifestUrl, loadCatalog(manifestUrl)).get(manifestUrl)

// Its Sizes & geometry view, with the size drawn here picked
const geometryPath = (id, size) => `/bikebook?${new URLSearchParams({ vehicle_models: id, view: 'geometry', ...(size?.name ? { vehicle_sizes: size.name } : {}) })}`

// Connects to data-controller='admin--cycle-drawing'
// Draws a vehicle type, or a type_detail of it, in a catalog model's size where it's given one, redrawn as a figure's input changes
export default class extends Controller {
  static values = { type: String, typeDetail: String, model: String, manifestUrl: String }

  async connect () {
    this.figures = {}
    this.highlight = null
    const catalog = await catalogAt(this.manifestUrlValue)
    // a model in the size BikeBook first shows it in
    const [found] = this.modelValue ? await catalog.vehicles([this.modelValue]) : [{ data: {} }]
    this.kit = catalog.kit
    this.vehicle = found && { id: found.value, data: found.data, size: found.value && chosenSizes([found])[0] }
    this.vehicle
      ? this.draw()
      : render(html`<p class="tw:text-gray-500"><code>${this.modelValue}</code> isn't in the published catalog yet</p>`, this.element)
  }

  // a cleared figure goes back to what the size lists
  edit ({ target }) {
    const { [target.name]: _, ...rest } = this.figures
    this.figures = target.value === '' ? rest : { ...rest, [target.name]: Number(target.value) }
    this.draw()
  }

  // a figure's letter, on the drawing or in the legend, highlights it until it's clicked again
  select (key) {
    this.highlight = this.highlight === key ? null : key
    this.draw()
  }

  reset () {
    this.figures = {}
    this.draw()
  }

  draw () {
    const { id, data, size } = this.vehicle
    const { figure, legend } = cycleDrawing({
      type: this.typeValue, typeDetail: this.typeDetailValue || undefined, data, size: withFigures(size, this.figures), kit: this.kit, highlight: this.highlight
    })
    const extras = legend.filter(({ extra }) => extra)
    // the model's line held open when there's none, so a typical drawing lines up with its example's
    render(html`<p class="tw:mb-2 tw:min-h-5 tw:text-sm">${id
    ? html`<a class="twlink" href=${geometryPath(id, size)}>${data.manufacturer} ${data.model}</a>${size?.name
      ? html` <span class="tw:text-gray-500">${size.name}</span>`
      : nothing}`
    : nothing}</p><div class="tw:text-gray-800 tw:dark:text-gray-200" @click=${({ target }) => {
      const key = target.closest('[data-figure]')?.dataset.figure
      if (key) this.select(key)
    }}>${figure}</div>${this.figureList(legend.filter(({ extra }) => !extra))}${extras.length
    ? html`<h4 class="tw:mt-3 tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">Extra measurements</h4>${this.figureList(extras)}`
    : nothing}<div class="tw:mt-2 tw:flex tw:justify-center"><button type="button" class=${buttonClasses({ size: 'sm' })}
    ?disabled=${Object.keys(this.figures).length === 0} @click=${() => this.reset()}>Reset</button></div>`, this.element)
  }

  // the legend's figures, down one column then the next, each an input but those that can't be set
  figureList (figures) {
    const idPrefix = [this.typeValue, this.typeDetailValue, this.modelValue].filter(Boolean).join('-').replaceAll('/', '-')
    return html`<ol class="tw:mt-2 tw:columns-2 tw:gap-4 tw:text-xs">${figures.map(({ letter, key, label, value, unit, listed, calculated, editable }) =>
    html`<li class="tw:mb-1 tw:flex tw:break-inside-avoid tw:items-baseline tw:gap-2 ${key === this.highlight ? 'tw:font-bold' : ''} ${key === this.highlight && listed
      ? 'tw:text-blue-500'
      : listed || calculated ? '' : 'tw:text-gray-500'}">${letter
      ? html`<button type="button" aria-label=${`Highlight ${label}`} aria-pressed=${String(key === this.highlight)}
      @click=${() => this.select(key)} class="tw:inline-flex tw:size-5 tw:shrink-0 tw:cursor-pointer tw:items-center tw:justify-center tw:rounded-full
      tw:border-0! tw:p-0! tw:text-xs tw:font-bold tw:text-white tw:focus:outline-none! tw:focus-visible:ring-2 tw:focus-visible:ring-blue-500/40 ${key === this.highlight && listed
        ? 'tw:bg-blue-500'
        : listed ? 'tw:bg-[#715eb2]' : calculated ? 'tw:bg-purple-300' : 'tw:bg-gray-400'}">${letter}</button>`
      : html`<span class="tw:w-5 tw:shrink-0"></span>`}<label for=${`${idPrefix}-${key}`}
      class="tw:grow">${label}</label>${!editable
      ? html`<span class="tw:font-mono">${value} ${unit}</span>`
      : html`<input type="number" step="any" name=${key} id=${`${idPrefix}-${key}`} autocomplete="off"
        class="twinput tw:w-20! tw:py-0.5! tw:text-right tw:text-xs!" .value=${String(value)} @input=${(event) => this.edit(event)}><span
        class="tw:w-6">${unit}</span>`}</li>`)}</ol>`
  }
}
