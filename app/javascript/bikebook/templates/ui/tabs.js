import { html, nothing } from 'lit-html'
import { numberDisplay } from 'bikebook/templates/helpers'

const TAB_CLASSES = 'twlink tw:-mb-px tw:inline-flex tw:items-baseline tw:gap-1 tw:whitespace-nowrap ' +
  'tw:rounded-t-md tw:border tw:border-transparent tw:px-4 tw:py-2 tw:text-sm tw:no-underline ' +
  'tw:hover:bg-gray-100 tw:dark:hover:bg-gray-800 tw:is-active:border-gray-300 tw:is-active:border-b-white ' +
  'tw:is-active:bg-white tw:is-active:font-semibold tw:is-active:text-gray-900 tw:dark:is-active:border-gray-700 ' +
  'tw:dark:is-active:border-b-gray-900 tw:dark:is-active:bg-gray-900 tw:dark:is-active:text-gray-100'

// UI::Tabs::Component, each of `tabs` a ComponentStructs::Shapes.tab
export const tabs = ({ tabs, navLabel, turbo = false, marginClasses = 'tw:mb-3' }) => html`<nav
  class=${`twgutter-bleed tw:overflow-x-auto tw:pt-1 ${marginClasses}`} aria-label=${navLabel} data-controller="ui--tabs"
  data-turbo=${turbo ? 'true' : nothing}><div class="tw:flex tw:w-max tw:min-w-full tw:gap-1 tw:border-b tw:border-gray-300 tw:dark:border-gray-700"
  data-ui--tabs-target="row">${tabs.map(({ label, href, active, count, classes }) => html`<a href=${href}
    class=${[TAB_CLASSES, classes].filter(Boolean).join(' ')} aria-current=${active ? 'page' : nothing}
    data-ui--tabs-target=${active ? 'active' : nothing}>${label}${count != null && count !== '' ? html`<small>${numberDisplay(count)}</small>` : nothing}</a>`)}</div></nav>`
