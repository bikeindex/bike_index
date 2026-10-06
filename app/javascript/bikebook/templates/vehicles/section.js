import { html, nothing } from 'lit-html'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { blank, present } from 'bikebook/templates/values'

// A headed list of spec rows. `subsections` are [heading, rows] pairs
export const section = ({ heading, content, subsections = [] }) => {
  // a compared model's values give this one rows it has nothing for
  const shown = subsections.filter(([, rows]) => present(rows))
  return blank(content) && shown.length === 0
    ? nothing
    : html`<section class="tw:mb-6 tw:break-inside-avoid tw:space-y-2">${present(heading) ? html`<h2 class="tw:border-b tw:border-gray-200 tw:dark:border-gray-700 tw:pb-1.5 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${heading}</h2>` : nothing}${
    definitionListContainer({ content })}${shown.map(([subheading, rows]) => html`<h3 class="tw:pt-2 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${subheading}</h3>${
      definitionListContainer({ content: rows })}`)}</section>`
}
