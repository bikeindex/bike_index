import { html } from 'lit-html'

// UI::Card::Component, undivided and without a shadow
export const card = ({ content, additionalClasses, fullBleed = false }) => html`<div class=${[
  'tw:bg-white tw:border tw:border-gray-200 tw:dark:bg-gray-800 tw:dark:border-gray-700', 'tw:p-4 tw:rounded-sm', fullBleed && 'tw:twfullbleed', additionalClasses
].filter(Boolean).join(' ')}>${content}</div>`
