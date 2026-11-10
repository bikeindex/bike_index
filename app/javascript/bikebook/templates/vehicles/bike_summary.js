import { html, nothing } from 'lit-html'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { definitionListRow } from 'bikebook/templates/ui/definition_list/row'
import { join, present } from 'bikebook/templates/values'
import { ulBadges } from 'bikebook/templates/vehicles/page_badges'

const NOT_CYCLES = { e_scooter: 'scooter', e_motorcycle: 'motorcycle', epamd: 'personal mobility' }

// Pages::EbikeRules::BikeSummary::Component, its UL badges copies of the ones the page renders
export const bikeSummary = ({ vehicleType, tiles, specs, ul2849, ul2271, others }) => html`<div class="tw:flex tw:flex-col tw:gap-5">${present(tiles)
  ? html`<div class="tw:flex tw:flex-col tw:items-start tw:gap-3.5"><h3 class="tw:text-[15px] tw:font-bold">E-${NOT_CYCLES[vehicleType] ?? 'bike'} classification</h3>${tiles}</div>`
  : nothing}<div
  class="tw:border-y tw:border-gray-200 tw:py-4 tw:dark:border-gray-700">${definitionListContainer({
    term: 'below',
    content: join(specs.map(([label, value]) => definitionListRow({ label, value, noValueText: 'Not provided' })))
  })}</div><div class="tw:flex tw:flex-col tw:items-start tw:gap-3.5"><h3 class="tw:text-[15px] tw:font-bold">Electric Certification</h3>${
    ulBadges({ ul2849, ul2271 })}${others ? html`<p class="tw:text-sm">${others}</p>` : nothing}</div></div>`
