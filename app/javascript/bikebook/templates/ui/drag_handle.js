import { html } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'

// UI::DragHandle::Component, a grip registering as the `controller`'s handle target
export const dragHandle = ({ controller, htmlClass }) => html`<span ${attributes({ [`data-${controller}-target`]: 'handle' })}
  aria-hidden="true" style="touch-action:none" class=${['tw:cursor-grab tw:select-none tw:text-gray-400', htmlClass].filter(Boolean).join(' ')}>⠿</span>`
