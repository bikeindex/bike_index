import { html, nothing } from 'lit-html'

// " (CA)" after a model's name where it isn't sold in the visitor's `market`, nothing where any market will do or its
// markets aren't known, ahead of the index
export const marketNote = ({ markets = [], market }) => market && markets.length > 0 && !markets.includes(market)
  ? html` <span class="tw:text-sm tw:font-normal less-strong">(${markets.join(', ')})</span>`
  : nothing
