import { html } from 'lit-html'

// UI::Code::Inline::Component
export const codeInline = ({ text, small = false, wordBreak = true }) => html`<code class="tw:rounded-none tw:bg-transparent tw:p-0 tw:text-pink-600 tw:dark:text-pink-400 ${
  small ? 'tw:text-xs' : 'tw:text-sm'} ${wordBreak ? 'tw:wrap-break-word' : 'tw:break-keep'}">${text}</code>`
