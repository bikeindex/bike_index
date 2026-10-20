import { html } from 'lit-html'

// app/assets/images/icons, as inline_svg_tag renders them. All but the chevron are decorative

export const check = (className) => html`<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor"
  stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24" aria-hidden="true"
  class=${className}><path d="M20 6 9 17l-5-5"></path></svg>`

export const chevronRight = (className) => html`<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"
  fill="currentColor" viewBox="0 0 16 16" class=${className}><path fill-rule="evenodd"
  d="M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708"></path></svg>`

export const copy = (className) => html`<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor"
  stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 20 20" aria-hidden="true"
  class=${className}><rect x="6.75" y="6.75" width="10.5" height="10.5" rx="1.5"></rect><path
  d="M13.25 6.75v-2.5a1.5 1.5 0 0 0-1.5-1.5h-7.5a1.5 1.5 0 0 0-1.5 1.5v7.5a1.5 1.5 0 0 0 1.5 1.5h2.5"></path></svg>`

export const x = (className) => html`<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor"
  stroke-width="2" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 14 14" aria-hidden="true"
  class=${className}><path d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"></path></svg>`
