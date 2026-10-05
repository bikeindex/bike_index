import { html, nothing } from 'lit-html'
import { amountDisplay } from 'bikebook/templates/helpers'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { array, blank, compact, equal, join, present, slice } from 'bikebook/templates/values'

const CELL = 'tw:border-b tw:border-gray-100 tw:px-1 tw:py-1 tw:dark:border-gray-700'

// A model's years with their price and paint, marking a year `others` lack or differ on
export const modelYears = ({ presenter, years, others }) => {
  if (blank(years)) return nothing

  const diffKeys = presenter.kit.model_years.diff_keys
  const rows = years.map((year) => {
    const differs = others.some((otherYears) => !equal(slice(array(otherYears).find((each) => each.year === year.year), diffKeys), slice(year, diffKeys)) ||
      !array(otherYears).some((each) => each.year === year.year))
    const label = blank(year.url) ? year.year : html`<a class="twlink" title=${year.url_is_official ? 'Official page' : nothing} href=${year.url}>${year.year}</a>`
    const money = blank(year.original_msrp)
      ? nothing
      : html`<span class="tw:font-spec tw:text-sm">${amountDisplay(year.original_msrp, year.original_msrp_currency, presenter.kit.currencies)}</span>`
    const swatches = array(year.paint_descriptions).map((paint, index) => {
      const hex = year.paint_color_codes?.[index]
      const swatch = present(hex)
        ? tooltip({ text: hex, content: html`<span class="tw:inline-block tw:h-3 tw:w-3 tw:rounded-full tw:border tw:border-gray-300 tw:dark:border-gray-600" style=${`background-color: ${hex}`}></span>` })
        : null
      return html`<span class="tw:inline-flex tw:items-center tw:gap-1 tw:text-xs tw:text-gray-600 tw:dark:text-gray-400">${join(compact([swatch, paint]))}</span>`
    })
    return html`<tr class="tw:even:bg-gray-100 tw:dark:even:bg-gray-800"><td class="${CELL} ${differs ? 'tw:spec-diff' : ''}">${label}</td><td class=${CELL}>${money}</td><td
      class=${CELL}><div class="tw:flex tw:flex-wrap tw:items-center tw:gap-x-3 tw:gap-y-1">${swatches}</div></td></tr>`
  })
  return html`<section class="tw:mb-6 tw:break-inside-avoid tw:space-y-2"><h2 class="tw:border-b tw:border-vellum tw:pb-1.5 tw:spec-eyebrow">Model years</h2><table
    class="tw:w-full tw:border-collapse tw:text-left"><tbody>${rows}</tbody></table></section>`
}
