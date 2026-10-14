import { html, nothing } from 'lit-html'
import { basics } from 'bikebook/templates/vehicles/basics'
import { chosenSizes, pickedSizes, sizesParam } from 'bikebook/sizes'
import { comparisonTable } from 'bikebook/templates/vehicles/comparison_table'
import { emptyState } from 'bikebook/templates/vehicles/empty_state'
import { frameGeometry } from 'bikebook/frame_geometry'
import { geometryOverlay } from 'bikebook/templates/vehicles/geometry_overlay'
import { jumpTo, VIEWS } from 'bikebook/templates/vehicles/jump_to'
import { basicsOf, componentsOf, modelViewer, sizesOf } from 'bikebook/templates/vehicles/model_viewer'
import { present } from 'bikebook/templates/values'
import { toQuery } from 'bikebook/query'
import { VehiclePresenter } from 'bikebook/vehicle_presenter'

// The compared vehicles' cards, from catalog blocks
export class VehicleViewer {
  constructor (kit, vocabulary) {
    this.presenter = new VehiclePresenter(kit, vocabulary)
  }

  // The vehicles at `url` in the view it picks, whose links keep its other params, compared in the sizes it picks or
  // the nearest to the `preferredSize`. With none, the `search`'s count and whether filters narrow it
  render (vehicles, url, preferredSize, search) {
    if (vehicles.length === 0) return emptyState({ pathname: url.pathname, filtersPath: pathWith(url, { filters: 1 }), ...search })

    const { presenter } = this
    const requested = url.searchParams.get('view')
    const view = requested in VIEWS ? requested : 'basics'
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
    // each vehicle's `key` on a card of its own, named as its full card is
    const cards = (key, none, content) => vehicles.map(({ data, value }) => {
      const { manufacturer, model } = presenter.named(presenter.kit.schemas.vehicle, data)
      return html`<section aria-label=${`${[manufacturer, model].filter(present).join(' ')} ${key}`} class="twgutter tw:w-full tw:min-w-0 tw:space-y-4
        tw:rounded-sm tw:border tw:border-gray-200 tw:bg-white tw:pt-4 tw:pb-6 tw:[--gutter:--spacing(6)] tw:dark:border-gray-700 tw:dark:bg-gray-800
        ${comparing ? 'tw:md:max-w-[56rem] tw:lg:flex-1' : 'tw:lg:w-[56rem] tw:lg:shrink-0'}"><header class="tw:flex tw:items-start tw:justify-between tw:gap-4"><div>${present(manufacturer)
        ? html`<p class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p>`
        : nothing}<h3 class="tw:text-2xl tw:leading-tight tw:font-extrabold">${model}</h3></div>${
        html`<div class="tw:shrink-0">${basicsOf({ presenter, data }).photo('tw:h-14 tw:w-21')}</div>`}</header>${present(data[key])
        ? content(data, value)
        : html`<p class="twless-strong">${none}</p>`}</section>`
    })
    const views = {
      basics: () => basics({ presenter, vehicles }),
      geometry: () => html`${comparing ? comparisonTable({ ...compared, part: 'geometry' }) : nothing}${geometryOverlay(compared)}${cardRow('tw:mt-6', cards('sizes', 'No sizes listed', (data, value) =>
        html`<div class="twgutter-bleed">${sizesOf({ presenter, data, others: others(value), selectedSize: selectedSizes.get(value), sizePath: sizePath(value) })}</div>`))}`,
      components: () => cardRow('tw:mt-6', cards('components', 'No components listed', (data, value) => componentsOf({ presenter, data, others: others(value) }))),
      all: () => {
        const full = vehicles.map(({ data, value }, index) => {
          const remaining = values.filter((each) => each !== value)
          const removePath = pathWith(url, { vehicle_models: remaining.join(','), vehicle_sizes: sizesParam(remaining, picked) })
          return modelViewer({ presenter, data, value, comparing, idSuffix: index + 1, others: others(value), removePath, ...(comparing && { selectedSize: selectedSizes.get(value), sizePath: sizePath(value) }) })
        })
        return html`${comparing ? html`${comparisonTable({ ...compared, part: 'all' })}${geometryOverlay(compared)}` : nothing}${cardRow('tw:mt-8', full)}`
      }
    }
    return html`${jumpTo(view, (each) => pathWith(url, { view: each === 'basics' ? '' : each }))}${views[view]()}`
  }
}

// This page's URL with `params` laid over its own
const pathWith = (url, params) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), ...params })
  return query ? `${url.pathname}?${query}` : url.pathname
}
