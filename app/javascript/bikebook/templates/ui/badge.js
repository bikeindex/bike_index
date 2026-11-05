import { html } from 'lit-html'
import { tooltip } from 'bikebook/templates/ui/tooltip'

const COLORS = {
  gray: 'tw:bg-[#f0f0f2] tw:text-[#666666] tw:border-transparent tw:dark:bg-gray-800 tw:dark:text-gray-400',
  purple: 'tw:bg-purple-50 tw:text-purple-700 tw:border-transparent tw:dark:bg-purple-950 tw:dark:text-purple-200'
}
const SIZES = {
  sm: 'tw:font-medium tw:px-1 tw:py-px',
  md: 'tw:font-bold tw:px-2 tw:py-1'
}

// UI::Badge::Component, in the colors the browser renders
export const badge = ({ text, title, color = 'gray', size = 'md' }) => {
  const titled = title && title !== text
  const pill = html`<span class="tw:inline-flex tw:border tw:items-center tw:leading-4 tw:rounded-full ${titled ? 'tw:cursor-help' : 'tw:cursor-default'}
    ${COLORS[color]} tw:text-xs ${SIZES[size]}">${text}</span>`
  return titled ? tooltip({ text: title, content: pill }) : pill
}

// A badge in a line of text, centered on its capitals rather than on align-middle's x-height, 0.09em lower, and in its
// own small font, as its tooltip's line box would otherwise take the text's and sit it low
export const inlineBadge = (args) => html`<span class="tw:relative tw:-top-[0.09em]"><span
  class="tw:inline-block tw:align-middle tw:text-xs tw:leading-none">${badge(args)}</span></span>`
