import { html, nothing } from 'lit-html'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { definitionListRow } from 'bikebook/templates/ui/definition_list/row'
import { figureLetter } from 'bikebook/templates/vehicles/cycle_drawing'
import { array, equal, except, isHash, presence, present } from 'bikebook/templates/values'

// A size's geometry, marked where the same-named size in `others` differs, and ringed when it's the size compared, its
// name otherwise a link to `href`, which compares it in place. A figure in `letters`, a key's letter, is lettered as its drawing has it.
// After it its vehicle's `cargo` area, against `otherCargos`, and its `wheels`, [label, content]. A letter is a link to its `figurePath`, `highlight` the key of the figure lit,
// which where it's one of the `drawn` size's figures it doesn't list, goes above its geometry with the value it's drawn at
export const geometryCard = ({ presenter, size, others, selected, href, letters = new Map(), highlight, figurePath, drawn, wheels = [], cargo, otherCargos = [] }) => {
  const { labels, extras_key: extrasKey, dimensions } = presenter.kit.geometry
  const geometry = size.geometry ?? {}
  const othersGeometry = others.map((sizes) => array(sizes).find((other) => equal(other.name, size.name))?.geometry)
  const sizeTravels = Object.values(presenter.kit.viewer.suspensions).map(({ size_travel: sizeTravel }) => sizeTravel)
  const rows = presenter.rowsFor(except(presenter.kit.schemas.geometry, [extrasKey, ...sizeTravels]), geometry, {
    labels, others: othersGeometry, collapse: dimensions, display: (value) => isHash(value) ? presenter.dimensions(value) : value
  })
  const otherExtras = othersGeometry.map((each) => each?.[extrasKey] ?? {})
  const extras = Object.entries(geometry[extrasKey] ?? {}).filter(([, value]) => present(value)).map(([key, value]) => {
    const [label, unit] = key.split(presenter.unitSuffix)
    return [presenter.humanize(label), value, unit || 'mm', otherExtras.some((each) => !equal(each[key], value)), key]
  })
  const { length, width, volume } = presenter.kit.schemas.vehicle.cargo.fields
  const cargoFields = { length, width, volume }
  // where its vehicle lists any, a row for each the compared ones do
  const cargoRows = Object.keys(cargoFields).some((key) => present(cargo?.[key]))
    ? presenter.rowsFor(cargoFields, cargo, { others: otherCargos }).map(([label, value, unit, differs, key, ...rest]) => [label, value, unit, differs, `cargo.${key}`, ...rest])
    : []
  const heading = (text) => html`<h4 class="tw:pt-2 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${text}</h4>`
  const group = (text, rows) => rows.length
    ? html`${heading(text)}${definitionListContainer({ term: 'right_align', content: presenter.measurementRows(lettered(rows)) })}`
    : nothing
  // a hash's row, as overall dimensions are, lettered with each of its fields drawn
  const lettersFor = (key) => [...letters].filter(([each]) => each === key || each.startsWith(`${key}.`))
  const lettered = (rows) => rows.map(([label, value, unit, differs, key, ...rest]) => [html`${lettersFor(key).map(([figure, letter]) =>
    figureLetter({ letter, listed: present(value), highlighted: figure === highlight, href: figurePath?.(figure), label }))}${label}`, value, unit, differs, key, ...rest])
  const unlisted = drawn && equal(drawn.name, size.name) ? drawn.figures : []
  const notes = unlisted.length
    ? html`<div data-controller="bikebook--figure-note" data-bikebook--figure-note-card-value=${`${drawn.id} ${size.name ?? ''}`}>${unlisted.map(({ key, letter, label, value, unit, calculated }) =>
      html`<div data-bikebook--figure-note-target="note" data-figure=${key} class=${key === highlight ? '' : 'tw:hidden'}><div
        class="tw:pb-2.5">${definitionListContainer({
        term: 'right_align',
        content: presenter.measurementRows([[html`${figureLetter({ letter, calculated, href: figurePath?.(key), label })}${label}`, value, unit === '°' ? 'degrees' : 'mm', false, key]])
      })}</div></div>`)}</div>`
    : nothing
  return html`<div aria-current=${selected ? 'true' : nothing} data-ui--tabs-target=${selected ? 'active' : nothing} class="tw:w-max tw:shrink-0 tw:space-y-3 tw:rounded-sm tw:border ${selected
    ? 'tw:border-purple-500 tw:ring-2 tw:ring-purple-500/40'
    : 'tw:border-gray-200 tw:dark:border-gray-700'} tw:bg-white tw:dark:bg-gray-800 tw:p-4"><h3
    class="tw:text-lg tw:font-bold">${href && present(size.name) && !selected
      ? html`<a class="twlink" href=${href} data-in-place="">${size.name}</a>`
      : presence(size.name) ?? 'Geometry'}</h3><div>${notes}${
    definitionListContainer({ term: 'right_align', content: presenter.measurementRows(lettered(rows)) })}</div>${
    group('Additional measurements', extras)}${group('Cargo', cargoRows)}${wheels.length
      ? html`${heading('Wheels')}${definitionListContainer({ term: 'right_align', content: wheels.map(([label, content]) => definitionListRow({ label, content })) })}`
      : nothing}</div>`
}
