import { html, nothing } from 'lit-html'
import { numberDisplay } from 'bikebook/templates/helpers'
import { x } from 'bikebook/templates/icons'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { MODEL_CARDS_CLASSES, modelCard } from 'bikebook/templates/vehicles/model_card'

// opens the search's filter panel, outside this controller, focusing its first field
const filtersButton = (label) => html`<button type="button" class="twlink" data-action="bikebook--tips#filters">${label}</button>`

const steps = [
  ['Search for a bike', html`Type a brand or model above, or narrow down with ${filtersButton('More filters')}.`],
  ['Add more to compare', 'Pick two or more bikes and they line up side by side.'],
  ['Compare what matters', 'Geometry, components, price, weight, and e-bike classification.']
]

const EXAMPLES = [
  ['Gravel bikes under $1,500', 'primary_activity=atb_gravel&price_max=1500'],
  ['Trek Marlin 5 vs Specialized Rockhopper Sport', 'vehicle_models=m/trek/2026/marlin_5_gen_3,m/specialized/2026/rockhopper_sport'],
  ['RadWagon 4 vs 5 vs 2026', 'vehicle_models=m/rad_power/2020/radwagon_4,m/rad_power/2024/radwagon_5,m/rad_power/2026/radwagon']
]

// active while `url` has every param its query sets, as UI::ButtonLink's `active:` renders it
const exampleLink = (url, [label, query]) => html`<a href=${`${url.pathname}?${query}`} class=${buttonClasses({ size: 'sm' })}
  data-active=${[...new URLSearchParams(query)].every(([name, value]) => url.searchParams.get(name) === value) || nothing}>${label}</a>`

// What the search leaves, and the way on: into the search's list, or back to the filters when it's empty
const searchNote = ({ count, filtered }) => html`<p class="tw:mt-3 tw:rounded-md tw:bg-blue-50 tw:px-4 tw:py-3 tw:text-sm tw:dark:bg-blue-950">${count
  ? html`${numberDisplay(count)} ${filtered
    ? (count === 1 ? 'model matches your filters' : 'models match your filters')
    : (count === 1 ? 'model to compare' : 'models to compare')}. <button type="button" class="twlink"
    data-action="bikebook--tips#browse">Search them</button>`
  : html`No models match your filters. ${filtersButton('Change filters')}`}</p>`

const featuredCards = ({ featured, vehiclePath, ...card }) => html`<ul aria-label="Models to compare" class="tw:mt-3 ${MODEL_CARDS_CLASSES}"
  >${featured.map((model) => modelCard({ model, href: vehiclePath(model.id), ...card }))}</ul>`

// With nothing picked, how the page works and comparisons to start from, or once they're dismissed, a prompt, and under
// either what the search leaves and some of it. A classification's card, shown alone, leaves out the first two
export const emptyState = ({ url, filtered, count, featured, ...cards }) => html`<div class="tw:mt-3" data-controller="bikebook--tips">${url.searchParams.get('classifications')
  ? nothing
  : tips(url)}${filtered || featured.length
  ? searchNote({ count, filtered })
  : nothing}${featured.length ? featuredCards({ featured, ...cards }) : nothing}</div>`

const tips = (url) => html`<div data-bikebook--tips-target="tips"><section aria-label="How to use Bike Book" tabindex="-1"
  class="tw:relative tw:flex tw:flex-col tw:gap-5 tw:rounded-md tw:border tw:border-dashed tw:border-gray-300 tw:px-7 tw:py-6 tw:outline-none
  tw:dark:border-gray-600"><ol class="tw:m-0 tw:grid tw:list-none tw:gap-6 tw:p-0 tw:sm:grid-cols-3">${steps.map(([title, description], index) =>
    html`<li class="tw:flex tw:gap-3"><span aria-hidden="true" class="tw:flex tw:size-7 tw:shrink-0 tw:items-center tw:justify-center tw:rounded-full
    tw:bg-[#715eb2] tw:font-header tw:text-sm tw:font-bold tw:text-white">${index + 1}</span><div><h2 class="tw:text-[15px] tw:font-bold">${title}</h2><p
    class="tw:mt-1 tw:text-sm tw:text-gray-600 tw:dark:text-gray-400">${description}</p></div></li>`)}</ol><div class="tw:flex tw:flex-wrap
  tw:items-center tw:gap-2.5 tw:border-t tw:border-gray-100 tw:pt-4 tw:dark:border-gray-700"><span class="tw:text-sm tw:text-gray-600
  tw:dark:text-gray-400">Or try an example:</span>${EXAMPLES.map((example) => exampleLink(url, example))}</div><button type="button" aria-label="Dismiss tips"
  data-action="bikebook--tips#dismiss" class="tw:absolute tw:top-2.5 tw:right-3 tw:p-1 tw:text-gray-400 tw:hover:text-gray-600
  tw:dark:hover:text-gray-200">${x('tw:h-3 tw:w-3')}</button></section></div><div hidden data-bikebook--tips-target="prompt"><div class="tw:rounded-md
  tw:border tw:border-dashed tw:border-gray-300 tw:px-4 tw:py-6 tw:text-center tw:dark:border-gray-600"><p class="tw:text-xs tw:font-bold tw:tracking-wider
  tw:text-[#715eb2] tw:uppercase tw:dark:text-[#a99bd6]">Nothing selected yet</p><p class="tw:mt-1 tw:text-sm tw:text-gray-500">Pick a bike above to start
  comparing. <button type="button" class="twlink" data-bikebook--tips-target="restore" data-action="bikebook--tips#restore">Show tips</button></p></div></div>`
