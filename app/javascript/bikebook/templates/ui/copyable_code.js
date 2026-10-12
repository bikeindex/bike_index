import { html } from 'lit-html'
import { copyButton } from 'bikebook/templates/ui/copy_button'

// UI::CopyableCode::Component
export const copyableCode = ({ value, label }) => html`<span class="tw:group tw:relative tw:inline-grid tw:max-w-full
  tw:grid-cols-[minmax(0,1fr)_auto] tw:items-center tw:gap-1 tw:data-overflowing:grid-cols-1" data-controller="overflowing"><code
  class="tw:overflow-x-auto tw:rounded-sm tw:border tw:border-gray-200 tw:bg-transparent tw:px-2 tw:py-0.5 tw:font-mono tw:text-xs
  tw:whitespace-nowrap tw:text-inherit tw:group-data-overflowing:pr-9 tw:dark:border-gray-700" data-overflowing-target="text">${value}</code><span
  class="tw:flex tw:items-center tw:rounded-sm tw:group-data-overflowing:absolute tw:group-data-overflowing:inset-y-px
  tw:group-data-overflowing:right-px tw:group-data-overflowing:bg-white tw:dark:group-data-overflowing:bg-gray-800">${
    copyButton({ value, label })}</span></span>`
