import { html } from 'lit-html'

// Color::COVER_UP_NAME and Color::COVER_UP_SWATCH
const COVER_UP_NAME = 'Stickers tape or other cover-up'
const COVER_UP_SWATCH = 'radial-gradient(circle at 50% 100%, transparent 0 20%, #a745c0 20% 30%, ' +
  '#386ed2 30% 40%, #1ba100 40% 50%, #fff44b 50% 60%, #ff8d1d 60% 70%, #ec1313 70% 80%, transparent 80%), #fff'
const SIZES = { sm: 'tw:h-3 tw:w-3', md: 'tw:h-6 tw:w-6' }
const ALIGNS = { middle: 'tw:align-middle', baseline: 'tw:align-baseline' }

// UI::ColorSwatch::Component
export const colorSwatch = ({ display, name, size = 'md', align = 'middle' }) => html`<span class="tw:inline-block tw:leading-[0] tw:rounded-xs tw:border tw:border-black/20 ${
  SIZES[size] ?? SIZES.md} ${ALIGNS[align] ?? ALIGNS.middle}" style="background: ${name === COVER_UP_NAME ? COVER_UP_SWATCH : display ?? ''}" aria-hidden="true"></span>`
