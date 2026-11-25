import { html } from 'lit-html'

// A catalog combobox's pick's stock photo, below the field. `failed` is called if it doesn't load
export const pickedPhoto = ({ photo, alt, failed }) => html`<img alt=${alt} class="tw:h-40 tw:w-auto tw:max-w-full tw:rounded-md
  tw:bg-white tw:object-contain tw:p-2" src=${photo} @error=${failed}>`
