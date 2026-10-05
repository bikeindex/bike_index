import { html } from 'lit-html'
import { modelViewer } from 'bikebook/templates/vehicles/model_viewer'
import { toQuery } from 'bikebook/query'
import { VehiclePresenter } from 'bikebook/vehicle_presenter'

// The compared vehicles' cards, from catalog blocks
export class VehicleViewer {
  constructor (kit, vocabulary) {
    this.presenter = new VehiclePresenter(kit, vocabulary)
  }

  // The vehicles at `url`, whose remove links keep its other params
  render (vehicles, url) {
    if (vehicles.length === 0) {
      return html`<div class="tw:mx-auto tw:mt-6 tw:max-w-4xl tw:rounded-lg tw:border tw:border-dashed tw:border-vellum tw:px-4 tw:py-6 tw:text-center"><p
        class="tw:spec-eyebrow">Nothing selected yet</p><p class="tw:mt-1 tw:text-sm tw:text-gray-500 tw:dark:text-gray-500">Pick a vehicle above to start comparing.</p></div>`
    }

    const comparing = vehicles.length > 1
    const baselineSolo = vehicles.length === 3
      ? 'tw:md:max-[1152px]:[&>*:first-child]:basis-full tw:md:max-[1152px]:[&>*:first-child>article]:mx-auto tw:md:max-[1152px]:[&>*:first-child>article]:max-w-[calc(50%-1rem)]'
      : ''
    const values = vehicles.map(({ value }) => value)
    const cards = vehicles.map(({ data, value }, index) => modelViewer({
      presenter: this.presenter, data, value, comparing, idSuffix: index + 1, others: index === 0 ? [] : [vehicles[0].data], removePath: removePath(url, values, value)
    }))
    return html`<div class="tw:mt-8 tw:max-[500px]:mx-[calc(50%-50vw)] tw:max-[500px]:w-screen ${comparing
      ? 'tw:md:mx-[calc(50%-50vw)] tw:md:w-screen tw:md:px-4'
      : 'tw:lg:mx-[calc(50%-50vw)] tw:lg:w-screen tw:lg:px-4'}"><div class="tw:flex tw:flex-col tw:gap-8 ${comparing ? 'tw:md:flex-row tw:md:flex-wrap tw:md:justify-center' : 'tw:lg:flex-row tw:lg:justify-center'}
      ${baselineSolo}" data-controller="bikebook--wrapped-scroll">${cards}</div></div>`
  }
}

// This page's URL with the other vehicles picked
const removePath = (url, values, value) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), vehicle_models: values.filter((each) => each !== value).join(',') })
  return query ? `${url.pathname}?${query}` : url.pathname
}
