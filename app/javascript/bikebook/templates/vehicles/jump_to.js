import { html, nothing } from 'lit-html'

export const VIEWS = { basics: 'Basics', geometry: 'Sizes & geometry', components: 'Components', all: 'All' }

// what an in-place link focuses once it renders, keeping the reader's place in the tabs
export const CURRENT_VIEW = '#vehicle-views [aria-current]'

// The views of what's picked, each a link to this page with it, `current` underlined. One line that scrolls on a
// phone; its rule is an inset shadow, which a scroller can't clip as it would a link's border hanging over its own
export const jumpTo = (current, path) => html`<nav id="vehicle-views" aria-label="Jump to" data-controller="bikebook--center-current" class="tw:mt-3 tw:flex tw:items-center tw:overflow-x-auto
  tw:whitespace-nowrap tw:shadow-[inset_0_-1px_0_var(--color-gray-200)] tw:[scrollbar-width:none] tw:dark:shadow-[inset_0_-1px_0_var(--color-gray-700)]"><span class="tw:mr-1
  tw:text-xs tw:font-bold tw:tracking-[.08em] tw:text-[#715eb2] tw:uppercase tw:sm:mr-2 tw:dark:text-[#a99bd6]">Jump to</span>${Object.entries(VIEWS)
    .map(([view, label]) => html`<a href=${path(view)} data-in-place=${CURRENT_VIEW} aria-current=${view === current ? 'page' : nothing}
    class="tw:shrink-0 tw:border-b-3 tw:border-transparent tw:px-2 tw:py-2 tw:text-sm tw:text-gray-700 tw:transition tw:duration-300
    tw:hover:bg-gray-50 tw:hover:text-blue-600 tw:aria-[current=page]:border-blue-600 tw:aria-[current=page]:text-blue-600 tw:sm:px-2.5
    tw:dark:text-gray-300 tw:dark:hover:bg-gray-800 tw:dark:hover:text-blue-400 tw:dark:aria-[current=page]:border-blue-400
    tw:dark:aria-[current=page]:text-blue-400">${label}</a>`)}</nav>`
