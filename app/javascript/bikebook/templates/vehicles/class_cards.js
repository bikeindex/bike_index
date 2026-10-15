import { html, nothing } from 'lit-html'
import { uuid } from 'bikebook/templates/helpers'
import { renderInto } from 'bikebook/render'

const PARAM = 'classifications'
const US_CLASS = /^evc\/us\/class_(\d)$/

export const hasCard = (id, classifications) => Boolean(classifications[id])

export const cardLabel = (id, classifications) => classifications[id]?.label

// A search that's a classification's exact ID offers it, unless it's `selected`
export const classificationOption = (query, selected, classifications) => {
  const id = String(query ?? '').trim().toLowerCase()
  if (!hasCard(id, classifications) || selected.includes(id)) return nothing

  const label = cardLabel(id, classifications)
  return html`<li id=${uuid()} role="option" tabindex="-1" class="hw-combobox__option" data-action="click->hw-combobox#selectOnClick"
    data-filterable-as=${label} data-autocompletable-as=${label} data-value=${id} aria-selected="false"><span class="tw:block
    tw:text-base"><strong>${label}</strong> <code class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">${id}</code></span></li>`
}

// The vehicle combobox picks classifications beside models; the URL keeps them apart, as vehicle_sizes lines up with
// vehicle_models
export const withClassifications = (url, classifications) => {
  const picked = url.searchParams.get('vehicle_models')?.split(',').filter(Boolean) ?? []
  const [cards, models] = [picked.filter((id) => hasCard(id, classifications)), picked.filter((id) => !hasCard(id, classifications))]
  const next = new URL(url)
  models.length ? next.searchParams.set('vehicle_models', models.join(',')) : next.searchParams.delete('vehicle_models')
  cards.length ? next.searchParams.set(PARAM, cards.join(',')) : next.searchParams.delete(PARAM)
  return next
}

export const pickedClassifications = (url, classifications) =>
  (url.searchParams.get(PARAM)?.split(',') ?? []).filter((id) => hasCard(id, classifications))

// The `ids`' /ebike-rules cards into `slot`, centered: a US class's from the page, which a state `jurisdiction`'s own,
// with its rules, loads over, and any other's from /ebike-rules. Each the page already shows carries over as it is,
// loaded and open or closed, so neither a search, a render nor another card reloads it
export const renderClassCards = (slot, ids, jurisdiction, classifications) => {
  const shown = [...new Set(ids)].filter((id) => hasCard(id, classifications))
  const key = JSON.stringify([shown, jurisdiction || ''])
  const current = document.getElementById(slot.id)
  if (current === slot && slot.dataset.key === key) return

  slot.dataset.key = key
  const { frameId, src } = slot.dataset
  const frame = (suffix, params, content = nothing, state = null) =>
    html`<turbo-frame id=${`${frameId}-${suffix}`} src=${path(src, state, params)}>${content}</turbo-frame>`
  const kept = new Map([...(current?.querySelectorAll('[data-card]') ?? [])].map((card) => [card.dataset.card, card]))
  const cards = shown.map((id) => {
    const number = id.match(US_CLASS)?.[1]
    const cardKey = number && jurisdiction ? `${id} ${jurisdiction}` : id
    if (kept.has(cardKey)) return kept.get(cardKey).cloneNode(true)

    const content = number && document.querySelector(`template[data-bikebook-class-card="${number}"]`)?.content.cloneNode(true)
    const card = number
      ? (jurisdiction ? frame(number, { e_bike_class: number }, content, jurisdiction) : content)
      : frame(id.replace(/[^\w-]/g, '-'), { classification: id })
    return html`<div class="tw:w-full tw:max-w-sm" data-card=${cardKey}>${card}</div>`
  })
  renderInto(slot, cards.length ? html`<div class="tw:mt-6 tw:flex tw:flex-wrap tw:justify-center tw:gap-4">${cards}</div>` : nothing)
}

// /ebike-rules with `params`, or a `state`'s own page, /ebike-rules/ca
const path = (base, state, params) => {
  const url = new URL(base, window.location.origin)
  if (state) url.pathname += `/${state.toLowerCase()}`
  url.search = new URLSearchParams(params)
  return url.pathname + url.search
}
