import { html, nothing } from 'lit-html'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { card } from 'bikebook/templates/ui/card'
import { collapse } from 'bikebook/templates/ui/collapse'
import { iconChevron } from 'bikebook/templates/ui/icon_chevron'
import { checkbox } from 'bikebook/templates/ui/forms/checkbox'
import { radioButtonGroup } from 'bikebook/templates/ui/forms/radio_button_group'
import { range } from 'bikebook/templates/ui/forms/range'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { GROUPS, MAX_WEIGHT, PRESETS, presetOf } from 'bikebook/similarity'

// CycleType::ALWAYS_MOTORIZED, by the catalog's slugs
const ALWAYS_MOTORIZED = ['e_scooter', 'epamd', 'e_motorcycle']

const note = (content) => html`<div class="tw:mt-4 tw:rounded-md tw:bg-blue-50 tw:px-4 tw:py-3 tw:text-sm tw:dark:bg-blue-950">${content}</div>`

// The `cards` of the models a scorer found beside the one compared against, or why there are none: no `results` where
// the catalog's comparison is a format it doesn't know, out to the window's edges with as many as fit at the search's
// cards' width. Once the comparison is `full`, only its own cards link
export const similarResults = ({ results, cards, full }) => {
  if (!results) return note("Similar models can't be found right now.")
  if (!results.models.length) {
    return note(results.groups.length ? 'No similar models are in the catalog.' : 'Too little is listed about this model to find similar ones.')
  }
  return html`${full ? note(`Compare up to ${full} at once. Remove one to add another.`) : nothing}<ul aria-label="Similar models to compare"
    class="tw:mt-4 tw:grid tw:grid-cols-[repeat(auto-fill,minmax(17rem,1fr))] tw:gap-4 tw:twpagebleed tw:px-4">${cards}</ul>`
}

const compareLabel = (type, model) => `Compare similar ${type}s to ${model}`

// On the search's More filters lines, what opens the similar models' section beneath them, whose own toggle takes over
// once it's open. Not a ui--collapse trigger, which the search's own would claim
export const compareToggle = ({ type, model }) => html`<button type="button" data-action="bikebook--page#compareSimilar" class=${buttonClasses({
  color: 'link',
  htmlClass: 'tw:not-data-[active=true]:[font-weight:inherit] tw:similar-open:hidden'
})}><span class="tw:inline-block"><span class="tw:flex">${iconChevron()}</span></span>${compareLabel(type, model)}</button>`

// Collapsed until it's wanted, the models most like the first compared, `model`, whose `results` bikebook--similar scores
// once it opens, and the controls that rescore them in place unless the open filters hold them. With the search showing,
// its toggle shows only once it's open, compareToggle opening it
export const similarSection = ({ model, results, searchShown, inFilters, ...similar }) => {
  const { vehicle, type } = similar
  const scored = results !== undefined
  const label = html`<span class="tw:group-aria-expanded/similar:hidden">${compareLabel(type, model)}</span><span
    class="tw:hidden tw:group-aria-expanded/similar:inline">Hide similar ${type}s</span>`
  return html`<section aria-label="Similar models" class="tw:flex tw:flex-wrap tw:items-baseline" data-controller="bikebook--similar ui--collapse"
    data-bikebook--similar-vehicle-value=${vehicle} data-bikebook--similar-scored-value=${scored} data-ui--collapse-param-value="similar"
    data-action="ui--collapse:shown->bikebook--similar#load:self">${collapse({
      content: label,
      chevron: true,
      color: 'link',
      htmlClass: `tw:group/similar tw:aria-expanded:mt-3 ${searchShown ? 'tw:not-aria-expanded:hidden' : ''}`,
      attributes: { id: 'similar-toggle' }
    })}${inFilters ? nothing : similarAdjustments({ ...similar, scored })}<div data-ui--collapse-target="content"
    class="tw:hidden tw:w-full">${scored
      ? html`<div id="similar-results">${results}</div>`
      : html`<p class="tw:mt-4 tw:text-sm tw:text-gray-500">Finding similar ${type}s…</p>`}</div></section>`
}

const CUSTOM = tooltip({ body: 'If you change a weight, this will be selected', content: 'Custom' })

const legend = (text) => html`<legend class="twlabel">${text}</legend>`

// The controls that rescore the similar models once they're scored, each with its own bikebook--similar and ui--collapse.
// Beside the section's toggle, outside its content so they share a line, laid into its row by display: contents, they open
// a card of their own, their toggle moving into it as More filters' does; `inFilters`, at the foot of the open filters'
// card, they extend it
export const similarAdjustments = ({ vehicle, type, vehicleType, electric, complete, current, settings, groups, scored, inFilters = false }) => {
  if (!scored || !groups?.length) return nothing

  const propulsion = electric ? !ALWAYS_MOTORIZED.includes(vehicleType) && `Show matching human powered ${type}s` : `Show matching e-${type}s`
  const configuration = complete ? `Only complete ${type}s` : 'Only frames & forks'
  const fields = controls(groups, settings, type, propulsion, configuration, current)
  const toggle = collapse({ content: 'Adjust comparison algorithm', chevron: true, color: 'link', size: 'sm', htmlClass: 'tw:text-sm' })
  if (inFilters) {
    return html`<div class="tw:hidden tw:similar-open:block" data-controller="bikebook--similar ui--collapse" data-ui--collapse-param-value="adjust"
    data-bikebook--similar-vehicle-value=${vehicle} data-action="input->bikebook--similar#change">${toggle}<div data-ui--collapse-target="content"
    class="tw:hidden"><div class="tw:mt-4">${fields}</div></div></div>`
  }
  return html`<div class="tw:hidden tw:similar-open:contents" data-controller="bikebook--similar ui--collapse" data-ui--collapse-param-value="adjust"
  data-bikebook--similar-vehicle-value=${vehicle} data-action="input->bikebook--similar#change"><div
  class="tw:ml-auto tw:has-[[aria-expanded=true]]:hidden">${toggle}</div><div data-ui--collapse-target="content" class="tw:hidden tw:w-full"><div
  class="twwiderow">${card({ fullBleed: true, additionalClasses: 'tw:col-span-full tw:mt-3', content: html`<div class="tw:text-right">${toggle}</div>${fields}` })}</div></div></div>`
}

// Custom is chosen only by moving a slider off every preset, each of the `listed` groups', the rest's disabled, as the
// model has nothing of theirs to compare
const controls = (listed, { weights, onlyCurrent, skipManufacturer, otherPropulsion, sameConfiguration, sameWheels, differentTypes }, type, propulsion, configuration, current) => {
  const preset = presetOf(weights, listed)
  return html`<div class="tw:space-y-4"><fieldset aria-label="Strategy">${radioButtonGroup({
    name: 'strategy',
    selected: preset,
    entries: [...Object.entries(PRESETS).map(([value, { label }]) => ({ value, label })), { value: 'custom', label: CUSTOM, disabled: preset !== 'custom' }],
    attributes: { 'data-bikebook--similar-target': 'strategy', 'data-action': 'bikebook--similar#strategy:stop' }
  })}</fieldset><fieldset>${legend('Weightings')}<div class="tw:mt-1 tw:grid tw:gap-x-6 tw:gap-y-5 tw:sm:grid-cols-2
  tw:lg:grid-cols-3">${Object.keys(GROUPS).map((group) => {
    const scored = listed.includes(group)
    // an unlisted group's slider a bare track in a slider's box, showing no weight, which stays the URL's or a strategy's
    return html`<div class=${scored
      ? ''
      : 'tw:[&_output]:invisible tw:[&_input]:appearance-none tw:[&_input]:h-4 tw:[&_input]:py-1 tw:[&_input]:bg-clip-content tw:[&_input]:rounded-full tw:[&_input]:bg-gray-200 tw:dark:[&_input]:bg-gray-700 ' +
        'tw:[&_input::-webkit-slider-thumb]:appearance-none tw:[&_input::-moz-range-thumb]:opacity-0'}>${range({
      name: group,
      label: GROUPS[group].label,
      minLabel: scored ? 'Ignore' : `Not listed for this ${type}`,
      maxLabel: scored ? `Only same ${GROUPS[group].same ?? GROUPS[group].label.toLowerCase()}` : null,
      value: scored ? weights[group] : 0,
      max: MAX_WEIGHT,
      attributes: { id: `similar-${group}`, disabled: !scored, 'data-bikebook--similar-target': scored && 'weight' }
    })}</div>`
  })}</div></fieldset><fieldset>${legend('Other settings')}<div class="tw:mt-1 tw:space-y-1">${
    setting('only_current', `Only show current ${type}s`, onlyCurrent ?? current, current)}${setting('skip_manufacturer', `Skip ${type}s from the same manufacturer`, skipManufacturer)}${
    propulsion ? setting('other_propulsion', propulsion, otherPropulsion) : nothing}${setting('same_configuration', configuration, sameConfiguration)}${
    setting('same_wheels', `Only match ${type}s with the same wheel size`, sameWheels)}${
    setting('different_types', 'Include different vehicle types', differentTypes)}</div></fieldset></div>`
}

// each a URL param of its name, 1 while it's checked, or 0 unchecked where it's `checkedByDefault`
const setting = (name, label, checked, checkedByDefault = false) => checkbox({
  name,
  label,
  checked,
  className: 'tw:mb-0 tw:text-sm tw:font-normal',
  attributes: { id: `similar-${name}`, 'data-bikebook--similar-target': 'setting', 'data-checked-by-default': checkedByDefault }
})
