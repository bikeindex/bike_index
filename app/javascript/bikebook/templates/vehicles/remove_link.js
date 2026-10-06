import { html } from 'lit-html'
import { x } from 'bikebook/templates/icons'

// A card's ×, to `href`: the page without it
export const removeLink = ({ label, href }) => html`<a aria-label=${label} data-controller="bikebook--remove-vehicle"
  data-action="ui--alert#close bikebook--remove-vehicle#remove" data-turbo-prefetch="false" class="tw:-my-1.5 tw:-mr-1.5 tw:ml-auto tw:inline-flex
  tw:h-8 tw:w-8 tw:shrink-0 tw:items-center tw:justify-center tw:rounded-sm tw:text-gray-500 tw:hover:bg-gray-100 tw:dark:hover:bg-gray-700
  tw:focus:ring-2 tw:focus:ring-gray-400 tw:dark:text-gray-400" href=${href}>${x('tw:h-3 tw:w-3')}</a>`
