import { html, nothing } from 'lit-html'
import { dropdown } from 'bikebook/templates/ui/dropdown'
import { MODEL_CARDS_CLASSES, modelCard } from 'bikebook/templates/vehicles/model_card'

// A model group's models sold in its `year`, which its menu switches between the years it has any in, in place of the
// history entry - each card linking to `vehiclePath` of its model
export const modelGroup = ({ group: { name, manufacturer, year, years, models }, yearPath, vehiclePath, ...card }) => html`<section
  id="model-group" tabindex="-1" aria-labelledby="model-group-name" class="tw:mt-8 tw:focus:outline-none" data-in-place="#group-year"
  data-replace><p class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p><div
  class="tw:flex tw:items-baseline tw:justify-between tw:gap-4"><h2 id="model-group-name" class="tw:text-2xl tw:leading-tight
  tw:font-extrabold">${name}</h2>${dropdown({
    name: 'Group year',
    button: year,
    buttonSize: 'sm',
    entries: years.map((each) => html`<a href=${yearPath(each)} aria-current=${each === year ? 'true' : nothing}>${each}</a>`)
  })}</div><ul aria-label=${`${name} models in ${year}`} class="tw:mt-3 ${MODEL_CARDS_CLASSES}">${models.map((model) =>
    modelCard({ model, href: vehiclePath(model.id), ...card }))}</ul></section>`
