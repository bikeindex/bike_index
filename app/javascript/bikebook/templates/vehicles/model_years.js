import { html } from 'lit-html'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { array, blank, compact, join, present } from 'bikebook/templates/values'

// A colorway's swatch by its name, else its colors, with its code and colors a tooltip away. Without a code, Bike Index's
// swatches of its colors in its swatch's place, and no tooltip
export const colorway = (presenter, { name, color_code: hex, colors }) => {
  const label = name ?? join(array(colors), ', ')
  if (blank(hex)) return html`<span class="tw:inline-flex tw:items-baseline tw:gap-1">${join(compact([...array(colors).map((color) => presenter.paintSwatch(color)), label]))}</span>`

  const lines = compact([html`Code: <code>${hex}</code>`, present(colors) ? join(['Colors: ', join(array(colors).map((color) => presenter.paintColor(color)), ', ')]) : null])
  return html`<span class="tw:inline-flex tw:items-baseline tw:gap-1"><span class="tw:inline-block tw:h-3 tw:w-3 tw:rounded-full tw:border tw:border-gray-300
    tw:dark:border-gray-600" style=${`background-color: ${hex}`}></span>${label}${tooltip({ body: join(lines.map((line) => html`<span class="tw:block">${line}</span>`)) })}</span>`
}

export const colorways = (presenter, each) => html`<div class="tw:flex tw:flex-wrap tw:items-baseline tw:gap-x-3 tw:gap-y-1 tw:text-xs tw:text-gray-600
  tw:dark:text-gray-400">${each.map((one) => colorway(presenter, one))}</div>`
