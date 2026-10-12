import { html } from 'lit-html'

const PANEL_CLASSES = 'tw:flex tw:flex-col tw:gap-2.5 tw:break-words tw:[&>div]:pt-0 tw:[&>div>dt]:text-[13px] ' +
  'tw:[&>div>dd]:text-[13.5px] tw:[&>div>dd]:font-semibold'

// UI::DefinitionList::Container::Component, single column with the term left or right aligned
export const definitionListContainer = ({ term = 'left_align', content }) =>
  html`<dl class=${term === 'right_align' ? PANEL_CLASSES : 'tw:@container tw:break-words'}>${content}</dl>`
