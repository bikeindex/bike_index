import { html, nothing } from 'lit-html'
import { localSources } from 'utils/hw_combobox_patch'
import { optionChips } from 'bikebook/catalog'
import { fragmentOf } from 'bikebook/render'
import { filterOption } from 'bikebook/templates/filter_option'
import { MODEL_CARDS_CLASSES, modelCard } from 'bikebook/templates/vehicles/model_card'

// A model group's models sold in any of the `shown` years, which the combobox beside its name picks - each card
// linking to `vehiclePath` of its model
export const modelGroup = ({ group: { name, manufacturer, shown, years, models }, vehiclePath, ...card }) => html`<section
  id="model-group" tabindex="-1" aria-labelledby="model-group-name" class="tw:mt-8 tw:focus:outline-none"><p class="tw:mb-1
  tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p><div class="tw:relative tw:z-20 tw:flex tw:flex-wrap
  tw:items-baseline tw:gap-x-4 tw:gap-y-2"><h2 id="model-group-name" class="tw:text-2xl tw:leading-tight tw:font-extrabold">${name}</h2>${yearsField(
    `${manufacturer} ${name} ${shown}`, years, shown)}</div><ul aria-label=${`${name} models in ${[...shown].sort().join(', ')}`}
  class="tw:mt-3 ${MODEL_CARDS_CLASSES}">${models.map((model) => modelCard({ model, href: vehiclePath(model.id), ...card }))}</ul></section>`

// A copy of the page's group years combobox. Permanent while the years it shows are, so the render a pick causes
// keeps it open as it was
const yearsField = (permanent, years, shown) => {
  const form = document.querySelector('template[data-bikebook-group-years]')?.content.querySelector('form').cloneNode(true)
  if (!form) return nothing

  form.id = 'group-years'
  form.dataset.permanent = permanent
  form.querySelector('#group_years-hw-listbox').append(fragmentOf(years.map((year) => filterOption({ value: year, display: year }))))
  form.querySelector('#group_years-hw-hidden-field').setAttribute('value', shown.join(','))
  localSources.set(form.querySelector('.hw-combobox'), optionChips)
  return form
}
