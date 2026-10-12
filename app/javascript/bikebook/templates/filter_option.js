import { html } from 'lit-html'
import { numberDisplay, uuid } from 'bikebook/templates/helpers'

// A filter combobox's option as hotwire_combobox renders one, how many models it matches after its name
export const filterOption = ({ value, display, count }) => html`<li id=${uuid()} role="option" tabindex="-1" class="hw-combobox__option"
  data-action="click->hw-combobox#selectOnClick" data-filterable-as=${display} data-autocompletable-as=${display} data-value=${value}
  aria-selected="false">${display} <span class="twless-strong">(${numberDisplay(count)})</span></li>`
