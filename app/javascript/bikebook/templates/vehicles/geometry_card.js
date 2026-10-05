import { html, nothing } from 'lit-html'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { array, equal, except, isHash, presence, present } from 'bikebook/templates/values'

// A size's geometry, marked where the same-named size in `others` differs
export const geometryCard = ({ presenter, size, others }) => {
  const { labels, extras_key: extrasKey, dimensions } = presenter.kit.geometry
  const geometry = size.geometry ?? {}
  const othersGeometry = others.map((sizes) => array(sizes).find((other) => equal(other.name, size.name))?.geometry)
  const sizeTravels = Object.values(presenter.kit.viewer.suspensions).map(({ size_travel: sizeTravel }) => sizeTravel)
  const rows = presenter.rowsFor(except(presenter.kit.schemas.geometry, [extrasKey, ...sizeTravels]), geometry, { labels, others: othersGeometry, collapse: dimensions })
    .map(([label, value, ...rest]) => [label, isHash(value) ? presenter.dimensions(value) : value, ...rest])
  const otherExtras = othersGeometry.map((each) => each?.[extrasKey] ?? {})
  const extras = Object.entries(geometry[extrasKey] ?? {}).filter(([, value]) => present(value)).map(([key, value]) => {
    const [label, unit] = key.split(presenter.unitSuffix)
    return [presenter.humanize(label), value, unit || 'mm', otherExtras.some((each) => !equal(each[key], value)), key]
  })
  return html`<div class="tw:w-max tw:shrink-0 tw:space-y-3 tw:rounded-md tw:border tw:border-vellum tw:bg-paper tw:p-4"><h3
    class="tw:font-display tw:text-lg tw:font-semibold tw:text-ink">${presence(size.name) ?? 'Geometry'}</h3>${
    definitionListContainer({ term: 'right_align', content: presenter.measurementRows(rows) })}${extras.length
      ? html`<h4 class="tw:pt-2 tw:spec-eyebrow">Additional measurements</h4>${definitionListContainer({ term: 'right_align', content: presenter.measurementRows(extras) })}`
      : nothing}</div>`
}
