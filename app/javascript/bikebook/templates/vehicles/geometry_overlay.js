import { html, nothing, svg } from 'lit-html'
import { builtWheel, outerRadius } from 'bikebook/frame_geometry'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { sectionHeading } from 'bikebook/templates/vehicles/section'
import { equal, isNumber, present } from 'bikebook/templates/values'

// UI::Chart::Component::COLORS, one per compared model; forced, or the table cells' dark border color wins
export const SERIES = [
  { color: '#3498db', border: 'tw:border-b-[#3498db]!' },
  { color: '#DC2626', border: 'tw:border-b-[#DC2626]!' },
  { color: '#7C3AED', border: 'tw:border-b-[#7C3AED]!' },
  { color: '#D97706', border: 'tw:border-b-[#D97706]!' },
  { color: '#059669', border: 'tw:border-b-[#059669]!' }
]
const PADDING = 30
const TIRE_GAP = 10
// mm around the bottom bracket and up from the ground that nearly every catalog frame fits, so a larger size draws
// larger rather than the drawing refitting
const BOUNDS = { left: -850, right: 1250, top: 1010 }
// a typical rear axle's mm behind the bottom bracket, for wheels with no frame to line up on
const REAR_AXLE = -430

const point = ([x, y]) => `${Math.round(x * 10) / 10},${Math.round(-y * 10) / 10}`
const path = (...lines) => lines.map(([start, ...rest]) => `M${point(start)}${rest.map((each) => `L${point(each)}`).join('')}`).join('')

const frame = ({ geometry: { rearAxle, frontAxle, rearRadius, frontRadius, headTop, headBottom, seatTop, bottomBracketHeight }, series, label }, index) => {
  const bottomBracket = [0, 0]
  return svg`<g id=${`geometry-frame-${index}`} data-bikebook--geometry-overlay-target="frame" transform=${`translate(0 ${-bottomBracketHeight})`} stroke=${series.color} fill="none" stroke-linecap="round" stroke-linejoin="round"><title>${label}</title><circle
    cx=${rearAxle[0]} cy=${-rearAxle[1]} r=${rearRadius} stroke-width="2" vector-effect="non-scaling-stroke"></circle><circle
    cx=${frontAxle[0]} cy=${-frontAxle[1]} r=${frontRadius} stroke-width="2" vector-effect="non-scaling-stroke"></circle>${headTop
    ? svg`<path d=${path([rearAxle, bottomBracket, seatTop, rearAxle], [bottomBracket, headBottom, headTop, seatTop], [headBottom, frontAxle])}
      stroke-width="4" vector-effect="non-scaling-stroke"></path>`
    : nothing}</g>`
}

// A [bsd, tire] wheel against the first's: the same size on a tire more than TIRE_GAP mm wider or narrower, or 700c
// against 650b
const sizedApart = ([bsd, tire], [baseBsd, baseTire]) => [bsd, tire, baseBsd, baseTire].every(isNumber) &&
  (bsd === baseBsd ? Math.abs(tire - baseTire) > TIRE_GAP : [bsd, baseBsd].every((each) => [584, 622].includes(each)))

// Once any model's built wheel is `sizedApart` from the first's, every model's, as diameters estimated with a tire as
// tall as it's wide. Front and rear as one where they match
const diameterNotes = (presenter, compared) => {
  const [first, ...others] = compared
  const wheel = ({ builtWheels }, position) => [builtWheels[position]?.bsd, builtWheels[position]?.tire_width]
  if (!others.some((vehicle) => ['front', 'rear'].some((position) => sizedApart(wheel(vehicle, position), wheel(first, position))))) return []
  const mm = (value) => presenter.measurement(presenter.rounded(value), 'mm')
  return compared.flatMap((vehicle) => {
    const positions = ['front', 'rear'].filter((position) => isNumber(outerRadius(vehicle.builtWheels[position])))
    const both = positions.length === 2 && equal(wheel(vehicle, 'front'), wheel(vehicle, 'rear'))
    return (both ? ['front'] : positions).map((position) => {
      const [bsd, tire] = wheel(vehicle, position)
      return html`<li>${vehicle.title}'s ${both ? '' : `${position} `}${presenter.vocabulary.wheel_sizes[bsd]?.name ?? `${bsd} mm BSD`} wheel with ${
        both ? html`${mm(tire)} tires` : html`a ${mm(tire)} tire`} is approximately ${mm(2 * outerRadius(vehicle.builtWheels[position]))} diameter</li>`
    })
  })
}

// The bottom border that keys a comparison table column to its frame, which the overlay draws in the same order
const drawable = (geometry) => geometry?.missing.length === 0 || geometry?.wheels

export const seriesBorder = (frame, index) => drawable(frame) ? `tw:border-b-4 ${SERIES[index].border}` : ''

// The compared models' frames in their `sizes`, standing on the same ground with their bottom brackets lined up,
// each over the ones the comparison table columns left of it. A frame it can't draw is its wheels alone where they're
// listed, the rear axle on the first drawn frame's
export const geometryOverlay = ({ presenter, vehicles, sizes, frames }) => {
  const named = vehicles.map(({ data }) => presenter.named(presenter.kit.schemas.vehicle, data))
  const labelled = named.map((vehicle, index) => {
    const title = [vehicle.manufacturer, vehicle.model].filter(present).join(' ')
    const size = sizes[index]?.name
    const builtWheels = Object.fromEntries(['front', 'rear'].map((position) => [position, builtWheel(vehicles[index].data, sizes[index], position)]))
    return { geometry: frames[index], series: SERIES[index], title, size, builtWheels, label: present(size) ? `${title}, ${size}` : title }
  })
  const aligned = labelled.find(({ geometry }) => geometry.missing.length === 0)
  const rearX = aligned?.geometry.rearAxle[0] ?? REAR_AXLE
  const drawn = labelled.filter(({ geometry }) => drawable(geometry)).map((each) => {
    if (each.geometry.missing.length === 0) return each
    const { rearRadius, frontRadius, wheelbase } = each.geometry.wheels
    return { ...each, geometry: { rearAxle: [rearX, rearRadius], frontAxle: [rearX + wheelbase, frontRadius], rearRadius, frontRadius, bottomBracketHeight: 0 } }
  })
  const undrawn = labelled.filter(({ geometry }) => geometry.missing.length)
  if (drawn.length === 0) return nothing

  const xs = drawn.flatMap(({ geometry: { rearAxle, frontAxle, rearRadius, frontRadius } }) => [rearAxle[0] - rearRadius, frontAxle[0] + frontRadius])
  // the wheels stand on the ground, so only the frame's top reaches past it
  const ys = drawn.filter(({ geometry }) => geometry.headTop).flatMap(({ geometry: { headTop, seatTop, bottomBracketHeight } }) => [headTop[1], seatTop[1]].map((y) => y + bottomBracketHeight))
  const [left, top] = [Math.min(BOUNDS.left, ...xs) - PADDING, -Math.max(BOUNDS.top, ...ys) - PADDING]
  const [width, height] = [Math.max(BOUNDS.right, ...xs) - left + PADDING, PADDING - top]
  const labels = presenter.kit.geometry.labels
  const notes = diameterNotes(presenter, labelled)

  // out to the screen's edges on a phone, as the cards below it are
  return html`<section aria-label="Geometry overlay" data-controller="bikebook--geometry-overlay" class="tw:mx-auto tw:mt-6 tw:max-w-4xl tw:space-y-3 tw:rounded-sm tw:border
    tw:border-gray-200 tw:bg-white tw:p-4 tw:dark:border-gray-700 tw:dark:bg-gray-800 tw:max-[500px]:mx-[calc(50%-50vw)] tw:max-[500px]:w-screen
    tw:max-[500px]:rounded-none tw:max-[500px]:border-x-0">${sectionHeading('Geometry overlay')}<svg
    role="img" aria-label=${`Frames on the same ground, their bottom brackets lined up: ${drawn.map(({ label }) => label).join('; ')}`}
    viewBox=${[left, top, width, height].map(Math.round).join(' ')} class="tw:h-auto tw:w-full">${drawn.map(frame)}<use
    data-bikebook--geometry-overlay-target="top"></use></svg><ul class="tw:flex tw:flex-wrap tw:gap-2">${drawn.map(({ series, title, size }) =>
      html`<li><button type="button" class=${buttonClasses({ size: 'sm' })} aria-pressed="false"
        data-bikebook--geometry-overlay-target="button" data-action="bikebook--geometry-overlay#toggle"><svg aria-hidden="true" class="tw:shrink-0" width="24" height="8"><line stroke=${series.color}
        x1="2" y1="4" x2="22" y2="4" stroke-width="4" stroke-linecap="round"></line></svg><span>${title}${
        present(size) ? html` <span class="tw:opacity-65">${size}</span>` : nothing}</span></button></li>`)}</ul>${notes.length
      ? html`<div class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400"><p>Note: you're comparing different diameter wheels and tires</p><ul
        class="tw:mt-1 tw:list-disc tw:space-y-1 tw:pl-5">${notes}</ul></div>`
      : nothing}${undrawn.length
      ? html`<p class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">${undrawn.map(({ title, geometry: { missing, wheels } }) => {
        const without = missing.map((key) => labels[key] ?? presenter.humanize(key)).join(', ')
        if (!wheels) return `${title} isn't drawn without its ${without}.`
        return `${title}'s frame isn't drawn without its ${without}, only its wheels${aligned ? `, the rear axle on ${aligned.title}'s` : ''}.`
      }).join(' ')}</p>`
      : nothing}${drawn.some(({ geometry }) => geometry.estimated)
      ? html`<p class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">Some tubes and wheels are estimated where a size doesn't list them.</p>`
      : nothing}</section>`
}
