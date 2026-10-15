import { html, nothing } from 'lit-html'
import { uuid } from 'bikebook/templates/helpers'
import { renderInto } from 'bikebook/render'

const PARAM = 'classifications'

// A classification's /ebike-rules card: a US class's number, or the e-moto's for one that's no e-bike law, as the
// Overview's tiles have them. None for an e-bike law, which /ebike-rules has no card for
export const cardOf = (id, classifications) =>
  id.match(/^evc\/us\/class_(\d)$/)?.[1] ?? (classifications[id] && !classifications[id].e_bike_law ? 'emoto' : null)

export const cardLabel = (id, classifications) => classifications[id]?.label

// A search that's a classification's exact ID offers it, unless it's `selected`
export const classificationOption = (query, selected, classifications) => {
  const id = String(query ?? '').trim().toLowerCase()
  if (!cardOf(id, classifications) || selected.includes(id)) return nothing

  const label = cardLabel(id, classifications)
  return html`<li id=${uuid()} role="option" tabindex="-1" class="hw-combobox__option" data-action="click->hw-combobox#selectOnClick"
    data-filterable-as=${label} data-autocompletable-as=${label} data-value=${id} aria-selected="false"><span class="tw:block
    tw:text-base"><strong>${label}</strong> <code class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">${id}</code></span></li>`
}

// The vehicle combobox picks classifications beside models; the URL keeps them apart, as vehicle_sizes lines up with
// vehicle_models
export const withClassifications = (url, classifications) => {
  const picked = url.searchParams.get('vehicle_models')?.split(',').filter(Boolean) ?? []
  const [cards, models] = [picked.filter((id) => cardOf(id, classifications)), picked.filter((id) => !cardOf(id, classifications))]
  const next = new URL(url)
  models.length ? next.searchParams.set('vehicle_models', models.join(',')) : next.searchParams.delete('vehicle_models')
  cards.length ? next.searchParams.set(PARAM, cards.join(',')) : next.searchParams.delete(PARAM)
  return next
}

export const pickedClassifications = (url, classifications) =>
  (url.searchParams.get(PARAM)?.split(',') ?? []).filter((id) => cardOf(id, classifications))

// The `ids`' cards into `slot`, centered, each a state `jurisdiction`'s own, with its rules, once it loads over the
// US one. Left alone when they're what it already shows, so a search doesn't reload them
export const renderClassCards = (slot, ids, jurisdiction, classifications) => {
  const shown = [...new Set(ids.map((id) => cardOf(id, classifications)))]
  const key = JSON.stringify([shown, jurisdiction])
  if (slot.dataset.key === key) return

  slot.dataset.key = key
  const cards = shown.flatMap((card) => {
    const template = document.querySelector(`template[data-bikebook-class-card="${card}"]`)
    if (!template) return []

    const content = template.content.cloneNode(true)
    return [html`<div class="tw:w-full tw:max-w-sm">${jurisdiction
      ? html`<turbo-frame id=${template.dataset.frameId} src=${statePath(template.dataset.src, jurisdiction)}>${content}</turbo-frame>`
      : content}</div>`]
  })
  renderInto(slot, cards.length ? html`<div class="tw:mt-6 tw:flex tw:flex-wrap tw:justify-center tw:gap-4">${cards}</div>` : nothing)
}

// /ebike-rules?e_bike_class=3 as the state's own page, /ebike-rules/ca?e_bike_class=3
const statePath = (path, state) => {
  const url = new URL(path, window.location.origin)
  url.pathname += `/${state.toLowerCase()}`
  return url.pathname + url.search
}
