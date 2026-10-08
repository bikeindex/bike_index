import { html, nothing } from 'lit-html'
import { copyableCode } from 'bikebook/templates/ui/copyable_code'
import { definitionListRow } from 'bikebook/templates/ui/definition_list/row'
import { removeLink } from 'bikebook/templates/vehicles/remove_link'
import { section, sectionHeading } from 'bikebook/templates/vehicles/section'
import { array, join } from 'bikebook/templates/values'

const listSection = (heading, items) => items.length === 0
  ? nothing
  : html`<section class="tw:mb-6 tw:space-y-2">${sectionHeading(heading)}<ul class="tw:list-disc tw:space-y-1 tw:pl-5 tw:text-sm">${
    items.map((item) => html`<li>${item}</li>`)}</ul></section>`

// a schema date is a calendar day, so it's read and written in UTC to keep it from shifting a day
const day = (date) => date && new Date(`${date}T00:00:00Z`).toLocaleDateString('en-US', { dateStyle: 'long', timeZone: 'UTC' })

const restriction = ({ rule, starts_on: startsOn, ends_on: endsOn }) => {
  const until = endsOn ? `until ${day(endsOn)}` : ''
  const dates = startsOn ? `From ${day(startsOn)} ${until}`.trim() : until.replace('u', 'U')
  return dates ? html`<span class="tw:font-semibold">${dates}:</span> ${rule}` : rule
}

// An e-vehicle classification's card, beside the compared vehicles', linking to the groups it's in or, for a group,
// the classifications in it
export const classificationCard = ({ presenter, id, classification, removePath, classificationPath }) => {
  const { title, jurisdiction, description, throttle, max_speed: maxSpeed, max_throttle_speed: maxThrottleSpeed, min_power: minPower, max_power: maxPower, limits_start_on: limitsStartOn, groups, restrictions, sources } = classification
  const rows = join([
    definitionListRow({ label: 'ID', content: copyableCode({ value: id, label: 'Copy ID' }) }),
    definitionListRow({ label: 'Jurisdiction', value: jurisdiction }),
    definitionListRow({ label: 'Throttle', value: presenter.measurement(throttle) }),
    definitionListRow({ label: 'Max speed', value: presenter.measurement(maxSpeed, 'km/h') }),
    definitionListRow({ label: 'Max throttle speed', value: presenter.measurement(maxThrottleSpeed, 'km/h') }),
    definitionListRow({ label: 'Min power', value: presenter.measurement(minPower, 'w') }),
    definitionListRow({ label: 'Max power', value: presenter.measurement(maxPower, 'w') }),
    definitionListRow({ label: 'Limits take effect', value: day(limitsStartOn) })
  ])
  const linked = (ids) => ids.map((each) => html`<a class="twlink" href=${classificationPath(each)}>${presenter.classificationName(each)}</a>`)
  const all = presenter.vocabulary.e_vehicle_classifications ?? {}
  const members = Object.keys(all).filter((each) => array(all[each].groups).includes(id))
  // a binding doesn't sanitize an href, so a source that isn't a web page isn't a link
  const links = array(sources).filter((source) => /^https?:\/\//.test(source))
    .map((source) => html`<a class="twlink tw:break-all" target="_blank" rel="noopener" href=${source}>${source}</a>`)
  return html`<div class="tw:md:w-[26rem] tw:md:shrink-0" data-controller="ui--alert"><article class="twgutter tw:space-y-6 tw:rounded-sm
    tw:border tw:border-gray-200 tw:dark:border-gray-700 tw:bg-white tw:dark:bg-gray-800 tw:pt-4 tw:pb-6 tw:[--gutter:--spacing(6)]"><header><div
    class="tw:flex tw:items-start tw:gap-4"><p class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">E-vehicle
    classification</p>${removeLink({ label: `Remove ${title}`, href: removePath })}</div><h1 class="tw:text-2xl tw:leading-tight tw:font-extrabold">${
    title}</h1></header><p>${description}</p>${section({ content: rows })}${listSection('Groups', linked(array(groups)))}${listSection('Classifications in this group', linked(members))}${
    listSection('Restrictions', array(restrictions).map(restriction))}${
    listSection('Sources', links)}</article></div>`
}
