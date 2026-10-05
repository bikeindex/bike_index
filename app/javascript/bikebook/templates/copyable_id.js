import { html } from 'lit-html'
import { copyButton } from 'bikebook/templates/copy_button'

// An ID in monospace with a button copying it; one too long for its space scrolls under the button
export const copyableId = ({ id }) => html`<span class="tw:group/id tw:relative tw:inline-grid tw:max-w-full tw:grid-cols-[minmax(0,1fr)_auto]
  tw:items-center tw:gap-1 tw:data-overflowing:grid-cols-1" data-controller="bikebook--overflowing"><code class="tw:overflow-x-auto
  tw:rounded-sm tw:border tw:border-vellum tw:px-2 tw:py-0.5 tw:font-spec tw:text-xs tw:whitespace-nowrap tw:group-data-overflowing/id:pr-9"
  data-bikebook--overflowing-target="text">${id}</code><span class="tw:flex tw:group-data-overflowing/id:absolute tw:group-data-overflowing/id:inset-y-px
  tw:group-data-overflowing/id:right-px tw:group-data-overflowing/id:items-center tw:group-data-overflowing/id:rounded-sm
  tw:group-data-overflowing/id:bg-paper">${copyButton({ value: id, label: 'Copy ID' })}</span></span>`
