import { html, nothing } from 'lit-html'
import { basics } from 'bikebook/templates/vehicles/basics'
import { classificationCard } from 'bikebook/templates/vehicles/classification_card'
import { chosenSizes, pickedSizes, sizesParam } from 'bikebook/sizes'
import { comparisonTable } from 'bikebook/templates/vehicles/comparison_table'
import { emptyState } from 'bikebook/templates/vehicles/empty_state'
import { frameGeometry } from 'bikebook/frame_geometry'
import { geometryOverlay } from 'bikebook/templates/vehicles/geometry_overlay'
import { jumpTo, VIEWS } from 'bikebook/templates/vehicles/jump_to'
import { modelViewer, sizesOf } from 'bikebook/templates/vehicles/model_viewer'
import { sectionHeading } from 'bikebook/templates/vehicles/section'
import { present } from 'bikebook/templates/values'
import { toQuery } from 'bikebook/query'
import { VehiclePresenter } from 'bikebook/vehicle_presenter'

// The compared vehicles' cards, from catalog blocks, and any e-vehicle classification picked beside them
export class VehicleViewer {
  constructor (kit, vocabulary) {
    this.presenter = new VehiclePresenter(kit, vocabulary)
  }

  // `url` with an e-vehicle classification added to the compared `values`
  classificationPath (url, values) {
    return (id) => pathWith(url, { vehicle_models: [...new Set([...values, id])].join(',') })
  }

  // The vehicles at `url` in the view it picks, whose links keep its other params, compared in the sizes it picks or
  // the nearest to the `preferredSize`
  render (vehicles, url, preferredSize) {
    if (vehicles.length === 0) return emptyState(url.pathname)

    const { presenter } = this
    const requested = url.searchParams.get('view')
    const view = requested in VIEWS ? requested : 'basics'
    const comparing = vehicles.length > 1
    const models = vehicles.filter(({ classification }) => !classification)
    const tabled = models.length > 1
    const picked = pickedSizes(url)
    const sizes = tabled ? chosenSizes(models, { picked, preferred: preferredSize }) : []
    const selectedSizes = new Map(models.map(({ value }, index) => [value, sizes[index]?.name]))
    const rowClasses = comparing
      ? 'tw:justify-center-safe tw:overflow-x-auto tw:max-md:snap-x tw:max-md:snap-mandatory tw:max-md:px-4 tw:max-md:*:w-[85vw] tw:max-md:*:shrink-0 tw:max-md:*:snap-center'
      : 'tw:flex-col tw:lg:flex-row tw:lg:justify-center'
    const values = vehicles.map(({ value }) => value)
    const baseline = models[0]
    const others = (value) => value === baseline.value ? [] : [baseline.data]
    const classificationPath = this.classificationPath(url, values)
    const cards = vehicles.map(({ data, value, classification }, index) => {
      const remaining = values.filter((each) => each !== value)
      const remove = pathWith(url, { vehicle_models: remaining.join(','), vehicle_sizes: sizesParam(remaining, picked) })
      return {
        classification,
        card: classification
          ? classificationCard({ presenter, id: value, classification: data, removePath: remove, classificationPath })
          : modelViewer({ presenter, data, value, comparing, idSuffix: index + 1, others: others(value), removePath: remove, classificationPath })
      }
    })
    const cardRow = (shown) => shown.length
      ? html`<div ?data-comparison=${comparing} class="tw:mt-8 tw:max-[500px]:mx-[calc(50%-50vw)] tw:max-[500px]:w-screen ${comparing
        ? 'tw:md:mx-[calc(50%-50vw)] tw:md:w-screen tw:md:px-4'
        : 'tw:lg:mx-[calc(50%-50vw)] tw:lg:w-screen tw:lg:px-4'}"><div class="tw:flex tw:gap-8 ${rowClasses}">${shown.map(({ card }) => card)}</div></div>`
      : nothing
    const compared = { presenter, vehicles: models, sizes, frames: models.map(({ data }, index) => frameGeometry(data, sizes[index])) }
    const sizeLists = html`<div ?data-comparison=${comparing} class="tw:mt-6 tw:space-y-6">${models.map(({ data, value }) => {
      const { manufacturer, model } = presenter.named(presenter.kit.schemas.vehicle, data)
      const title = [manufacturer, model].filter(present).join(' ')
      return html`<section aria-label=${`${title} sizes`} class="tw:space-y-2"><h3 class="tw:font-bold">${title}</h3>${
        present(data.sizes) ? sizesOf({ presenter, data, others: others(value), selectedSize: selectedSizes.get(value) }) : html`<p class="twless-strong">No sizes listed</p>`}</section>`
    })}</div>`
    const sections = {
      basics: (alone) => html`${models.length ? basics({ presenter, vehicles: models, classificationPath }) : nothing}${
        alone ? cardRow(cards.filter(({ classification }) => classification)) : nothing}`,
      geometry: () => html`${tabled
        ? html`${comparisonTable({ ...compared, part: 'geometry', label: 'Sizes & geometry comparison' })}${geometryOverlay(compared)}`
        : nothing}${sizeLists}`,
      components: (alone) => html`${tabled ? comparisonTable({ ...compared, label: 'Components comparison' }) : nothing}${
        cardRow(alone ? cards.filter(({ classification }) => !classification) : cards)}`
    }
    const shown = view === 'all'
      ? Object.entries(sections).map(([name, section]) => html`<div class="tw:mt-10">${sectionHeading(VIEWS[name])}${section(false)}</div>`)
      : sections[view](true)
    return html`${jumpTo(view, (each) => pathWith(url, { view: each === 'basics' ? '' : each }))}${shown}`
  }
}

// This page's URL with `params` laid over its own
const pathWith = (url, params) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), ...params })
  return query ? `${url.pathname}?${query}` : url.pathname
}
