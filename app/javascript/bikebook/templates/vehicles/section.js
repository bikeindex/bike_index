import { html, nothing } from 'lit-html'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { blank, present } from 'bikebook/templates/values'

// A headed list of spec rows. `subsections` are [heading, rows] pairs
export const section = ({ heading, content, subsections = [] }) => blank(content) && subsections.length === 0
  ? nothing
  : html`<section class="tw:mb-6 tw:break-inside-avoid tw:space-y-2">${present(heading) ? html`<h2 class="tw:border-b tw:border-vellum tw:pb-1.5 tw:spec-eyebrow">${heading}</h2>` : nothing}${
    definitionListContainer({ content })}${subsections.map(([subheading, rows]) => html`<h3 class="tw:pt-2 tw:spec-eyebrow">${subheading}</h3>${
      definitionListContainer({ content: rows })}`)}</section>`
