import { html, nothing } from 'lit-html'

// A catalog combobox's pick's stock photo, below the field. Nothing for a pick without one, and hidden once it fails to load
export const pickedPhoto = (photo, alt) => photo
  ? html`<div class="tw:group tw:mt-3" data-controller="image-fallback"><img alt=${alt} class="tw:h-40 tw:w-auto tw:max-w-full
    tw:rounded-md tw:bg-white tw:object-contain tw:p-2 tw:group-data-broken:hidden" data-action="error->image-fallback#fallBack" src=${photo}></div>`
  : nothing
