import { html, nothing } from 'lit-html'
import { uuid } from 'bikebook/templates/helpers'

// Copies of the badges the page renders once as templates under `attribute`, by `keys`, in a row. Each copy gets its
// own tooltip id, as two models can share a badge
const copies = (attribute, keys, classes) => {
  const badges = keys.flatMap((key) => {
    const template = document.querySelector(`template[${attribute}="${key}"]`)
    if (!template) return []

    const badge = template.content.cloneNode(true)
    const id = `tooltip-${uuid()}`
    badge.querySelector('[role="tooltip"]')?.setAttribute('id', id)
    badge.querySelector('[aria-describedby]')?.setAttribute('aria-describedby', id)
    return [badge]
  })
  return badges.length ? html`<span class=${classes}>${badges}</span>` : nothing
}

// The US classes' tiles by number, '2/throttle' for one only an optional throttle brings, and 'emoto' the e-moto's,
// 'emoto/US-CA' out of class in that jurisdiction alone, each a tooltip of its card
export const classBadges = (classes) => copies('data-bikebook-class-badge', classes, 'tw:flex tw:gap-2')

// The UL badges for a bike's statuses, as Pages::EbikeRules::BikeSummary has them: the certifications it carries, else
// the one saying neither is known. Each a tooltip of what it means
export const ulBadges = ({ ul2849, ul2271 }) => {
  const certified = [['2849', ul2849], ['2271', ul2271]].filter(([, status]) => status === 'certified').map(([standard]) => `${standard}/certified`)
  return copies('data-bikebook-ul-badge', certified.length ? certified : ['unknown'], 'tw:flex tw:flex-wrap tw:gap-2')
}

// The motors' `certifications`, each a comma-separated list: UL 2849's and 2271's statuses, certified or not known to
// be, and any other they list
export const certificationsOf = (certifications) => {
  const listed = [...new Set(certifications.flatMap((each) => String(each ?? '').split(/,\s*/)).filter(Boolean))]
  const status = (standard) => listed.includes(`UL ${standard}`) ? 'certified' : 'unknown'
  return { ul2849: status(2849), ul2271: status(2271), others: listed.filter((each) => !/^UL (2849|2271)$/.test(each)).join(', ') }
}

// As /ebike-rules shows them: UL 2849's and 2271's badges, then any other the motors' `certifications` list
export const certificationBadges = (certifications) => {
  const { ul2849, ul2271, others } = certificationsOf(certifications)
  return html`${ulBadges({ ul2849, ul2271 })}${others ? html`<span class="tw:mt-2 tw:block">${others}</span>` : nothing}`
}
