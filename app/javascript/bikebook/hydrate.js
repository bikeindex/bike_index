import { html } from 'lit-html'
import { localSources } from 'utils/hw_combobox_patch'
import { matching, renderChips } from 'bikebook/catalog'
import { numberDisplay } from 'bikebook/templates/helpers'
import { filterOption } from 'bikebook/templates/filter_option'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { toQuery } from 'bikebook/query'
import { fragmentOf, renderInto } from 'bikebook/render'
import { VehicleViewer } from 'bikebook/vehicle_viewer'

/* global CSS */

const LISTS = ['primary_activity', 'manufacturer', 'vehicle_type']
const SINGLES = ['electric', 'suspension', 'model_configuration']
const RANGES = ['year_min', 'year_max', 'price_min', 'price_max']
const FILTERS = [...LISTS, ...SINGLES, ...RANGES, 'year_dir', 'price_dir']
// rather than the kit's max_compare, which the catalog publishes as 3
const MAX_COMPARE = 5

const combobox = (root, name) => root.getElementById(`${name}-hw-hidden-field`).closest('.hw-combobox')

// The page at `url`: the shell, with the catalog's filter options, filled in from the URL. Its
// comboboxes answer from the catalog: the vehicle combobox through `source`, the filters' chips
// from their own options
export async function hydrate (catalog, source, shell, url) {
  const { kit } = catalog
  const root = shell.content.cloneNode(true)
  const params = url.searchParams
  for (const name of [...LISTS, ...SINGLES]) root.getElementById(`${name}-hw-listbox`).append(fragmentOf(catalog.options[name].map(filterOption)))

  const filters = Object.fromEntries(FILTERS.map((name) => [name, params.get(name) ?? '']))
  // a renamed slug reads as its new one, and a value naming no option is dropped
  for (const name of LISTS) {
    const values = new Set(catalog.options[name].map(({ value }) => value))
    const slugs = filters[name].split(',').map((value) => kit.slug_aliases[name]?.[value] ?? value)
    filters[name] = [...new Set(slugs.filter((value) => values.has(value)))].join(',')
  }
  const [found, { filteredCount }] = await Promise.all([catalog.vehicles(params.get('vehicle_models')?.split(',') ?? []), catalog.search(filters, 0, 0)])
  const vehicles = found.slice(0, MAX_COMPARE)
  const values = vehicles.map(({ value }) => value).join(',')

  const panel = root.querySelector('[data-controller~="bikebook--catalog-filters"]')
  for (const field of ['year', 'price']) panel.setAttribute(`data-bikebook--catalog-filters-${field}-dir-value`, filters[`${field}_dir`] === 'asc' ? 'asc' : 'desc')
  renderInto(root.getElementById('vehicle-models-count'), matching(filteredCount))
  const manufacturers = catalog.options.manufacturer.length
  renderInto(root.getElementById('manufacturer-count'),
    html`(${numberDisplay(manufacturers)} ${tooltip({ text: `${manufacturers.toLocaleString('en-US')} manufacturers have models in the catalog` })})`)

  const query = toQuery({ ...filters, vehicle_models: values })
  combobox(root, 'vehicle_models').dataset.hwComboboxAsyncSrcValue = `${url.pathname}?${query ? `${query}&` : ''}for_id=vehicle_models`
  root.getElementById('vehicle_models-hw-hidden-field').setAttribute('value', values)
  for (const name of [...LISTS, ...SINGLES]) root.getElementById(`${name}-hw-hidden-field`).setAttribute('value', filters[name])
  for (const name of SINGLES) {
    const display = catalog.options[name].find(({ value }) => value === filters[name])?.display
    if (display) combobox(root, name).dataset.hwComboboxPrefilledDisplayValue = display
  }
  for (const name of RANGES) root.querySelector(`input[name="${name}"]`).setAttribute('value', filters[name])

  root.getElementById('comparison-view').setAttribute('aria-pressed', params.get('view') === 'comparison')
  renderInto(root.getElementById('vehicle-viewers'), new VehicleViewer(kit, catalog.vocabulary).render(vehicles, url))

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
