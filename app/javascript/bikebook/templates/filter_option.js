import { html, nothing } from 'lit-html'
import { numberDisplay, uuid } from 'bikebook/templates/helpers'

// A filter combobox's option as hotwire_combobox renders one, how many models it matches after its name -
// or, given a name, the code its display ends in
export const filterOption = ({ value, display, name, count }) => html`<li id=${uuid()} role="option" tabindex="-1" class="hw-combobox__option"
  data-action="click->hw-combobox#selectOnClick" data-filterable-as=${display} data-autocompletable-as=${display} data-value=${value}
  data-name=${name ?? nothing} aria-selected="false">${name ?? display} <span class="twless-strong">(${name ? value : numberDisplay(count)})</span></li>`
