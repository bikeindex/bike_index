import { html, nothing } from 'lit-html'

// " (CA)" after a model's name where it isn't sold in the visitor's `market`, nothing where any market will do
export const marketNote = ({ markets = [], market }) => market && !markets.includes(market)
  ? html` <span class="tw:text-sm tw:font-normal twless-strong">(${markets.join(', ')})</span>`
  : nothing
