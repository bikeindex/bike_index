import { html } from 'lit-html'
import { x } from 'bikebook/templates/icons'
import { CURRENT_VIEW } from 'bikebook/templates/vehicles/jump_to'

export const X_LINK_CLASSES = 'tw:inline-flex tw:h-8 tw:w-8 tw:shrink-0 tw:items-center tw:justify-center tw:rounded-sm tw:text-gray-500 ' +
  'tw:hover:bg-gray-100 tw:dark:hover:bg-gray-700 tw:focus:ring-2 tw:focus:ring-gray-400 tw:dark:text-gray-400'

// A card's ×, to `href`: the page without it, rendered where the reader is, focus back on the view's tab. In the `corner`
// of a relative card, over its photo, else at the end of its line
export const removeLink = ({ label, href, corner = false }) => html`<a aria-label=${label} data-in-place=${CURRENT_VIEW}
  data-controller="bikebook--remove-vehicle" data-action="ui--alert#close bikebook--remove-vehicle#remove" data-turbo-prefetch="false" class="${corner
  ? 'tw:absolute tw:top-0 tw:right-0 tw:z-10 tw:bg-white/80 tw:dark:bg-gray-800/80'
  : 'tw:-my-1.5 tw:-mr-1.5 tw:ml-auto'} ${X_LINK_CLASSES}" href=${href}>${x('tw:h-3 tw:w-3')}</a>`
