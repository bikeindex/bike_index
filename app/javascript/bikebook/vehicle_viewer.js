import { html, nothing } from 'lit-html'
import { basics } from 'bikebook/templates/vehicles/basics'
import { copyButton } from 'bikebook/templates/ui/copy_button'
import { chosenSizes, paramList, pickedSizes, sizesParam } from 'bikebook/sizes'
import { comparisonTable } from 'bikebook/templates/vehicles/comparison_table'
import { cycleDrawing } from 'bikebook/templates/vehicles/cycle_drawing'
import { emptyState } from 'bikebook/templates/vehicles/empty_state'
import { compareToggle, similarResults, similarSection } from 'bikebook/templates/vehicles/similar'
import { geometryOverlay, overlayFrames, seriesBorders } from 'bikebook/templates/vehicles/geometry_overlay'
import { jumpTo, VIEWS } from 'bikebook/templates/vehicles/jump_to'
import { modelCard } from 'bikebook/templates/vehicles/model_card'
import { removeLink } from 'bikebook/templates/vehicles/remove_link'
import { componentsOf, modelViewer, motorsOf, photoOf, runningGearOf, sizesOf } from 'bikebook/templates/vehicles/model_viewer'
import { array, present } from 'bikebook/templates/values'
import { searching, toQuery } from 'bikebook/query'
import { VehiclePresenter } from 'bikebook/vehicle_presenter'

// rather than the kit's max_compare, which the catalog publishes as 3
export const MAX_COMPARE = 5

// The compared vehicles' cards, from catalog blocks
export class VehicleViewer {
  // `jurisdiction`'s out of class marker, evc/out_of_class/us/ca, where its law bars a Class 3's throttle, as
  // EbikeRuleServices::StateLaws.out_of_class_ids has them
  constructor (kit, vocabulary, jurisdiction) {
    this.presenter = new VehiclePresenter(kit, vocabulary)
    const barred = Object.values(vocabulary.e_vehicle_classifications)
      .some((record) => record.jurisdiction === `US-${jurisdiction}` && record.class_3_throttle === false)
    this.outOfClassId = barred ? `evc/out_of_class/us/${jurisdiction.toLowerCase()}` : null
  }

  // The vehicles at `url` in the view it picks, whose links keep its other params, compared in the sizes it picks or
  // the nearest to the `preferredSize`. With none, the `search`'s count, whether filters narrow it, and its featured models.
  // `similar` puts the models most like the first above the views, its settings, and its `results` once they're scored
  render (vehicles, url, preferredSize, search, similar) {
    const { presenter, outOfClassId } = this
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
    const removePath = (value) => comparedPath(url, values.filter((each) => each !== value))
    const sizePath = (value) => (name) => pathWith(url, { vehicle_sizes: sizesParam(values, { ...picked, [value]: name }) })
    // a figure's letter lights it on each drawing, card and table row, until it's clicked again
    const highlight = url.searchParams.get('figure')
    const figurePath = (key) => pathWith(url, { figure: key === highlight ? '' : key })
    const compared = { presenter, vehicles, sizes, frames: overlayFrames(vehicles, sizes) }
    const rowClasses = comparing
      ? 'tw:justify-center-safe tw:overflow-x-auto tw:max-md:snap-x tw:max-md:snap-mandatory tw:max-md:px-4 tw:max-md:*:w-[85vw] tw:max-md:*:shrink-0 tw:max-md:*:snap-center'
      : 'tw:flex-col tw:lg:flex-row tw:lg:justify-center'
    const cardRow = (margin, cards, aligned = false) => html`<div ?data-comparison=${comparing} data-controller=${comparing && aligned ? 'bikebook--align-rows' : nothing} class="${margin} tw:max-[500px]:twpagebleed ${comparing
      ? 'tw:md:twpagebleed tw:md:px-4'
      : 'tw:lg:twpagebleed tw:lg:px-4'}"><div class="tw:flex tw:gap-8 ${rowClasses}">${cards}</div></div>`
    // each vehicle's `key` on a card of its own, named as its full card is, after whatever `lead` shows, with the overview's ×
    // `keyed`, each topped in its frame's color in the overlay
    const cards = (key, none, content, { lead, keyed = false } = {}) => vehicles.map(({ data, value }, index) => {
      const { manufacturer, model } = presenter.named(presenter.kit.schemas.vehicle, data)
      const name = [manufacturer, model].filter(present).join(' ')
      return html`<section aria-label=${`${name} ${key}`} class="twgutter tw:relative tw:w-full tw:min-w-0 tw:space-y-4
        tw:rounded-sm tw:border tw:border-gray-200 tw:bg-white tw:pt-4 tw:pb-6 tw:[--gutter:--spacing(6)] tw:dark:border-gray-700 tw:dark:bg-gray-800
        ${keyed ? seriesBorders(compared.frames, index).top : ''} ${comparing ? 'tw:md:max-w-[56rem] tw:lg:flex-1' : 'tw:lg:w-[56rem] tw:lg:shrink-0'}">${removeLink({
        label: `Remove ${name}`,
        href: removePath(value),
        corner: true
      })}<header data-align-row="header" class="tw:flex tw:items-start tw:justify-between tw:gap-4"><div>${present(manufacturer)
        ? html`<p class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p>`
        : nothing}<div class="tw:text-2xl tw:leading-tight"><h3 class="tw:inline tw:font-extrabold">${model}</h3> ${
          copyButton({ value, label: 'Copy ID', tooltip: true })}</div></div><div
        class="tw:shrink-0">${photoOf({ presenter, data }, 'tw:h-14 tw:w-21')}</div></header>${lead ? html`<div data-align-row="lead">${lead(data, value)}</div>` : nothing}${present(data[key])
        ? content(data, value)
        : html`<p class="twless-strong">${none}</p>`}</section>`
    })
    // its type's drawing of `size`, said where it works figures out or takes a typical one's: its `typicalKind`'s where
    // they're all that kind of bike's
    const drawing = (data, size, { figure, legend, typicalKind }) => {
      const notes = [legend.some(({ calculated }) => calculated) && 'Light purple figures are calculated from the listed ones.',
        legend.some(({ listed, calculated }) => !listed && !calculated) &&
          `Gray figures aren't listed, so they're estimated from ${typicalKind ? 'typical' : 'average'} values on ${typicalKind ?? typeName(presenter, data).toLowerCase()}s.`]
        .filter(Boolean)
      return html`<figure class="tw:space-y-1"><div class="tw:mx-auto tw:max-w-xl tw:text-gray-800 tw:dark:text-gray-200">${figure}</div>${notes.length
        ? html`<figcaption class="tw:text-center tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">${present(size?.name) && array(data.sizes).length > 1 ? `${size.name} drawn. ` : ''}${notes.join(' ')}</figcaption>`
        : nothing}</figure>`
    }
    // drawn only where its size lists some of its frame: overall dimensions, wheels and a cargo area alone would be all
    // it drew of its own
    const framed = (legend) => legend.some(({ letter, listed, editable, extra, key }) => letter && listed && editable && !extra && !key.startsWith('dimensions'))
    // each one's drawing, those drawn at the largest's scale and on the same ground, so they line up across the cards
    const sizeDrawings = () => {
      const draw = (index, options) => cycleDrawing({ type: vehicles[index].data.type, data: vehicles[index].data, size: sizes[index], kit: presenter.kit, highlight, figurePath, ...options })
      const own = vehicles.map((_, index) => draw(index))
      const shown = own.filter(({ legend }) => framed(legend))
      if (shown.length < 2) return own
      const span = Math.max(...shown.map((each) => each.span))
      const scaled = own.map((each, index) => framed(each.legend) && each.span !== span ? draw(index, { span }) : each)
      const bounds = scaled.filter(({ legend }) => framed(legend)).map((each) => each.bounds)
      const box = { width: Math.max(...bounds.map(({ left, right }) => right - left)), top: Math.max(...bounds.map(({ top }) => top)), bottom: Math.min(...bounds.map(({ bottom }) => bottom)) }
      return scaled.map((each) => framed(each.legend) ? { ...each, figure: each.within(box) } : each)
    }
    const views = {
      // the overlay while the similar models are open, each column's bottom in its frame's color
      basics: () => {
        if (!comparing || similar?.results === undefined) return basics({ presenter, vehicles, outOfClassId, removePath })
        const bottoms = vehicles.map((_, index) => {
          const { variable } = seriesBorders(compared.frames, index)
          return variable && `${variable} tw:similar-open:border-b-4 tw:similar-open:border-b-(--series)!`
        })
        // the overlay left of the table once the window is wide, as Sizes & geometry's is, beneath it until then
        return html`<div class="tw:flex tw:flex-col tw:min-[1500px]:similar-open:twpagebleed tw:min-[1500px]:similar-open:flex-row
          tw:min-[1500px]:similar-open:items-start tw:min-[1500px]:similar-open:gap-6 tw:min-[1500px]:similar-open:px-4">${basics({
          presenter,
          vehicles,
          outOfClassId,
          removePath,
          bottoms,
          sectionClasses: 'tw:min-[1500px]:similar-open:mx-0 tw:min-[1500px]:similar-open:w-auto tw:min-[1500px]:similar-open:min-w-0 ' +
            'tw:min-[1500px]:similar-open:flex-1 tw:min-[1500px]:similar-open:px-0'
        })}<div class="tw:hidden tw:similar-open:contents">${geometryOverlay({
          ...compared, selected: url.searchParams.get('overlay_selected'), beside: true
        })}</div></div>`
      },
      // the overlay beside the table once the window is wide, above it until then
      geometry: () => {
        const drawings = sizeDrawings()
        return html`<div class="tw:flex tw:flex-col tw:min-[1500px]:twpagebleed tw:min-[1500px]:flex-row
        tw:min-[1500px]:items-start tw:min-[1500px]:gap-6 tw:min-[1500px]:px-4">${geometryOverlay({ ...compared, selected: url.searchParams.get('overlay_selected'), beside: true })}${
        comparisonTable({ ...compared, highlight, beside: true })}</div>${cardRow('tw:mt-6', cards('sizes', 'No sizes listed', (data, value) => {
        const size = sizes[values.indexOf(value)]
        const drawn = drawings[values.indexOf(value)]
        const { legend } = drawn
        return html`${framed(legend) ? drawing(data, size, drawn) : nothing}<div class="tw:-mx-(--gutter)">${sizesOf({
          presenter,
          data,
          others: others(value),
          selectedSize: selectedSizes.get(value),
          sizePath: sizePath(value),
          lettering: framed(legend) && {
            letters: new Map(legend.filter(({ letter }) => letter).map(({ key, letter }) => [key, letter])),
            highlight,
            figurePath,
            drawn: { id: value, name: size?.name, figures: legend.filter(({ letter, listed }) => letter && !listed) }
          }
        })}</div>`
      }, { keyed: true }))}`
      },
      components: () => {
        const components = componentsOf({ presenter, vehicles, others })
        return cardRow('tw:mt-6', cards('components', 'No components listed', (data, value) => components.get(value),
          { lead: (data, value) => runningGearOf({ presenter, data, others: others(value) }) }), true)
      },
      motors: () => cardRow('tw:mt-6', cards('motors', 'No motor', (data, value) => motorsOf({ presenter, data, others: others(value), outOfClassId }))),
      all: () => {
        const full = vehicles.map(({ data, value }, index) => modelViewer({
          presenter, data, value, comparing, idSuffix: index + 1, others: others(value), removePath: removePath(value), selectedSize: selectedSizes.get(value), sizePath: sizePath(value), outOfClassId
        }))
        return cardRow('tw:mt-6', full)
      }
    }
    // a model opened alone, its search hidden, has a tab to show it filtered to its type: "Search other cargo bikes"
    const lone = !searching(url) && vehicles.length === 1 && vehicles[0].data
    const searchTab = lone && {
      label: `Search other ${typeName(presenter, lone).toLowerCase()}s`,
      href: pathWith(url, { search: '1', vehicle_type: lone.type || 'bike' })
    }
    const similarModels = similar
      ? similarSection({
        vehicle: baseline.value,
        model: modelName(presenter, baseline.data),
        type: typeName(presenter, baseline.data).toLowerCase(),
        vehicleType: baseline.data.type,
        electric: present(baseline.data.motors),
        settings: similar,
        groups: similar.results?.groups,
        results: similar.results === undefined ? undefined : this.similarResults(url, similar.results),
        searchShown: searching(url)
      })
      : nothing
    return html`${similarModels}${jumpTo(view, (each) => pathWith(url, { view: each === 'basics' ? '' : each }), shown, searchTab)}${views[view]()}`
  }

  // What opens the models most like the first of `vehicles` from the search's More filters lines, where `similar` offers them
  compareToggle (vehicles, similar) {
    if (!similar) return nothing
    return compareToggle({ type: typeName(this.presenter, vehicles[0].data).toLowerCase(), model: modelName(this.presenter, vehicles[0].data) })
  }

  // The cards of the models most like the first at `url`, each a link adding it to the comparison there or taking it out,
  // which renders in place, focusing it again
  similarResults (url, results) {
    const { kit, vocabulary } = this.presenter
    const values = paramList(url, 'vehicle_models').filter(Boolean)
    const full = values.length >= MAX_COMPARE && MAX_COMPARE
    const cards = results?.models.map((model) => {
      const active = values.includes(model.id)
      const next = active ? values.filter((value) => value !== model.id) : [...values, model.id]
      const id = `similar-${model.id.replaceAll('/', '-')}`
      return modelCard({
        model,
        href: active || !full ? comparedPath(url, next) : null,
        placeholderUrl: kit.placeholder_url,
        currencies: vocabulary.currencies,
        toggle: true,
        active,
        attributes: { id, 'data-in-place': `#${id}` }
      })
    })
    return similarResults({ results, cards, full })
  }
}

// This page's URL with `params` laid over its own
const pathWith = (url, params) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), ...params })
  return query ? `${url.pathname}?${query}` : url.pathname
}
const typeName = (presenter, data) => presenter.named(presenter.kit.schemas.vehicle, data).type || 'bike'
const modelName = (presenter, data) => presenter.named(presenter.kit.schemas.vehicle, data).model
// comparing `ids`, each picked size following its vehicle
const comparedPath = (url, ids) => pathWith(url, { vehicle_models: ids.join(','), vehicle_sizes: sizesParam(ids, pickedSizes(url)) })
