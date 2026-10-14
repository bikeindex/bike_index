import { html } from 'lit-html'
import { x } from 'bikebook/templates/icons'

const STEPS = [
  ['Search for a bike', html`Type a brand or model above, or narrow down with <button type="button" class="twlink" data-action="bikebook--tips#openFilters">More filters</button>.`],
  ['Add more to compare', 'Pick two or more bikes and they line up side by side.'],
  ['Compare what matters', 'Geometry and overlay, components, sizes, price, weight, and e-bike class.']
]

const EXAMPLES = [
  ['Trek Marlin 5 vs Specialized Rockhopper Sport', 'vehicle_models=m/trek/2026/marlin_5_gen_3,m/specialized/2026/rockhopper_sport'],
  ['e-bike and classification', 'vehicle_models=m/rad_power/2020/radwagon_4,m/rad_power/2024/radwagon_5,m/rad_power/2026/radwagon'],
  ['Gravel bikes under $1,500', 'primary_activity=atb_gravel&price_max=1500']
]

// With nothing picked, how the page works and comparisons to start from, or once they're dismissed, a prompt
export const emptyState = (pathname) => html`<div class="tw:mt-3" data-controller="bikebook--tips"><div data-bikebook--tips-target="tips"><section
  aria-label="How to use Bike Book" class="tw:relative tw:flex tw:flex-col tw:gap-5 tw:rounded-md tw:border tw:border-dashed tw:border-gray-300
  tw:px-7 tw:py-6 tw:dark:border-gray-600"><button type="button" aria-label="Dismiss tips" data-action="bikebook--tips#dismiss" class="tw:absolute
  tw:top-2.5 tw:right-3 tw:p-1 tw:text-gray-400 tw:hover:text-gray-600 tw:dark:hover:text-gray-200">${x('tw:h-3 tw:w-3')}</button><ol
  class="tw:m-0 tw:grid tw:list-none tw:gap-6 tw:p-0 tw:sm:grid-cols-3">${STEPS.map(([title, description], index) => html`<li class="tw:flex tw:gap-3"><span
  aria-hidden="true" class="tw:flex tw:size-7 tw:shrink-0 tw:items-center tw:justify-center tw:rounded-full tw:bg-[#715eb2] tw:font-header tw:text-sm
  tw:font-bold tw:text-white">${index + 1}</span><div><h2 class="tw:text-[15px] tw:font-bold">${title}</h2><p class="tw:mt-1 tw:text-sm tw:text-gray-600
  tw:dark:text-gray-400">${description}</p></div></li>`)}</ol><div class="tw:flex tw:flex-wrap tw:items-center tw:gap-2.5 tw:border-t tw:border-gray-100 tw:pt-4
  tw:dark:border-gray-700"><span class="tw:text-sm tw:text-gray-600 tw:dark:text-gray-400">Or try an example:</span>${EXAMPLES.map(([label, query]) =>
    html`<a href=${`${pathname}?${query}`} class="tw:rounded-full tw:border tw:border-gray-200 tw:px-3.5 tw:py-1 tw:text-sm tw:text-blue-600 tw:transition
    tw:duration-300 tw:hover:border-blue-600 tw:dark:border-gray-700 tw:dark:text-blue-400 tw:dark:hover:border-blue-400">${label}</a>`)}</div></section></div><div
  hidden data-bikebook--tips-target="prompt"><div class="tw:mx-auto tw:max-w-4xl tw:rounded-lg tw:border tw:border-dashed tw:border-gray-200 tw:px-4 tw:py-6
  tw:text-center tw:dark:border-gray-700"><p class="tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">Nothing selected yet</p><p
  class="tw:mt-1 tw:text-sm tw:text-gray-500">Pick a bike above to start comparing. <button type="button" class="twlink"
  data-action="bikebook--tips#restore">Show tips</button></p></div></div></div>`
