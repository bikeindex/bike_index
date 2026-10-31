import { html, nothing } from 'lit-html'
import { amountDisplay } from 'bikebook/templates/helpers'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { array, blank, compact, equal, join, present, slice } from 'bikebook/templates/values'

const CELL = 'tw:border-b tw:border-gray-100 tw:px-1 tw:py-1 tw:dark:border-gray-700'

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

// A model's years with their price and paint, marking each cell `others` differ on, and just the year of one they lack
export const modelYears = ({ presenter, years, others }) => {
  if (blank(years)) return nothing

  const rows = years.map((year) => {
    const counterparts = others.map((otherYears) => array(otherYears).find((each) => each.year === year.year))
    const highlight = (keys, lacking = false) => counterparts.some((other) => other ? !equal(slice(other, keys), slice(year, keys)) : lacking) ? 'tw:spec-diff' : ''
    const label = blank(year.url) ? year.year : html`<a class="twlink" href=${year.url}>${year.year}</a>`
    const money = blank(year.original_msrp)
      ? nothing
      : html`<span class="tw:font-mono tw:text-sm">${amountDisplay(year.original_msrp, year.original_msrp_currency, presenter.vocabulary.currencies)}</span>`
    return html`<tr class="tw:even:bg-gray-100 tw:dark:even:bg-gray-800"><td class="${CELL} ${highlight(['url'], true)}">${label}</td><td
      class="${CELL} ${highlight(['original_msrp', 'original_msrp_currency'])}">${money}</td><td class="${CELL} ${highlight(['colorways'])}">${colorways(presenter, array(year.colorways))}</td></tr>`
  })
  return html`<section class="tw:mb-6 tw:break-inside-avoid tw:space-y-2"><h2 class="tw:border-b tw:border-gray-200 tw:dark:border-gray-700 tw:pb-1.5 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">Model years</h2><table
    class="tw:w-full tw:border-collapse tw:text-left"><tbody>${rows}</tbody></table></section>`
}
