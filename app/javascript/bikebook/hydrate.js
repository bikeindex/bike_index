import { html } from 'lit-html'
import { localSources } from 'utils/hw_combobox_patch'
import { renderChips, renderCounts } from 'bikebook/catalog'
import { numberDisplay } from 'bikebook/templates/helpers'
import { filterOption } from 'bikebook/templates/filter_option'
import { pickedClassifications, renderClassCards } from 'bikebook/templates/vehicles/class_cards'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { FILTERS, LISTS, RANGES, SINGLES, searching, toQuery } from 'bikebook/query'
import { fragmentOf, renderInto } from 'bikebook/render'
import { preferredSize } from 'bikebook/sizes'
import { VehicleViewer } from 'bikebook/vehicle_viewer'

/* global CSS */

// rather than the kit's max_compare, which the catalog publishes as 3
const MAX_COMPARE = 10

const combobox = (root, name) => root.getElementById(`${name}-hw-hidden-field`).closest('.hw-combobox')
const panelOf = (root) => root.querySelector('[data-controller~="bikebook--catalog-filters"]')
const MARKET_ATTRIBUTE = 'data-bikebook--catalog-filters-default-market-value'
const JURISDICTION_ATTRIBUTE = 'data-bikebook--catalog-filters-default-jurisdiction-value'

// The fields as `filters` set them, none of which needs the catalog
const fillFields = (root, filters) => {
  panelOf(root).setAttribute('data-bikebook--catalog-filters-sort-value', filters.sort === 'price' ? 'price' : 'year')
  for (const field of ['year', 'price']) panelOf(root).setAttribute(`data-bikebook--catalog-filters-${field}-dir-value`, filters[`${field}_dir`] === 'asc' ? 'asc' : 'desc')
  for (const name of [...LISTS, ...SINGLES]) root.getElementById(`${name}-hw-hidden-field`).setAttribute('value', filters[name])
  for (const name of RANGES) root.querySelector(`input[name="${name}"]`).setAttribute('value', filters[name])
  const { jurisdiction } = filters
  const state = root.querySelector(`#jurisdiction-hw-listbox [role="option"][data-value="${CSS.escape(jurisdiction)}"]`)
  if (state) {
    root.getElementById('jurisdiction-hw-hidden-field').setAttribute('value', jurisdiction)
    combobox(root, 'jurisdiction').dataset.hwComboboxPrefilledDisplayValue = state.dataset.autocompletableAs
  }
  // evc/out_of_class is in a state's classes as well as the US ones; the jurisdiction's hidden ones uncheck on connecting
  for (const value of filters.electric.split(',')) root.querySelectorAll(`input[name="electric"][value="${CSS.escape(value)}"]`).forEach((input) => input.setAttribute('checked', ''))
}

// The e-bike classes legal where the visitor is. In the US, the electric filter's values for those of the jurisdiction the
// filters pick or the visitor is in, whose checkboxes are the US's for a state without its own; elsewhere the market's
// e-bike law, none where the catalog has none
const legalClasses = (root, filters, { e_vehicle_classifications: classifications }) => {
  if (filters.market && filters.market !== 'US') {
    return Object.keys(classifications).filter((id) => classifications[id].e_bike_law && classifications[id].jurisdiction === filters.market)
  }
  const classes = root.querySelector(`[data-jurisdiction="${CSS.escape(filters.jurisdiction)}"]`) ?? root.querySelector('[data-jurisdiction="US"]')
  return [...classes.querySelectorAll('input[name="electric"]')].map(({ value }) => value).filter((value) => value !== 'evc/out_of_class')
}

// `url`'s filters, "all" markets as Any, without which it and the jurisdiction - a state's abbreviation, or US - are the
// panel's defaults
const urlFilters = (root, url) => {
  const filters = Object.fromEntries(FILTERS.map((name) => [name, url.searchParams.get(name) ?? '']))
  return {
    ...filters,
    market: filters.market === 'all' ? '' : filters.market || panelOf(root).getAttribute(MARKET_ATTRIBUTE),
    jurisdiction: filters.jurisdiction || panelOf(root).getAttribute(JURISDICTION_ATTRIBUTE)
  }
}

// as the catalog reads them: a renamed slug as its new one, and a value naming no option dropped
const filtersAt = ({ kit, options }, root, url) => {
  const filters = urlFilters(root, url)
  return {
    ...filters,
    ...Object.fromEntries(LISTS.map((name) => {
      const values = new Set(options[name].map(({ value }) => value))
      const slugs = filters[name].split(',').map((value) => kit.slug_aliases[name]?.[value] ?? value)
      return [name, [...new Set(slugs.filter((value) => values.has(value)))].join(',')]
    }))
  }
}

// With nothing picked, the `count` of models `filters` leave, the ones featured, and whether filters narrow it
const unpicked = async (catalog, root, filters) => ({
  ...await catalog.featured(filters, legalClasses(root, filters, catalog.vocabulary)),
  // the market narrows every visitor's search, so it's no filter of theirs
  filtered: [...LISTS, ...SINGLES, ...RANGES, 'electric'].some((name) => name !== 'market' && filters[name])
})

// The vehicles' place with nothing picked, for `url`'s filters, which change in `page` without rendering it afresh
export async function unpickedVehicles (catalog, page, url) {
  return new VehicleViewer(catalog.kit, catalog.vocabulary).render([], url, null, await unpicked(catalog, page, filtersAt(catalog, page, url)))
}

const pickedOf = (catalog, url, { market }) => catalog.vehicles(url.searchParams.get('vehicle_models')?.split(',') ?? [], { market })

// the model group `url`'s overview shows, of one of its vehicles
const groupOf = (catalog, url) => {
  const id = url.searchParams.get('group')
  const view = url.searchParams.get('view')
  const picked = url.searchParams.get('vehicle_models')?.split(',').slice(0, MAX_COMPARE) ?? []
  return picked.includes(id) && (!view || view === 'basics') ? catalog.group(id) : null
}

// The picked vehicles' place for `url`'s jurisdiction, which decides which are out of class there, and market, which
// which are sold elsewhere
export async function pickedVehicles (catalog, page, url) {
  const filters = filtersAt(catalog, page, url)
  const [found, group] = await Promise.all([pickedOf(catalog, url, filters), groupOf(catalog, url)])
  return new VehicleViewer(catalog.kit, catalog.vocabulary, filters.jurisdiction).render(found.slice(0, MAX_COMPARE), url, preferredSize(), {}, group)
}

// The page at `url` while the catalog loads: its filters live and filled in from the URL, their values as it has them, and
// its comboboxes, whose options are the catalog's, disabled. `status` stands in for the vehicles
export function loadingShell (shell, url, status) {
  const root = shell.content.cloneNode(true)
  const panel = panelOf(root)
  panel.hidden = !searching(url)
  const filters = urlFilters(root, url)
  fillFields(root, filters)
  // one holding what only the catalog names, rather than the Any it isn't
  for (const name of ['vehicle_models', ...LISTS, ...SINGLES].filter((each) => filters[each] ?? url.searchParams.get(each))) {
    const field = combobox(root, name)
    const input = field.querySelector('.hw-combobox__input')
    field.dataset.hwComboboxPrefilledDisplayValue = ''
    input.placeholder = panel.dataset.loadingPlaceholder
    input.dataset.awaitingCatalog = ''
  }
  for (const field of root.querySelectorAll('.hw-combobox')) {
    field.inert = true
    field.querySelector('.hw-combobox__input').disabled = true
    // the catalog names its chips and answers its searches once it's in, rather than the server
    localSources.set(field, { chips: () => {}, filter: () => {} })
  }
  root.getElementById('vehicle-viewers').append(status)
  return root
}

// The page at `url`: the shell, with the catalog's filter options, filled in from the URL. Its
// comboboxes answer from the catalog: the vehicle combobox through `source`, the filters' chips
// from their own options
export async function hydrate (catalog, source, shell, url) {
  const { kit } = catalog
  const root = shell.content.cloneNode(true)
  panelOf(root).hidden = !searching(url)
  for (const name of [...LISTS, ...SINGLES]) root.getElementById(`${name}-hw-listbox`).append(fragmentOf(catalog.options[name].map(filterOption)))

  // the visitor's country, when it's a market with models
  const panel = panelOf(root)
  const located = panel.getAttribute(MARKET_ATTRIBUTE)
  panel.setAttribute(MARKET_ATTRIBUTE, catalog.options.market.some(({ value }) => value === located) ? located : '')
  const filters = filtersAt(catalog, root, url)
  const [found, { filteredCount }, group] = await Promise.all([pickedOf(catalog, url, filters), catalog.search(filters, 0, 0), groupOf(catalog, url)])
  const vehicles = found.slice(0, MAX_COMPARE)
  const classifications = catalog.vocabulary.e_vehicle_classifications
  const cards = pickedClassifications(url, classifications)
  const values = [...vehicles.map(({ value }) => value), ...cards].join(',')

  renderCounts(root, filteredCount)
  const manufacturers = catalog.options.manufacturer.length
  renderInto(root.getElementById('manufacturer-count'),
    html`(${numberDisplay(manufacturers)} ${tooltip({ text: `${manufacturers.toLocaleString('en-US')} manufacturers have models in the catalog` })})`)

  const query = toQuery({ ...filters, vehicle_models: values })
  combobox(root, 'vehicle_models').dataset.hwComboboxAsyncSrcValue = `${url.pathname}?${query ? `${query}&` : ''}for_id=vehicle_models`
  root.getElementById('vehicle_models-hw-hidden-field').setAttribute('value', values)
  // chipped before it's shown, rather than once the combobox asks the worker, which would leave the field bare a frame
  renderChips(combobox(root, 'vehicle_models'), [...vehicles.filter(({ display }) => display != null),
    ...cards.map((value) => ({ value, display: classifications[value].label }))])
  fillFields(root, filters)
  renderClassCards(root, cards, classifications)
  for (const name of SINGLES) {
    const display = catalog.options[name].find(({ value }) => value === filters[name])?.display
    if (display) combobox(root, name).dataset.hwComboboxPrefilledDisplayValue = display
  }

  const viewer = new VehicleViewer(kit, catalog.vocabulary, filters.jurisdiction)
  for (const input of root.querySelectorAll('input[name="electric"]')) {
    const id = input.value.replace(/^class_/, 'evc/us/class_')
    const classification = catalog.vocabulary.e_vehicle_classifications[id]
    // a marker's checkbox has the page's own tooltip
    if (classification && !classification.marker) input.closest('label').after(fragmentOf(tooltip({ text: classification.title, body: viewer.presenter.classificationTooltip(id) })))
  }

  renderInto(root.getElementById('vehicle-viewers'), viewer.render(vehicles, url, preferredSize(),
    vehicles.length ? {} : await unpicked(catalog, root, filters), group))

  localSources.set(combobox(root, 'vehicle_models'), source)
  for (const name of LISTS) {
    localSources.set(combobox(root, name), {
      chips: ({ element }, chosen) => renderChips(element, String(chosen).split(',').filter(Boolean).flatMap((value) => {
        const option = element.querySelector(`[role="option"][data-value="${CSS.escape(value)}"]`)
        return option ? [{ value, display: option.dataset.autocompletableAs }] : []
      }))
    })
  }
  return { content: root, title: vehicles[0]?.display }
}
