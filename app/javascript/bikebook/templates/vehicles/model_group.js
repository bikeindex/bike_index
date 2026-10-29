import { html } from 'lit-html'
import { MODEL_CARDS_CLASSES, modelCard } from 'bikebook/templates/vehicles/model_card'

// whole years, as many as make a page of at least this many models
const PAGE_SIZE = 24

// A model group's models under each year, newest first, a page at a time as the reader scrolls - each card linking to
// `vehiclePath` of its model
export const modelGroup = ({ group: { name, manufacturer, years }, vehiclePath, ...card }) => html`<section id="model-group"
  tabindex="-1" aria-labelledby="model-group-name" class="tw:mt-8 tw:focus:outline-none" data-controller="bikebook--infinite-scroll"><p
  class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p><h2 id="model-group-name"
  class="tw:text-2xl tw:leading-tight tw:font-extrabold">${name}</h2>${pages(years).map((page, index) => html`<div
  ?hidden=${index > 0} data-bikebook--infinite-scroll-target="page">${page.map(({ year, models }) => html`<h3
  id="model-group-${year}" class="tw:mt-6 tw:mb-3 tw:text-lg tw:font-bold">${year}</h3><ul aria-labelledby="model-group-${year}"
  class=${MODEL_CARDS_CLASSES}>${models.map((model) => modelCard({ model, href: vehiclePath(model.id), ...card }))}</ul>`)}</div>`)}<div
  data-bikebook--infinite-scroll-target="sentinel"></div></section>`

const pages = (years) => years.reduce((paged, year) => {
  const last = paged.at(-1)
  return last && last.reduce((count, { models }) => count + models.length, 0) < PAGE_SIZE
    ? [...paged.slice(0, -1), [...last, year]]
    : [...paged, [year]]
}, [])
