import { html, nothing } from 'lit-html'
import { amountDisplay } from 'bikebook/templates/helpers'
import { attributes } from 'bikebook/templates/attributes'
import { badge } from 'bikebook/templates/ui/badge'
import { configurationNote } from 'bikebook/templates/vehicles/configuration_note'
import { marketNote } from 'bikebook/templates/vehicles/market_note'

// SharedBlocks::SearchResults::BikeCard::Component::LIST_CLASSES
export const MODEL_CARDS_CLASSES = 'tw:grid tw:grid-cols-[repeat(auto-fill,minmax(max(14rem,calc((100%_-_3rem)/4)),1fr))] tw:gap-4'

// The years a model is sold in, one alone where its first is its final
const cardYears = ({ first_year: first, final_year: final }) => !first || first === final ? final ?? first : `${first}–${final ?? 'current'}`

// A catalog model as the search's cards show a bike: its photo and price, linking to `href` everywhere but its tooltips,
// `attributes` on the link. A `toggle`'s link adds it to the comparison, or takes it out once it's `active` there; without
// an `href` it can't. Its markets follow its name where `market` doesn't sell it
export const modelCard = ({ model, href, placeholderUrl, currencies, market, configurations, toggle = false, active = false, attributes: linkAttributes = {} }) => {
  const years = cardYears(model)
  return html`<li class="tw:relative tw:flex tw:flex-col tw:rounded-xl tw:border tw:bg-white tw:transition tw:focus-within:z-10 tw:dark:bg-gray-800
  tw:[&_[data-controller~=ui--tooltip]]:relative tw:[&_[data-controller~=ui--tooltip]]:z-20 ${active
    ? 'tw:border-purple-500 tw:ring-2 tw:ring-purple-500'
    : 'tw:border-gray-200 tw:dark:border-gray-700'} ${href
    ? 'tw:hover:z-10 tw:hover:-translate-y-0.5 tw:hover:shadow-lg tw:active:translate-y-0.5 tw:hover:active:translate-y-0'
    : 'tw:opacity-60'}"><div class="tw:group tw:relative tw:h-40 tw:rounded-t-[11px] tw:bg-white" data-controller=${model.stock_photo
    ? 'image-fallback'
    : nothing} data-broken=${model.stock_photo ? nothing : ''}>${model.stock_photo
    ? html`<img alt=${model.display} loading="lazy" class="tw:h-full tw:w-full tw:rounded-t-[11px] tw:object-contain tw:p-2 tw:group-data-broken:hidden"
      data-action="error->image-fallback#fallBack" src=${model.stock_photo}>`
    : nothing}<img alt=${model.display} class="tw:hidden tw:h-full tw:w-full tw:rounded-t-[11px] tw:bg-gray-100 tw:object-contain tw:p-8
    tw:group-data-broken:block tw:dark:bg-gray-900" src=${placeholderUrl}>${model.msrp_cents == null
    ? nothing
    : html`<span class="tw:absolute tw:top-2 tw:left-2 tw:rounded-full tw:bg-gray-900/80 tw:px-2 tw:py-1 tw:text-xs tw:font-extrabold
      tw:text-white">${amountDisplay(model.msrp_cents, model.msrp_currency, currencies)}</span>`}</div><div class="tw:flex tw:flex-col tw:gap-2
  tw:px-3 tw:pt-3 tw:pb-3.5"><h3 class="tw:m-0 tw:font-sans tw:text-base tw:leading-snug tw:normal-case"><a href=${href ?? nothing}
  ${attributes(linkAttributes)} aria-disabled=${href ? nothing : 'true'} class="tw:twtext-color tw:hover:underline"><strong>${model.manufacturer_name}</strong> ${
    model.model}${configurationNote({ configuration: model.model_configuration, names: configurations })}${marketNote({ markets: model.markets, market })}${toggle ? html`<span class="tw:sr-only">, ${active ? 'remove from' : 'add to'} the comparison</span>` : nothing}<span
  class="tw:absolute tw:inset-0 tw:z-10"></span></a></h3>${years || model.activity_name
    ? html`<p class="tw:m-0 tw:text-sm tw:text-gray-500"><strong>${years}</strong> ${model.activity_name}</p>`
    : nothing}<div class="tw:flex tw:flex-wrap tw:items-center tw:gap-1.5">${model.electric
    ? badge({ text: '⚡', title: 'E-vehicle', color: 'purple' })
    : nothing}${model.type_name ? badge({ text: model.type_name, color: model.electric ? 'purple' : 'gray' }) : nothing}</div></div></li>`
}
