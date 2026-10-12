import { html, nothing } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { iconChevron } from 'bikebook/templates/ui/icon_chevron'

const ACTIONS = 'mousedown->ui--collapse#press click->ui--collapse#toggle keydown.enter->ui--collapse#toggle:prevent ' +
  'keydown.space->ui--collapse#toggle:prevent'

// UI::Collapse::Component in the secondary color, the trigger for a ui--collapse controller on an
// ancestor, its chevron leading. `attributes` is its aria and html_options
export const collapse = ({ content, chevron = false, size, htmlClass, attributes: htmlOptions = {} }) => html`<span
  ${attributes(htmlOptions)} role="button" tabindex="0" class=${buttonClasses({ size, htmlClass })} aria-expanded="false"
  data-ui--collapse-target="trigger" data-action=${ACTIONS}>${chevron
    ? html`<span class="tw:inline-block tw:transition-transform tw:duration-200" data-ui--collapse-target="chevron"><span
      class="tw:flex">${iconChevron()}</span></span>`
    : nothing}${content}</span>`
