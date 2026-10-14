import { html, nothing } from 'lit-html'
import { basics } from 'bikebook/templates/vehicles/basics'
import { classificationCard } from 'bikebook/templates/vehicles/classification_card'
import { chosenSizes, pickedSizes, sizesParam } from 'bikebook/sizes'
import { comparisonTable } from 'bikebook/templates/vehicles/comparison_table'
import { emptyState } from 'bikebook/templates/vehicles/empty_state'
import { frameGeometry } from 'bikebook/frame_geometry'
import { geometryOverlay } from 'bikebook/templates/vehicles/geometry_overlay'
import { jumpTo, VIEWS } from 'bikebook/templates/vehicles/jump_to'
import { componentsOf, modelViewer, sizesOf } from 'bikebook/templates/vehicles/model_viewer'
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
  // the nearest to the `preferredSize`. With none, the `search`'s count and whether filters narrow it
  render (vehicles, url, preferredSize, search) {
    if (vehicles.length === 0) return emptyState({ pathname: url.pathname, filtersPath: pathWith(url, { filters: 1 }), ...search })

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
    const card = (vehicle) => {
      const { data, value, classification } = vehicle
      const remaining = values.filter((each) => each !== value)
      const remove = pathWith(url, { vehicle_models: remaining.join(','), vehicle_sizes: sizesParam(remaining, picked) })
      return classification
        ? classificationCard({ presenter, id: value, classification: data, removePath: remove, classificationPath })
        : modelViewer({ presenter, data, value, comparing, idSuffix: vehicles.indexOf(vehicle) + 1, others: others(value), removePath: remove, classificationPath })
    }
    const cardRow = (classified) => {
      const shown = vehicles.filter(({ classification }) => Boolean(classification) === classified)
      return shown.length
        ? html`<div ?data-comparison=${comparing} class="tw:mt-8 tw:max-[500px]:mx-[calc(50%-50vw)] tw:max-[500px]:w-screen ${comparing
          ? 'tw:md:mx-[calc(50%-50vw)] tw:md:w-screen tw:md:px-4'
          : 'tw:lg:mx-[calc(50%-50vw)] tw:lg:w-screen tw:lg:px-4'}"><div class="tw:flex tw:gap-8 ${rowClasses}">${shown.map(card)}</div></div>`
        : nothing
    }
    const compared = () => ({ presenter, vehicles: models, sizes, frames: models.map(({ data }, index) => frameGeometry(data, sizes[index])) })
    // each model's `content`, or `none` where it has no `key`, under its name
    const listed = (key, none, content) => html`<div ?data-comparison=${comparing} class="tw:mt-6 tw:space-y-6">${models.map(({ data, value }) => {
      const { manufacturer, model } = presenter.named(presenter.kit.schemas.vehicle, data)
      const title = [manufacturer, model].filter(present).join(' ')
      return html`<section aria-label=${`${title} ${key}`} class="tw:space-y-2"><h3 class="tw:font-bold">${title}</h3>${
        present(data[key]) ? content(data, value) : html`<p class="twless-strong">${none}</p>`}</section>`
    })}</div>`
    const basicsView = () => html`${models.length ? basics({ presenter, vehicles: models, classificationPath }) : nothing}${cardRow(true)}`
    const geometryView = () => {
      const comparison = compared()
      return html`${tabled ? html`${comparisonTable({ ...comparison, part: 'geometry' })}${geometryOverlay(comparison)}` : nothing}${
        listed('sizes', 'No sizes listed', (data, value) => sizesOf({ presenter, data, others: others(value), selectedSize: selectedSizes.get(value) }))}`
    }
    // a classification has its card, and no sizes or components
    const views = models.length
      ? { basics: basicsView, geometry: geometryView, components: () => listed('components', 'No components listed', (data, value) => componentsOf({ presenter, data, others: others(value) })) }
      : { basics: basicsView }
    // every model's whole card, the components with the rest of its specs
    const all = models.length
      ? [[VIEWS.basics, basicsView], [VIEWS.geometry, geometryView], ['Specs & components', () => html`${tabled ? comparisonTable(compared()) : nothing}${cardRow(false)}`]]
      : [[VIEWS.basics, basicsView]]
    const shown = view === 'all'
      ? all.map(([heading, section]) => html`<div class="tw:mt-10">${sectionHeading(heading)}${section()}</div>`)
      : views[view]?.() ?? html`<p class="tw:mt-6 tw:text-sm tw:text-gray-600 tw:dark:text-gray-400">E-vehicle classifications have no ${
        VIEWS[view].toLowerCase()}. Their rules are under Basics.</p>`
    return html`${jumpTo(view, (each) => pathWith(url, { view: each === 'basics' ? '' : each }))}${shown}`
  }
}

// This page's URL with `params` laid over its own
const pathWith = (url, params) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), ...params })
  return query ? `${url.pathname}?${query}` : url.pathname
}
