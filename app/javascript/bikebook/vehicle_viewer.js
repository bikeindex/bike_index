import { html, nothing } from 'lit-html'
import { basics } from 'bikebook/templates/vehicles/basics'
import { withColorwayPhoto } from 'bikebook/colorways'
import { chosenSizes, paramList, pickedColorways, pickedSizes, sizesParam, vehicleKeys } from 'bikebook/sizes'
import { comparisonTable } from 'bikebook/templates/vehicles/comparison_table'
import { cycleDrawing } from 'bikebook/templates/vehicles/cycle_drawing'
import { emptyState } from 'bikebook/templates/vehicles/empty_state'
import { compareToggle, similarAdjustments, similarResults, similarSection } from 'bikebook/templates/vehicles/similar'
import { geometryOverlay, overlayFrames, overlayOpener, seriesBorders } from 'bikebook/templates/vehicles/geometry_overlay'
import { jumpTo, VIEWS } from 'bikebook/templates/vehicles/jump_to'
import { modelCard } from 'bikebook/templates/vehicles/model_card'
import { modelGroup } from 'bikebook/templates/vehicles/model_group'
import { removeLink } from 'bikebook/templates/vehicles/remove_link'
import { vehicleTitle } from 'bikebook/templates/vehicles/vehicle_title'
import { componentsOf, modelViewer, motorsOf, photoOf, runningGearOf, sizesOf } from 'bikebook/templates/vehicles/model_viewer'
import { array, present } from 'bikebook/templates/values'
import { searching, toQuery } from 'bikebook/query'
import { VehiclePresenter } from 'bikebook/vehicle_presenter'

// rather than the kit's max_compare, which the catalog publishes as 3
export const MAX_COMPARE = 10

// The compared vehicles' cards, from catalog blocks
export class VehicleViewer {
  // `jurisdiction`'s out of class marker, evc/out_of_class/us/ca, where its law bars a Class 3's throttle, as
  // EbikeRuleServices::StateLaws.out_of_class_ids has them. Model cards name the markets of those `market` doesn't sell
  constructor (kit, vocabulary, { jurisdiction, market } = {}) {
    this.presenter = new VehiclePresenter(kit, vocabulary)
    const barred = Object.values(vocabulary.e_vehicle_classifications)
      .some((record) => record.jurisdiction === `US-${jurisdiction}` && record.class_3_throttle === false)
    this.outOfClassId = barred ? `evc/out_of_class/us/${jurisdiction.toLowerCase()}` : null
    this.card = { placeholderUrl: kit.placeholder_url, currencies: vocabulary.currencies, market, configurations: kit.model_configurations }
  }

  // The vehicles at `url` in the view it picks, each under its key, whose links keep its other params, compared in the
  // sizes it picks or the nearest to the `preferredSize`, the overview over the `group` it shows. With none, the
  // `search`'s count, whether filters narrow it, and its featured models. `similar` puts the models most like the first
  // above the views, its settings, and its `results` once they're scored
  render (picks, url, preferredSize, search, { group = null, similar } = {}) {
    const { presenter, outOfClassId } = this
    const values = picks.map(({ value }) => value)
    const keys = vehicleKeys(values)
    // each showing its chosen colorway's photo everywhere it's pictured, its card among the group's and similar models' too
    const vehicles = withChosenPhotos(url, picks)
    const photos = pickedPhotos(vehicles)
    const colorways = pickedColorways(url)
    if (vehicles.length === 0) {
      return emptyState({
        url,
        vehiclePath: (id) => pathWith(url, { vehicle_models: id }),
        ...this.card,
        ...search
      })
    }

    const shown = Object.keys(VIEWS).filter((each) => each !== 'motors' || vehicles.some(({ data }) => present(data.motors)))
    const requested = url.searchParams.get('view')
    const view = shown.includes(requested) ? requested : 'basics'
    const comparing = vehicles.length > 1
    const picked = pickedSizes(url)
    const sizes = chosenSizes(vehicles, { picked, preferred: preferredSize })
    const selectedSizes = new Map(vehicles.map(({ key }, index) => [key, sizes[index]?.name]))
    const baseline = vehicles[0]
    const others = (key) => key === baseline.key ? [] : [baseline.data]
    // without the vehicle at `index`, the others' picked sizes and colorways following them
    const removePath = (index) => {
      const without = (list) => list.filter((_, each) => each !== index).join(',')
      const remaining = (chosen) => without(keys.map((each) => chosen[each] ?? '')).replace(/,+$/, '')
      return pathWith(url, { vehicle_models: without(values), vehicle_sizes: remaining(picked), vehicle_colorways: remaining(colorways) })
    }
    const sizePath = (key) => (name) => pathWith(url, { vehicle_sizes: sizesParam(values, { ...picked, [key]: name }) })
    // a figure's letter lights it on each drawing, card and table row, until it's clicked again
    const highlight = url.searchParams.get('figure')
    const figurePath = (key) => pathWith(url, { figure: key === highlight ? '' : key })
    const compared = { presenter, vehicles, sizes, frames: overlayFrames(vehicles, sizes), market: this.card.market }
    const rowClasses = comparing
      ? 'tw:justify-center-safe tw:overflow-x-auto tw:max-md:snap-x tw:max-md:snap-mandatory tw:max-md:px-4 tw:max-md:*:w-[85vw] tw:max-md:*:shrink-0 tw:max-md:*:snap-center'
      : 'tw:flex-col tw:lg:flex-row tw:lg:justify-center'
    const cardRow = (margin, cards, aligned = false) => html`<div ?data-comparison=${comparing} data-controller=${comparing && aligned ? 'bikebook--align-rows' : nothing} class="${margin} tw:max-[500px]:twpagebleed ${comparing
      ? 'tw:md:twpagebleed tw:md:px-4'
      : 'tw:lg:twpagebleed tw:lg:px-4'}"><div class="tw:flex tw:gap-8 ${rowClasses}">${cards}</div></div>`
    // each vehicle's `field` on a card of its own, named as its full card is, after whatever `lead` shows, with the overview's ×
    // `keyed`, each topped in its frame's color in the overlay
    const cards = (field, none, content, { lead, keyed = false } = {}) => vehicles.map(({ data, value, key }, index) => {
      const { manufacturer, model } = presenter.named(presenter.kit.schemas.vehicle, data)
      const name = [manufacturer, model].filter(present).join(' ')
      return html`<section aria-label=${`${name} ${field}`} class="twgutter tw:relative tw:w-full tw:min-w-0 tw:space-y-4
        tw:rounded-sm tw:border tw:border-gray-200 tw:bg-white tw:pt-4 tw:pb-6 tw:[--gutter:--spacing(6)] tw:dark:border-gray-700 tw:dark:bg-gray-800
        ${keyed ? seriesBorders(compared.frames, index).top : ''} ${comparing ? 'tw:md:max-w-[56rem] tw:lg:flex-1' : 'tw:lg:w-[56rem] tw:lg:shrink-0'}">${removeLink({
        label: `Remove ${name}`,
        href: removePath(index),
        corner: true
      })}<header data-align-row="header" class="tw:flex tw:items-start tw:justify-between tw:gap-4"><div>${
        vehicleTitle({ manufacturer, model, data, value, ...this.card, heading: 'h3' })}</div><div
        class="tw:shrink-0">${photoOf({ presenter, data }, 'tw:h-14 tw:w-21')}</div></header>${lead ? html`<div data-align-row="lead">${lead(data, key)}</div>` : nothing}${present(data[field])
        ? content(data, key, index)
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
    // the overlay left of the `table` once the window is wide, beneath it until then or `above`, which closes to a button in the
    // table's corner
    const withOverlay = (table, above = false) => {
      const open = url.searchParams.get('overlay') !== '0'
      const parts = [geometryOverlay({ ...compared, selected: url.searchParams.get('overlay_selected'), open, beside: true }), table(overlayOpener(open))]
      return html`<div class="tw:flex tw:flex-col tw:min-[1500px]:twpagebleed tw:min-[1500px]:flex-row tw:min-[1500px]:items-start tw:min-[1500px]:gap-6
        tw:min-[1500px]:px-4" data-controller="ui--collapse" data-ui--collapse-param-value="overlay" data-ui--collapse-direction-value="horizontal">${
        above ? parts : parts.toReversed()}</div>`
    }
    const views = {
      // comparing, the overlay, each column's bottom in its frame's color
      basics: () => {
        const overview = { presenter, vehicles, market: this.card.market, outOfClassId, removePath, colorways, groupPath: (value) => pathWith(url, { group: value }), shownGroup: group && url.searchParams.get('group') }
        const groupModels = group ? modelGroup({ group, card: (model) => this.#toggleCard(url, model, 'group', photos) }) : nothing
        if (!comparing) return html`${basics(overview)}${groupModels}`
        const bottoms = vehicles.map((_, index) => {
          const { variable } = seriesBorders(compared.frames, index)
          return variable && `${variable} tw:border-b-4 tw:border-b-(--series)!`
        })
        return html`${withOverlay((corner) => basics({
          ...overview,
          bottoms,
          corner,
          sectionClasses: 'tw:min-[1500px]:mx-0 tw:min-[1500px]:w-auto tw:min-[1500px]:min-w-0 tw:min-[1500px]:flex-1 tw:min-[1500px]:px-0'
        }))}${groupModels}`
      },
      geometry: () => {
        const drawings = sizeDrawings()
        return html`${withOverlay((corner) => comparisonTable({ ...compared, highlight, beside: true, corner }), true)}${cardRow('tw:mt-6', cards('sizes', 'No sizes listed', (data, key, index) => {
        const size = sizes[index]
        const drawn = drawings[index]
        const { legend } = drawn
        return html`${framed(legend) ? drawing(data, size, drawn) : nothing}<div class="tw:-mx-(--gutter)">${sizesOf({
          presenter,
          data,
          others: others(key),
          selectedSize: selectedSizes.get(key),
          sizePath: sizePath(key),
          lettering: framed(legend) && {
            letters: new Map(legend.filter(({ letter }) => letter).map(({ key, letter }) => [key, letter])),
            highlight,
            figurePath,
            drawn: { id: key, name: size?.name, figures: legend.filter(({ letter, listed }) => letter && !listed) }
          }
        })}</div>`
      }, { keyed: true }))}`
      },
      components: () => {
        const components = componentsOf({ presenter, vehicles, others })
        return cardRow('tw:mt-6', cards('components', 'No components listed', (data, key) => components.get(key),
          { lead: (data, key) => runningGearOf({ presenter, data, others: others(key) }) }), true)
      },
      motors: () => cardRow('tw:mt-6', cards('motors', 'No motor', (data, key) => motorsOf({ presenter, data, others: others(key), outOfClassId }))),
      all: () => {
        const full = vehicles.map(({ data, value, key }, index) => modelViewer({
          presenter, data, value, market: this.card.market, comparing, idSuffix: index + 1, others: others(key), removePath: removePath(index), selectedSize: selectedSizes.get(key), sizePath: sizePath(key), outOfClassId
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
        ...this.#similarOf(baseline, similar),
        model: modelName(presenter, baseline.data),
        results: similar.results === undefined ? undefined : this.similarResults(url, similar.results, photos),
        searchShown: searching(url)
      })
      : nothing
    return html`${similarModels}${jumpTo(view, (each) => pathWith(url, { view: each === 'basics' ? '' : each }), shown, searchTab)}${views[view]()}`
  }

  // The controls that rescore the models most like the first of `vehicles`, for the filters' card
  similarAdjustments (vehicles, similar) {
    return similar && vehicles.length ? similarAdjustments(this.#similarOf(vehicles[0], similar)) : nothing
  }

  #similarOf ({ value, data, current }, similar) {
    return {
      vehicle: value,
      current,
      type: typeName(this.presenter, data).toLowerCase(),
      complete: (data.model_configuration ?? 'complete') === 'complete',
      settings: similar,
      groups: similar.results?.groups,
      scored: similar.results !== undefined
    }
  }

  // What opens the models most like the first of `vehicles` from the search's More filters lines, where `similar` offers them
  compareToggle (vehicles, similar) {
    if (!similar) return nothing
    return compareToggle({ type: typeName(this.presenter, vehicles[0].data).toLowerCase(), model: modelName(this.presenter, vehicles[0].data) })
  }

  // The cards of the models most like the first at `url`, those it compares showing `photos`' photo of them
  similarResults (url, results, photos) {
    const full = paramList(url, 'vehicle_models').filter(Boolean).length >= MAX_COMPARE && MAX_COMPARE
    return similarResults({ results, cards: results?.models.map((model) => this.#toggleCard(url, model, 'similar', photos)), full })
  }

  // `model`'s card, a link adding it to the comparison at `url` or taking it out, which renders in place, focusing it again
  #toggleCard (url, model, idPrefix, photos) {
    const values = paramList(url, 'vehicle_models').filter(Boolean)
    const active = values.includes(model.id)
    const next = active ? values.filter((value) => value !== model.id) : [...values, model.id]
    const id = `${idPrefix}-${model.id.replaceAll('/', '-')}`
    return modelCard({
      model: photos.has(model.id) ? { ...model, stock_photo: photos.get(model.id) } : model,
      href: active || values.length < MAX_COMPARE ? comparedPath(url, next) : null,
      ...this.card,
      toggle: true,
      active,
      attributes: { id, 'data-in-place': `#${id}` }
    })
  }
}

// Each of the `picks` at `url` keyed, its photo its chosen colorway's where it has one
export const withChosenPhotos = (url, picks) => {
  const colorways = pickedColorways(url)
  const keys = vehicleKeys(picks.map(({ value }) => value))
  return picks.map((pick, index) => ({ ...pick, key: keys[index], data: pick.data && withColorwayPhoto(pick.data, colorways[keys[index]]) }))
}

// Each of the `vehicles` compared's photo, by its id
export const pickedPhotos = (vehicles) => new Map(vehicles.filter(({ data }) => present(data?.stock_photo)).map(({ value, data }) => [value, data.stock_photo]))

// This page's URL with `params` laid over its own
const pathWith = (url, params) => {
  const query = toQuery({ ...Object.fromEntries(url.searchParams), ...params })
  return query ? `${url.pathname}?${query}` : url.pathname
}
const typeName = (presenter, data) => presenter.named(presenter.kit.schemas.vehicle, data).type || 'bike'
const modelName = (presenter, data) => presenter.named(presenter.kit.schemas.vehicle, data).model
// comparing `ids`, each picked size following its vehicle
const comparedPath = (url, ids) => pathWith(url, {
  vehicle_models: ids.join(','), vehicle_sizes: sizesParam(ids, pickedSizes(url)), vehicle_colorways: sizesParam(ids, pickedColorways(url))
})
