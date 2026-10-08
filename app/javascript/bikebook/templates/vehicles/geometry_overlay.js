import { html, nothing, svg } from 'lit-html'
import { frameGeometry } from 'bikebook/frame_geometry'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { sectionHeading } from 'bikebook/templates/vehicles/section'
import { present } from 'bikebook/templates/values'

// UI::Chart::Component::COLORS, one per compared model
export const SERIES = [
  { color: '#3498db', border: 'tw:border-b-[#3498db]' },
  { color: '#DC2626', border: 'tw:border-b-[#DC2626]' },
  { color: '#7C3AED', border: 'tw:border-b-[#7C3AED]' },
  { color: '#D97706', border: 'tw:border-b-[#D97706]' },
  { color: '#059669', border: 'tw:border-b-[#059669]' }
]
const PADDING = 30
// mm from the bottom bracket and up from the ground that nearly every catalog frame fits inside, so the drawing keeps its scale as sizes
// change, and widens only for a frame that doesn't fit
const BOUNDS = { left: -850, right: 1250, bottom: 0, top: 1010 }

const point = ([x, y]) => `${Math.round(x * 10) / 10},${Math.round(-y * 10) / 10}`
const path = (...lines) => lines.map(([start, ...rest]) => `M${point(start)}${rest.map((each) => `L${point(each)}`).join('')}`).join('')

const frame = ({ geometry: { rearAxle, frontAxle, rearRadius, frontRadius, headTop, headBottom, seatTop, bottomBracketHeight }, series, label }, index) => {
  const bottomBracket = [0, 0]
  return svg`<g id=${`geometry-frame-${index}`} data-bikebook--geometry-overlay-target="frame" transform=${`translate(0 ${-bottomBracketHeight})`} stroke=${series.color} fill="none" stroke-linecap="round" stroke-linejoin="round"><title>${label}</title><circle
    cx=${rearAxle[0]} cy=${-rearAxle[1]} r=${rearRadius} stroke-width="2" vector-effect="non-scaling-stroke"></circle><circle
    cx=${frontAxle[0]} cy=${-frontAxle[1]} r=${frontRadius} stroke-width="2" vector-effect="non-scaling-stroke"></circle><path
    d=${path([rearAxle, bottomBracket, seatTop, rearAxle], [bottomBracket, headBottom, headTop, seatTop], [headBottom, frontAxle])}
    stroke-width="4" vector-effect="non-scaling-stroke"></path></g>`
}

// The bottom border that keys a comparison table column to its frame, which the overlay draws in the same order
export const seriesBorder = (data, size, index) => frameGeometry(data, size).missing.length ? null : `tw:border-b-4 ${SERIES[index].border}`

// The compared models' frames in their `sizes`, standing on the same ground with their bottom brackets lined up,
// each over the ones the comparison table columns left of it
export const geometryOverlay = ({ presenter, vehicles, sizes }) => {
  const named = vehicles.map(({ data }) => presenter.named(presenter.kit.schemas.vehicle, data))
  const frames = vehicles.map(({ data }, index) => {
    const title = [named[index].manufacturer, named[index].model].filter(present).join(' ')
    const size = sizes[index]?.name
    return { geometry: frameGeometry(data, sizes[index]), series: SERIES[index], title, size, label: present(size) ? `${title}, ${size}` : title }
  })
  const drawn = frames.filter(({ geometry }) => geometry.missing.length === 0)
  const undrawn = frames.filter(({ geometry }) => geometry.missing.length)
  if (drawn.length === 0) return nothing

  const xs = drawn.flatMap(({ geometry: { rearAxle, frontAxle, rearRadius, frontRadius } }) => [rearAxle[0] - rearRadius, frontAxle[0] + frontRadius])
  const ys = drawn.flatMap(({ geometry: { rearAxle, frontAxle, rearRadius, frontRadius, headTop, seatTop, bottomBracketHeight } }) =>
    [rearAxle[1] - rearRadius, frontAxle[1] - frontRadius, headTop[1], seatTop[1]].map((y) => y + bottomBracketHeight))
  const [left, top] = [Math.min(BOUNDS.left, ...xs) - PADDING, -Math.max(BOUNDS.top, ...ys) - PADDING]
  const [width, height] = [Math.max(BOUNDS.right, ...xs) - left + PADDING, -Math.min(BOUNDS.bottom, ...ys) - top + PADDING]
  const labels = presenter.kit.geometry.labels

  return html`<section aria-label="Geometry overlay" data-controller="bikebook--geometry-overlay" class="tw:mx-auto tw:mt-6 tw:max-w-4xl tw:space-y-3 tw:rounded-sm tw:border
    tw:border-gray-200 tw:bg-white tw:p-4 tw:dark:border-gray-700 tw:dark:bg-gray-800">${sectionHeading('Geometry overlay')}<svg
    role="img" aria-label=${`Frames on the same ground, their bottom brackets lined up: ${drawn.map(({ label }) => label).join('; ')}`}
    viewBox=${[left, top, width, height].map(Math.round).join(' ')} class="tw:h-auto tw:w-full">${drawn.map(frame)}<use
    data-bikebook--geometry-overlay-target="top"></use></svg><ul class="tw:flex tw:flex-wrap tw:gap-2">${drawn.map(({ series, title, size }) =>
      html`<li><button type="button" class=${buttonClasses({ size: 'sm' })} aria-pressed="false"
        data-bikebook--geometry-overlay-target="button" data-action="bikebook--geometry-overlay#toggle"><svg aria-hidden="true" class="tw:shrink-0" width="24" height="8"><line stroke=${series.color}
        x1="2" y1="4" x2="22" y2="4" stroke-width="4" stroke-linecap="round"></line></svg><span>${title}${
        present(size) ? html` <span class="tw:opacity-65">${size}</span>` : nothing}</span></button></li>`)}</ul>${undrawn.length
      ? html`<p class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">${undrawn.map(({ title, geometry: { missing } }) =>
        `${title} isn't drawn without its ${missing.map((key) => labels[key] ?? presenter.humanize(key)).join(', ')}.`).join(' ')}</p>`
      : nothing}${drawn.some(({ geometry }) => geometry.estimated)
      ? html`<p class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">Some tubes and wheels are estimated where a size doesn't list them.</p>`
      : nothing}</section>`
}
