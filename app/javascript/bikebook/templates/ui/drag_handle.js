import { html, nothing } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'

// UI::DragHandle::Component, a grip registering as the `controller`'s handle target. An id, which the
// component doesn't take, is what keeps it focused through a bikebook--page render
export const dragHandle = ({ controller, label, htmlClass, id }) => html`<button type="button" id=${id ?? nothing} aria-label=${`Move ${label}`}
  style="touch-action:none" class=${['tw:cursor-grab tw:select-none tw:text-gray-400', htmlClass].filter(Boolean).join(' ')}
  ${attributes({ [`data-${controller}-target`]: 'handle', 'data-action': `keydown->${controller}#moveByKey` })}
  data-moved-message="Position %{position} of %{count}">⠿</button>`
