import { html } from 'lit-html'
import { check, clipboard } from 'bikebook/templates/icons'

// An ID in monospace with a button copying it; one too long for its space scrolls under the button
export const copyableId = ({ id }) => html`<span class="tw:group/id tw:relative tw:inline-grid tw:max-w-full tw:grid-cols-[minmax(0,1fr)_auto]
  tw:items-center tw:gap-1 tw:data-overflowing:grid-cols-1" data-controller="bikebook--overflowing"><code class="tw:overflow-x-auto
  tw:rounded-sm tw:border tw:border-vellum tw:px-2 tw:py-0.5 tw:font-spec tw:text-xs tw:whitespace-nowrap tw:group-data-overflowing/id:pr-9"
  data-bikebook--overflowing-target="text">${id}</code><span class="tw:flex tw:group-data-overflowing/id:absolute tw:group-data-overflowing/id:inset-y-px
  tw:group-data-overflowing/id:right-px tw:group-data-overflowing/id:items-center tw:group-data-overflowing/id:rounded-sm
  tw:group-data-overflowing/id:bg-paper"><button type="button" class="tw:group tw:shrink-0 tw:cursor-pointer tw:rounded-sm tw:p-1 tw:text-ink/50
  tw:hover:bg-vellum tw:hover:text-ink tw:focus:ring-2 tw:focus:ring-gray-400" title="Copy ID" data-controller="bikebook--copy-button"
  data-bikebook--copy-button-text-value=${id} data-action="bikebook--copy-button#copy">${clipboard('tw:h-3.5 tw:w-3.5 tw:group-data-copied:hidden')}${
    check('tw:hidden tw:h-3.5 tw:w-3.5 tw:text-green-600 tw:group-data-copied:block')}</button></span></span>`
