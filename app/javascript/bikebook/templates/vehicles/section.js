import { html, nothing } from 'lit-html'
import { collapse } from 'bikebook/templates/ui/collapse'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { blank, present } from 'bikebook/templates/values'

export const sectionHeading = (heading) => html`<h2 class="tw:border-b tw:border-gray-200 tw:dark:border-gray-700 tw:pb-1.5 tw:text-xs tw:font-bold
  tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${heading}</h2>`

// A headed list of spec rows. `subsections` are [heading, rows] pairs
export const section = ({ heading, content, subsections = [] }) => {
  // a compared model's values give this one rows it has nothing for
  const shown = subsections.filter(([, rows]) => present(rows))
  return blank(content) && shown.length === 0
    ? nothing
    : html`<section class="tw:mb-6 tw:break-inside-avoid tw:space-y-2">${present(heading) ? sectionHeading(heading) : nothing}${
    definitionListContainer({ content })}${shown.map(([subheading, rows]) => html`<h3 class="tw:pt-2 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${subheading}</h3>${
      definitionListContainer({ content: rows })}`)}</section>`
}

// A section whose heading's chevron opens and closes its content (ui--collapse), rendered open
// unless the content is hidden. A `param` keeps its state in the URL
export const disclosure = ({ param, label, heading, content }) => html`<section class="tw:group/disclosure tw:space-y-2"
  data-controller="ui--collapse" data-ui--collapse-param-value=${param ?? nothing}><div class="tw:flex tw:items-baseline tw:justify-between tw:gap-3"><h2
  class="tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${heading}</h2>${collapse({ chevron: true, size: 'sm', attributes: { 'aria-label': `Toggle ${label}` } })}</div>${content}</section>`
