import { html, nothing } from 'lit-html'

export const VIEWS = { basics: 'Basics', geometry: 'Sizes & geometry', components: 'Components', all: 'All' }

// The views of what's picked, each a link to this page with it, `current` underlined
export const jumpTo = (current, path) => html`<nav aria-label="Jump to" class="tw:mt-3 tw:flex tw:flex-wrap tw:items-center tw:border-b
  tw:border-gray-200 tw:dark:border-gray-700"><span class="tw:mr-2 tw:text-xs tw:font-bold tw:tracking-[.08em] tw:text-[#715eb2]
  tw:uppercase">Jump to</span>${Object.entries(VIEWS).map(([view, label]) => html`<a href=${path(view)} data-in-place=""
  aria-current=${view === current ? 'page' : nothing} class="tw:-mb-px tw:border-b-3 tw:border-transparent tw:px-2.5 tw:py-2 tw:text-sm tw:text-gray-700
  tw:transition tw:duration-300 tw:hover:bg-gray-50 tw:hover:text-blue-600 tw:aria-[current=page]:border-blue-600 tw:aria-[current=page]:text-blue-600
  tw:dark:text-gray-300 tw:dark:hover:bg-gray-800 tw:dark:hover:text-blue-400 tw:dark:aria-[current=page]:border-blue-400
  tw:dark:aria-[current=page]:text-blue-400">${label}</a>`)}</nav>`
