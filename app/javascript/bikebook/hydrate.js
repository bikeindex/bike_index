import { html } from 'lit-html'
import kit from 'bikebook/kit'
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
const FILTERS = [...LISTS, ...SINGLES, 'year_min', 'year_max', 'price_min', 'price_max', 'year_dir', 'price_dir']

const combobox = (root, name) => root.getElementById(`${name}-hw-hidden-field`).closest('.hw-combobox')

// The page at `url`: the shell, with the catalog's filter options, filled in from the URL
export async function hydrate (catalog, shell, url, standardWheelSizes) {
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
  const vehicles = (await catalog.vehicles(params.get('vehicle_models')?.split(',') ?? [])).slice(0, kit.max_compare)
  const values = vehicles.map(({ value }) => value).join(',')
  const { filteredCount } = await catalog.search(filters, 0, 0)

  const panel = root.querySelector('[data-controller~="bikebook--catalog-filters"]')
  for (const field of ['year', 'price']) {
    if (filters[`${field}_dir`] !== 'asc') continue

    panel.setAttribute(`data-bikebook--catalog-filters-${field}-dir-value`, 'asc')
    root.querySelector(`[data-bikebook--catalog-filters-target="${field}Arrow"]`).textContent = '↑'
  }
  renderInto(root.getElementById('vehicle-models-count'), matching(filteredCount, numberDisplay(filteredCount)))
  const manufacturers = catalog.options.manufacturer.length
  renderInto(root.getElementById('manufacturer-count'),
    html`(${numberDisplay(manufacturers)} ${tooltip({ text: `${manufacturers.toLocaleString('en-US')} manufacturers have models in the catalog` })})`)

  const query = toQuery({ ...filters, vehicle_models: values })
  combobox(root, 'vehicle_models').dataset.hwComboboxAsyncSrcValue = `${url.pathname}?${query ? `${query}&` : ''}for_id=vehicle_models`
  // The vehicle combobox lists from the catalog as it connects, so its lazy frame has nothing to fetch
  root.getElementById('vehicle_models__hw_combobox_pagination').remove()
  root.getElementById('vehicle_models-hw-hidden-field').setAttribute('value', values)

  for (const name of LISTS) root.getElementById(`${name}-hw-hidden-field`).setAttribute('value', filters[name])
  for (const name of SINGLES.filter((each) => filters[each])) {
    root.getElementById(`${name}-hw-hidden-field`).setAttribute('value', filters[name])
    const display = catalog.options[name].find(({ value }) => value === filters[name])?.display
    if (display) combobox(root, name).dataset.hwComboboxPrefilledDisplayValue = display
  }
  for (const bound of ['min', 'max']) {
    for (const name of ['year', 'price']) {
      if (filters[`${name}_${bound}`]) root.getElementById(`filter-${name}-${bound}`).setAttribute('value', filters[`${name}_${bound}`])
    }
  }

  renderInto(root.getElementById('vehicle-viewers'), new VehicleViewer(catalog.vocabulary, standardWheelSizes).render(vehicles, url))
  const [title] = await catalog.displays(vehicles.slice(0, 1).map(({ value }) => value))
  return { content: root, title }
}

// The comboboxes' requests, answered in the browser: the vehicle combobox's from the catalog,
// and the filter comboboxes' chips from their own options
export function wire (root, source) {
  localSources.set(combobox(root, 'vehicle_models'), source)
  for (const name of LISTS) {
    localSources.set(combobox(root, name), {
      chips: ({ element }, values) => renderChips(element, String(values).split(',').filter(Boolean).flatMap((value) => {
        const option = element.querySelector(`[role="option"][data-value="${CSS.escape(value)}"]`)
        return option ? [{ value, display: option.dataset.autocompletableAs }] : []
      }))
    })
  }
}
