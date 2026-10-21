import { html } from 'lit-html'
import { tooltip } from 'bikebook/templates/ui/tooltip'

const COLORS = {
  gray: 'tw:bg-[#f0f0f2] tw:text-[#666666] tw:border-transparent tw:dark:bg-gray-800 tw:dark:text-gray-400',
  purple: 'tw:bg-purple-50 tw:text-purple-700 tw:border-transparent tw:dark:bg-purple-950 tw:dark:text-purple-200'
}

// UI::Badge::Component at its md size, in the colors the browser renders
export const badge = ({ text, title, color = 'gray' }) => {
  const titled = title && title !== text
  const pill = html`<span class="tw:inline-flex tw:border tw:items-center tw:leading-4 tw:rounded-full ${titled ? 'tw:cursor-help' : 'tw:cursor-default'}
    ${COLORS[color]} tw:text-xs tw:font-bold tw:px-2 tw:py-1">${text}</span>`
  return titled ? tooltip({ text: title, content: pill }) : pill
}
