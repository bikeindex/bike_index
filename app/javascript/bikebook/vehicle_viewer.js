import { html, nothing } from 'lit-html'
import { classificationCard } from 'bikebook/templates/vehicles/classification_card'
import { chosenSizes, pickedSizes, sizesParam } from 'bikebook/sizes'
import { comparisonTable } from 'bikebook/templates/vehicles/comparison_table'
import { modelViewer } from 'bikebook/templates/vehicles/model_viewer'
import { toQuery } from 'bikebook/query'
import { VehiclePresenter } from 'bikebook/vehicle_presenter'

// The compared vehicles' cards, from catalog blocks, and any e-vehicle classification picked beside them
export class VehicleViewer {
  constructor (kit, vocabulary) {
    this.presenter = new VehiclePresenter(kit, vocabulary)
  }

  // The vehicles at `url`, whose remove links keep its other params, compared in the sizes it picks or the nearest
  // to the `preferredSize`
  render (vehicles, url, preferredSize) {
    if (vehicles.length === 0) {
      return html`<div class="tw:mx-auto tw:mt-6 tw:max-w-4xl tw:rounded-lg tw:border tw:border-dashed tw:border-gray-200 tw:dark:border-gray-700 tw:px-4 tw:py-6 tw:text-center"><p
        class="tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">Nothing selected yet</p><p class="tw:mt-1 tw:text-sm tw:text-gray-500 tw:dark:text-gray-500">Pick a vehicle above to start comparing.</p></div>`
    }

    const comparing = vehicles.length > 1
    const comparisonView = url.searchParams.get('view') === 'comparison'
    const models = vehicles.filter(({ classification }) => !classification)
    const picked = pickedSizes(url)
    const sizes = comparisonView ? chosenSizes(models, { picked, preferred: preferredSize }) : []
    const selectedSizes = new Map(models.map(({ value }, index) => [value, sizes[index]?.name]))
    const baselineSolo = vehicles.length === 3 && !comparisonView
      ? 'tw:md:max-[1152px]:[&>*:first-child]:basis-full tw:md:max-[1152px]:[&>*:first-child>article]:mx-auto tw:md:max-[1152px]:[&>*:first-child>article]:max-w-[calc(50%-1rem)]'
      : ''
    // the comparison view scrolls its cards sideways at any width, a phone's each most of the screen and snapping to it
    const rowClasses = !comparing
      ? 'tw:flex-col tw:lg:flex-row tw:lg:justify-center'
      : comparisonView
        ? 'tw:justify-center-safe tw:overflow-x-auto tw:max-md:snap-x tw:max-md:snap-mandatory tw:max-md:px-4 tw:max-md:*:w-[85vw]! tw:max-md:*:shrink-0 tw:max-md:*:snap-center'
        : 'tw:flex-col tw:md:flex-row tw:md:flex-wrap tw:md:justify-center'
    const values = vehicles.map(({ value }) => value)
    const baseline = models[0]
    const classificationPath = (id) => pathWith(url, { vehicle_models: [...new Set([...values, id])].join(',') })
    const cards = vehicles.map(({ data, value, classification }, index) => {
      const remaining = values.filter((each) => each !== value)
      const remove = pathWith(url, { vehicle_models: remaining.join(','), vehicle_sizes: sizesParam(remaining, picked) })
      return classification
        ? classificationCard({ presenter: this.presenter, id: value, classification: data, removePath: remove })
        : modelViewer({ presenter: this.presenter, data, value, comparing, idSuffix: index + 1, others: value === baseline.value ? [] : [baseline.data], removePath: remove, classificationPath, selectedSize: selectedSizes.get(value) })
    })
    return html`${comparisonView && models.length ? comparisonTable({ presenter: this.presenter, vehicles: models, sizes }) : nothing}<div ?data-comparison=${comparisonView} class="tw:mt-8 tw:max-[500px]:mx-[calc(50%-50vw)] tw:max-[500px]:w-screen ${comparing
      ? 'tw:md:mx-[calc(50%-50vw)] tw:md:w-screen tw:md:px-4'
      : 'tw:lg:mx-[calc(50%-50vw)] tw:lg:w-screen tw:lg:px-4'}"><div class="tw:flex tw:gap-8 ${rowClasses} ${baselineSolo}"
      data-controller="bikebook--wrapped-scroll">${cards}</div></div>`
  }
}

// This page's URL with `params` laid over its own
const pathWith = (url, params) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), ...params })
  return query ? `${url.pathname}?${query}` : url.pathname
}
