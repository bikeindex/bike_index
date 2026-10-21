import { Controller } from '@hotwired/stimulus'
import { html, nothing, render } from 'lit-html'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { cycleDrawing } from 'bikebook/templates/vehicles/cycle_drawing'
import { array } from 'bikebook/templates/values'

const catalogFiles = new Map()
const MODEL_BLOCK = /^m\/([a-z0-9_]+\/\d{4})\//

// A published catalog file, the manifest when it's given no `path`, fetched once
const catalogFile = (manifestUrl, path) => {
  const url = new URL(path ?? manifestUrl, new URL(manifestUrl, window.location.href))
  if (!catalogFiles.has(url.href)) catalogFiles.set(url.href, fetch(url).then((response) => response.json()))
  return catalogFiles.get(url.href)
}

// The figures the catalog's geometry schema has, rather than gathering in extra_measurements
const fetchGeometryKeys = async (manifestUrl) =>
  Object.keys((await catalogFile(manifestUrl, (await catalogFile(manifestUrl)).kit)).kit.schemas.geometry)

// A catalog model and its middle size, null for one the catalog hasn't published
const fetchModel = async (manifestUrl, id) => {
  const block = (await catalogFile(manifestUrl)).blocks[id.match(MODEL_BLOCK)[1]]
  const data = block && (await catalogFile(manifestUrl, block)).models[id]
  if (!data) return null
  const sizes = array(data.sizes)
  return { id, data, size: sizes[Math.floor(sizes.length / 2)] }
}

// Its Sizes & geometry view, with the size drawn here picked
const geometryPath = (id, size) => `/bikebook?${new URLSearchParams({ vehicle_models: id, view: 'geometry', ...(size?.name ? { vehicle_sizes: size.name } : {}) })}`

// `size` with each of `figures`, a key as dimensions.length for one inside a hash
const withFigures = (size, figures) => ({
  ...size,
  geometry: Object.entries(figures).reduce((geometry, [key, value]) => {
    const [name, field] = key.split('.')
    return field ? { ...geometry, [name]: { ...geometry[name], [field]: value } } : { ...geometry, [name]: value }
  }, size?.geometry ?? {})
})

// Connects to data-controller='admin--cycle-drawing'
// Draws a vehicle type, or a type_detail of it, a catalog model's middle size where it's given one, redrawn as a figure's input changes
export default class extends Controller {
  static values = { type: String, typeDetail: String, model: String, manifestUrl: String }

  async connect () {
    this.figures = {}
    this.highlight = null
    this.geometryKeys = await fetchGeometryKeys(this.manifestUrlValue)
    this.vehicle = this.modelValue ? await fetchModel(this.manifestUrlValue, this.modelValue) : { data: {} }
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
      type: this.typeValue, typeDetail: this.typeDetailValue || undefined, data, size: withFigures(size, this.figures), geometryKeys: this.geometryKeys, highlight: this.highlight
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

  // the legend's figures, down one column then the next, each an input but the wheels' diameters
  figureList (figures) {
    const idPrefix = [this.typeValue, this.typeDetailValue, this.modelValue].filter(Boolean).join('-').replaceAll('/', '-')
    return html`<ol class="tw:mt-2 tw:columns-2 tw:gap-4 tw:text-xs">${figures.map(({ letter, key, label, value, unit, listed }) =>
    html`<li class="tw:mb-1 tw:flex tw:break-inside-avoid tw:items-baseline tw:gap-2 ${key === this.highlight
      ? 'tw:font-bold tw:text-blue-500'
      : listed ? '' : 'tw:text-gray-500'}"><button type="button" aria-label=${`Highlight ${label}`} aria-pressed=${String(key === this.highlight)}
      @click=${() => this.select(key)} class="tw:inline-flex tw:size-5 tw:shrink-0 tw:cursor-pointer tw:items-center tw:justify-center tw:rounded-full
      tw:border-0! tw:p-0! tw:text-xs tw:font-bold tw:text-white tw:focus:outline-none! tw:focus-visible:ring-2 tw:focus-visible:ring-blue-500/40 ${key === this.highlight
        ? 'tw:bg-blue-500'
        : listed ? 'tw:bg-[#715eb2]' : 'tw:bg-gray-400'}">${letter}</button><label for=${`${idPrefix}-${key}`}
      class="tw:grow">${label}</label>${key.startsWith('wheel_')
      ? html`<span class="tw:font-mono">${value} ${unit}</span>`
      : html`<input type="number" step="any" name=${key} id=${`${idPrefix}-${key}`} autocomplete="off"
        class="twinput tw:w-20! tw:py-0.5! tw:text-right tw:text-xs!" .value=${String(value)} @input=${(event) => this.edit(event)}><span
        class="tw:w-6">${unit === '°' ? '°' : 'mm'}</span>`}</li>`)}</ol>`
  }
}
