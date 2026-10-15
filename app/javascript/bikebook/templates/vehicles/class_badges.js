import { html, nothing } from 'lit-html'
import { uuid } from 'bikebook/templates/helpers'

// The US classes' tiles by number, and 'emoto' the e-moto's, in a row, each a tooltip of its card, from the ones the
// page renders once as templates. Each copy gets its own tooltip id, as two models can share a class
export const classBadges = (classes) => {
  const badges = classes.flatMap((each) => {
    const template = document.querySelector(`template[data-bikebook-class-badge="${each}"]`)
    if (!template) return []

    const badge = template.content.cloneNode(true)
    const id = `tooltip-${uuid()}`
    badge.querySelector('[role="tooltip"]')?.setAttribute('id', id)
    badge.querySelector('[aria-describedby]')?.setAttribute('aria-describedby', id)
    return [badge]
  })
  return badges.length ? html`<span class="tw:mt-2 tw:flex tw:gap-2">${badges}</span>` : nothing
}
