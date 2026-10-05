import { html, nothing } from 'lit-html'
import { amountDisplay, uuid } from 'bikebook/templates/helpers'

const years = (text) => html`<span class="tw:text-sm tw:tabular-nums tw:text-gray-400 tw:dark:text-gray-500">${text}</span>`
const CURRENT = html`<span class="tw:rounded-full tw:bg-emerald-100 tw:px-1.5 tw:text-xs tw:font-medium tw:text-emerald-700 tw:dark:bg-emerald-900/50
  tw:dark:text-emerald-300">current</span>`

const yearBadge = ({ first_year: first, final_year: final }) => {
  if (final) return years(first && first !== final ? `${first}-${final}` : final)
  if (!first) return nothing
  return first < new Date().getFullYear() ? html`<span class="tw:flex tw:items-baseline tw:gap-x-1">${years(`${first}-`)}${CURRENT}</span>` : CURRENT
}

const thumb = (photo, placeholderUrl) => html`<span class="tw:group tw:shrink-0" data-controller=${photo ? 'bikebook--image-fallback' : nothing}
  data-broken=${photo ? nothing : ''}>${photo
    ? html`<img alt="" loading="lazy" class="tw:h-8 tw:w-12 tw:rounded-sm tw:object-contain tw:group-data-broken:hidden"
      data-action="error->bikebook--image-fallback#fail" src=${photo}>`
    : nothing}<span class="tw:hidden tw:h-8 tw:w-12 tw:items-center tw:justify-center tw:rounded-sm tw:bg-gray-100
    tw:group-data-broken:flex tw:dark:bg-gray-800"><img alt="" class="tw:h-6 tw:w-6" src=${placeholderUrl}></span></span>`

// A model's option in the vehicle combobox: photo, name, activity, years and price
export const comboboxOption = ({ model, placeholderUrl, currencies }) => {
  const badge = yearBadge(model)
  const price = model.msrp_cents == null ? nothing : amountDisplay(model.msrp_cents, model.msrp_currency, currencies)
  const activity = model.activity_name
    ? html`<span class="tw:min-w-0 tw:flex-1 tw:truncate tw:text-xs tw:text-gray-400 tw:dark:text-gray-500">${model.activity_name}</span>`
    : nothing
  const meta = badge !== nothing || price !== nothing
    ? html`<span class="tw:ml-auto tw:flex tw:shrink-0 tw:items-baseline tw:gap-x-2 tw:text-sm tw:tabular-nums">${badge}${price}</span>`
    : nothing
  const details = activity !== nothing || meta !== nothing ? html`<span class="tw:flex tw:items-baseline tw:gap-x-2">${activity}${meta}</span>` : nothing
  return html`<li id=${uuid()} role="option" tabindex="-1" class="hw-combobox__option" data-action="click->hw-combobox#selectOnClick"
    data-filterable-as=${model.display} data-autocompletable-as=${model.display} data-value=${model.id} aria-selected="false"><span
    class="tw:flex tw:items-center tw:gap-x-2">${thumb(model.stock_photo, placeholderUrl)}<span class="tw:min-w-0 tw:flex-1"><span
    class="tw:block tw:text-base"><strong>${model.manufacturer_name}</strong>${model.model ? ` ${model.model}` : nothing}</span>${details}</span></span></li>`
}
