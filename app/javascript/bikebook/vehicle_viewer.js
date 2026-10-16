import { html, nothing } from 'lit-html'
import { basics } from 'bikebook/templates/vehicles/basics'
import { chosenSizes, pickedSizes, sizesParam } from 'bikebook/sizes'
import { comparisonTable } from 'bikebook/templates/vehicles/comparison_table'
import { emptyState } from 'bikebook/templates/vehicles/empty_state'
import { frameGeometry } from 'bikebook/frame_geometry'
import { geometryOverlay, seriesBorders } from 'bikebook/templates/vehicles/geometry_overlay'
import { jumpTo, VIEWS } from 'bikebook/templates/vehicles/jump_to'
import { basicsOf, componentsOf, modelViewer, motorsOf, runningGearOf, sizesOf } from 'bikebook/templates/vehicles/model_viewer'
import { present } from 'bikebook/templates/values'
import { toQuery } from 'bikebook/query'
import { VehiclePresenter } from 'bikebook/vehicle_presenter'

// The compared vehicles' cards, from catalog blocks
export class VehicleViewer {
  constructor (kit, vocabulary) {
    this.presenter = new VehiclePresenter(kit, vocabulary)
  }

  // The vehicles at `url` in the view it picks, whose links keep its other params, compared in the sizes it picks or
  // the nearest to the `preferredSize`. With none, the `search`'s count, whether filters narrow it, and its featured models
  render (vehicles, url, preferredSize, search) {
    const { presenter } = this
    if (vehicles.length === 0) {
      return emptyState({
        url,
        vehiclePath: (id) => pathWith(url, { vehicle_models: id }),
        placeholderUrl: presenter.kit.placeholder_url,
        currencies: presenter.vocabulary.currencies,
        ...search
      })
    }

    const shown = Object.keys(VIEWS).filter((each) => each !== 'motors' || vehicles.some(({ data }) => present(data.motors)))
    const requested = url.searchParams.get('view')
    const view = shown.includes(requested) ? requested : 'basics'
    const comparing = vehicles.length > 1
    const picked = pickedSizes(url)
    const sizes = chosenSizes(vehicles, { picked, preferred: preferredSize })
    const selectedSizes = new Map(vehicles.map(({ value }, index) => [value, sizes[index]?.name]))
    const values = vehicles.map(({ value }) => value)
    const baseline = vehicles[0]
    const others = (value) => value === baseline.value ? [] : [baseline.data]
    const sizePath = (value) => (name) => pathWith(url, { vehicle_sizes: sizesParam(values, { ...picked, [value]: name }) })
    const compared = { presenter, vehicles, sizes, frames: vehicles.map(({ data }, index) => frameGeometry(data, sizes[index])) }
    const rowClasses = comparing
      ? 'tw:justify-center-safe tw:overflow-x-auto tw:max-md:snap-x tw:max-md:snap-mandatory tw:max-md:px-4 tw:max-md:*:w-[85vw] tw:max-md:*:shrink-0 tw:max-md:*:snap-center'
      : 'tw:flex-col tw:lg:flex-row tw:lg:justify-center'
    const cardRow = (margin, cards) => html`<div ?data-comparison=${comparing} class="${margin} tw:max-[500px]:mx-[calc(50%-50vw)] tw:max-[500px]:w-screen ${comparing
      ? 'tw:md:mx-[calc(50%-50vw)] tw:md:w-screen tw:md:px-4'
      : 'tw:lg:mx-[calc(50%-50vw)] tw:lg:w-screen tw:lg:px-4'}"><div class="tw:flex tw:gap-8 ${rowClasses}">${cards}</div></div>`
    // each vehicle's `key` on a card of its own, named as its full card is, after whatever `lead` shows
    // `keyed`, each topped in its frame's color in the overlay
    const cards = (key, none, content, { lead = () => nothing, keyed = false } = {}) => vehicles.map(({ data, value }, index) => {
      const { manufacturer, model } = presenter.named(presenter.kit.schemas.vehicle, data)
      return html`<section aria-label=${`${[manufacturer, model].filter(present).join(' ')} ${key}`} class="twgutter tw:w-full tw:min-w-0 tw:space-y-4
        tw:rounded-sm tw:border tw:border-gray-200 tw:bg-white tw:pt-4 tw:pb-6 tw:[--gutter:--spacing(6)] tw:dark:border-gray-700 tw:dark:bg-gray-800
        ${keyed ? seriesBorders(compared.frames, index).top : ''} ${comparing ? 'tw:md:max-w-[56rem] tw:lg:flex-1' : 'tw:lg:w-[56rem] tw:lg:shrink-0'}"><header class="tw:flex tw:items-start tw:justify-between tw:gap-4"><div>${present(manufacturer)
        ? html`<p class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p>`
        : nothing}<h3 class="tw:text-2xl tw:leading-tight tw:font-extrabold">${model}</h3></div><div
        class="tw:shrink-0">${basicsOf({ presenter, data }).photo('tw:h-14 tw:w-21')}</div></header>${lead(data, value)}${present(data[key])
        ? content(data, value)
        : html`<p class="twless-strong">${none}</p>`}</section>`
    })
    const views = {
      basics: () => basics({ presenter, vehicles }),
      // the overlay beside the table once the window is wide, above it until then
      geometry: () => html`<div class="tw:flex tw:flex-col tw:min-[1500px]:mx-[calc(50%-50vw)] tw:min-[1500px]:w-screen tw:min-[1500px]:flex-row
        tw:min-[1500px]:items-start tw:min-[1500px]:gap-6 tw:min-[1500px]:px-4">${geometryOverlay({ ...compared, beside: true })}${
        comparisonTable({ ...compared, part: 'geometry', beside: true })}</div>${cardRow('tw:mt-6', cards('sizes', 'No sizes listed', (data, value) =>
        html`<div class="tw:-mx-(--gutter)">${sizesOf({ presenter, data, others: others(value), selectedSize: selectedSizes.get(value), sizePath: sizePath(value) })}</div>`,
      { keyed: true }))}`,
      components: () => cardRow('tw:mt-6', cards('components', 'No components listed', (data, value) => componentsOf({ presenter, data, others: others(value) }),
        { lead: (data, value) => runningGearOf({ presenter, data, others: others(value) }) })),
      motors: () => cardRow('tw:mt-6', cards('motors', 'No motor', (data, value) => motorsOf({ presenter, data, others: others(value) }))),
      all: () => {
        const full = vehicles.map(({ data, value }, index) => {
          const remaining = values.filter((each) => each !== value)
          const removePath = pathWith(url, { vehicle_models: remaining.join(','), vehicle_sizes: sizesParam(remaining, picked) })
          return modelViewer({ presenter, data, value, comparing, idSuffix: index + 1, others: others(value), removePath, selectedSize: selectedSizes.get(value), sizePath: sizePath(value) })
        })
        return html`${comparisonTable({ ...compared, part: 'all' })}${geometryOverlay(compared)}${cardRow('tw:mt-8', full)}`
      }
    }
    return html`${jumpTo(view, (each) => pathWith(url, { view: each === 'basics' ? '' : each }), shown)}${views[view]()}`
  }
}

// This page's URL with `params` laid over its own
const pathWith = (url, params) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), ...params })
  return query ? `${url.pathname}?${query}` : url.pathname
}
