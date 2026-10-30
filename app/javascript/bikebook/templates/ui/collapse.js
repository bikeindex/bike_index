import { html, nothing } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'
import { buttonClasses, LINK_COLORS } from 'bikebook/templates/ui/button'
import { iconChevron } from 'bikebook/templates/ui/icon_chevron'

const ACTIONS = 'mousedown->ui--collapse#press click->ui--collapse#toggle keydown.enter->ui--collapse#toggle:prevent ' +
  'keydown.space->ui--collapse#toggle:prevent'

// UI::Collapse::Component in the secondary or a link color, the trigger for a ui--collapse controller on an ancestor, its
// chevron leading, or following for 'trailing'. `attributes` is its aria and html_options
export const collapse = ({ content, chevron = false, color = 'secondary', size, htmlClass, attributes: htmlOptions = {} }) => {
  const chevronSpan = chevron
    ? html`<span class="tw:inline-block tw:transition-transform tw:duration-200" data-ui--collapse-target="chevron"><span
      class="tw:flex">${iconChevron()}</span></span>`
    : nothing
  // as UI::Collapse::Component pins a link color's weight, which bolds while active
  const classes = [buttonClasses({ size, htmlClass, color }),
    LINK_COLORS.includes(color) && !String(htmlClass ?? '').includes('tw:font-') && 'tw:not-data-[active=true]:[font-weight:inherit]'].filter(Boolean).join(' ')
  return html`<span ${attributes(htmlOptions)} role="button" tabindex="0" class=${classes} aria-expanded="false"
    data-ui--collapse-target="trigger" data-action=${ACTIONS}>${chevron === 'trailing' ? html`${content}${chevronSpan}` : html`${chevronSpan}${content}`}</span>`
}
