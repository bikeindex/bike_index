import { html } from 'lit-html'

const PANEL_CLASSES = 'tw:flex tw:flex-col tw:gap-2.5 tw:break-words tw:[&>div]:pt-0 tw:[&>div>dt]:text-[13px] ' +
  'tw:[&>div>dd]:text-[13.5px] tw:[&>div>dd]:font-semibold'

const BELOW_CLASSES = 'tw:grid tw:grid-cols-2 tw:gap-x-5 tw:gap-y-[18px] tw:break-words tw:lg:grid-cols-3 ' +
  'tw:[&>div]:block tw:[&>div]:pt-0 ' +
  'tw:[&>div>dt]:mb-[3px] tw:[&>div>dt]:text-[11.5px] ' +
  'tw:[&>div>dd]:text-left tw:[&>div>dd]:text-[14px] tw:[&>div>dd]:font-medium'
const CLASSES = { left_align: 'tw:@container tw:break-words', right_align: PANEL_CLASSES, below: BELOW_CLASSES }

// UI::DefinitionList::Container::Component, single column with the term left or right aligned, or below each value
export const definitionListContainer = ({ term = 'left_align', content }) => html`<dl class=${CLASSES[term]}>${content}</dl>`
