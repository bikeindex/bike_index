import { html, nothing } from 'lit-html'
import { dropdown } from 'bikebook/templates/ui/dropdown'
import { MODEL_CARDS_CLASSES, modelCard } from 'bikebook/templates/vehicles/model_card'

// Which of a model group's years are `shown`, toggled by `yearsPath`, and the models sold in any of them - each card linking to
// `vehiclePath` of its model. A toggle replaces the history entry, and the menu stays open across the render it causes
export const modelGroup = ({ group: { name, manufacturer, shown, years, models }, yearsPath, vehiclePath, ...card }) => html`<section
  id="model-group" tabindex="-1" aria-labelledby="model-group-name" class="tw:mt-8 tw:focus:outline-none" data-in-place="#group-year"
  data-replace><p class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p><div
  class="tw:flex tw:items-baseline tw:gap-3" data-stays-open><h2 id="model-group-name" class="tw:text-2xl tw:leading-tight
  tw:font-extrabold">${name}</h2>${dropdown({
    name: 'Group year',
    button: shown.join(', '),
    buttonSize: 'sm',
    entries: years.map((each) => yearToggle(each, shown, yearsPath))
  })}</div><ul aria-label=${`${name} models in ${shown.join(', ')}`} class="tw:mt-3 ${MODEL_CARDS_CLASSES}">${models.map((model) =>
    modelCard({ model, href: vehiclePath(model.id), ...card }))}</ul></section>`

// the last year shown stays, rather than leaving none
const yearToggle = (year, shown, yearsPath) => {
  const checked = shown.includes(year)
  const toggled = checked ? shown.filter((each) => each !== year) : [...shown, year].sort((a, b) => b - a)
  return html`<a href=${yearsPath(toggled.length ? toggled : shown)} id="group-year-${year}" role="menuitemcheckbox"
    aria-checked=${checked ? 'true' : 'false'} class="tw:flex! tw:items-center tw:gap-2"><span aria-hidden="true" class="tw:inline-flex
    tw:size-4 tw:items-center tw:justify-center tw:rounded-sm tw:border tw:text-xs ${checked
      ? 'tw:border-purple-500 tw:bg-purple-500 tw:text-white'
      : 'tw:border-gray-400'}">${checked ? '✓' : nothing}</span>${year}</a>`
}
