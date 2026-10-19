import { html, nothing } from 'lit-html'
import { toQuery } from 'bikebook/query'
import { fragmentOf, keepPermanent } from 'bikebook/render'
import { paramList } from 'bikebook/sizes'
import { filterOption } from 'bikebook/templates/filter_option'
import { US_CLASS } from 'bikebook/templates/vehicles/model_viewer'

const PARAM = 'classifications'

const hasCard = (id, classifications) => Boolean(classifications[id])

// A search that's a classification's exact ID, in any case, as evc/out_of_class/US-CA's has capitals, offers it, unless
// it's `selected`
export const classificationOption = (query, selected, classifications) => {
  const typed = String(query ?? '').trim().toLowerCase()
  const id = Object.keys(classifications).find((key) => key.toLowerCase() === typed)
  const label = classifications[id]?.label
  return label && !selected.includes(id) ? filterOption({ value: id, display: label, name: label }) : null
}

// The vehicle combobox picks classifications beside models; the URL keeps them apart, as vehicle_sizes lines up with
// vehicle_models
export const withClassifications = (url, classifications) => {
  const picked = paramList(url, 'vehicle_models').filter(Boolean)
  const [cards, models] = [picked.filter((id) => hasCard(id, classifications)), picked.filter((id) => !hasCard(id, classifications))]
  const next = new URL(url)
  models.length ? next.searchParams.set('vehicle_models', models.join(',')) : next.searchParams.delete('vehicle_models')
  cards.length ? next.searchParams.set(PARAM, cards.join(',')) : next.searchParams.delete(PARAM)
  return next
}

export const pickedClassifications = (url, classifications) => paramList(url, PARAM).filter((id) => hasCard(id, classifications))

// The `ids`' /ebike-rules cards into `root`'s slot, centered: a US class's from the page, which its jurisdiction's own,
// with its rules, loads over, and any other's from /ebike-rules. Each is permanent, so one already shown is kept as it is
export const renderClassCards = (root, ids, classifications) => {
  const slot = root.getElementById('classification-cards')
  const jurisdiction = root.getElementById('jurisdiction-hw-hidden-field').value
  const shown = [...new Set(ids)].filter((id) => hasCard(id, classifications))
  const key = JSON.stringify([shown, jurisdiction])
  if (slot.dataset.key === key) return

  slot.dataset.key = key
  const { frameId, src } = slot.dataset
  const frame = (suffix, params, content = nothing, state = '') =>
    html`<turbo-frame id=${`${frameId}-${suffix}`} src=${`${src}${state && `/US/${state}`}?${toQuery(params)}`}>${content}</turbo-frame>`
  const cards = shown.map((id) => {
    const number = id.match(US_CLASS)?.[1]
    const permanent = number && jurisdiction ? `${id} ${jurisdiction}` : id
    const content = number && document.querySelector(`template[data-bikebook-class-card="${number}"]`)?.content.cloneNode(true)
    const card = number
      ? (jurisdiction ? frame(number, { e_bike_class: number }, content, jurisdiction) : content)
      : frame(id.replace(/[^\w-]/g, '-'), { classification: id })
    return html`<div id=${`classification-card-${id.replace(/[^\w-]/g, '-')}`} class="tw:w-full tw:max-w-sm" data-permanent=${permanent}>${card}</div>`
  })
  slot.replaceChildren(keepPermanent(fragmentOf(cards.length
    ? html`<div class="tw:mt-6 tw:flex tw:flex-wrap tw:justify-center tw:gap-4">${cards}</div>`
    : nothing), slot))
}
