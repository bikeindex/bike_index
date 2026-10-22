import { html, nothing, svg } from 'lit-html'
import { builtWheel, frameGeometry, outerRadius } from 'bikebook/frame_geometry'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { extent, renderShape, sideView } from 'bikebook/templates/vehicles/cycle_drawing'
import { tireWidth, wheelSize } from 'bikebook/templates/vehicles/model_viewer'
import { sectionHeading } from 'bikebook/templates/vehicles/section'
import { andSentence, equal, isNumber, join, present } from 'bikebook/templates/values'

// UI::Chart::Component::COLORS, one per compared model; forced, or the table cells' dark border color wins
export const SERIES = [
  { color: '#3498db', bottom: 'tw:border-b-[#3498db]!', top: 'tw:border-t-[#3498db]!' },
  { color: '#DC2626', bottom: 'tw:border-b-[#DC2626]!', top: 'tw:border-t-[#DC2626]!' },
  { color: '#7C3AED', bottom: 'tw:border-b-[#7C3AED]!', top: 'tw:border-t-[#7C3AED]!' },
  { color: '#D97706', bottom: 'tw:border-b-[#D97706]!', top: 'tw:border-t-[#D97706]!' },
  { color: '#059669', bottom: 'tw:border-b-[#059669]!', top: 'tw:border-t-[#059669]!' }
]
const PADDING = 30
const TIRE_GAP = 10
// mm around the bottom bracket and up from the ground that nearly every catalog frame fits, so a larger size draws
// larger rather than the drawing refitting
const BOUNDS = { left: -890, right: 1255, top: 1140 }
// a typical rear axle's mm behind the bottom bracket, for wheels with no frame to line up on
const REAR_AXLE = -430

const figures = (presenter, keys) => andSentence(keys.map((key) => presenter.kit.geometry.labels[key] ?? presenter.humanize(key)))

// A frame drawn whole as its type's side view, its rims only while it's `chosen`, else its wheels alone, faded while
// another is chosen
const frame = ({ side, geometry: { rearAxle, frontAxle, rearRadius, frontRadius }, series, label, value }, index, chosen) =>
  svg`<g id=${`geometry-frame-${index}`} data-bikebook--geometry-overlay-target="frame" data-vehicle=${value} color=${series.color}
    opacity=${chosen >= 0 && chosen !== index ? 0.2 : nothing}><title>${label}</title>${side
    ? side.shapes(chosen === index)
    : [[rearAxle, rearRadius], [frontAxle, frontRadius]].map(([center, radius]) => renderShape({ kind: 'circle', center, radius, weight: 'part' }))}</g>`

// A [bsd, tire] wheel against the first's: the same size on a tire more than TIRE_GAP mm wider or narrower, or 700c
// against 650b
const sizedApart = ([bsd, tire], [baseBsd, baseTire]) => [bsd, tire, baseBsd, baseTire].every(isNumber) &&
  (bsd === baseBsd ? Math.abs(tire - baseTire) > TIRE_GAP : [bsd, baseBsd].every((each) => [584, 622].includes(each)))

// Once any model's built wheel is `sizedApart` from the first's, every model's, as diameters estimated with a tire as
// tall as it's wide, each model's in one sentence. Front and rear as one where they match
const diameterNotes = (presenter, compared) => {
  const [first, ...others] = compared
  const wheel = ({ builtWheels }, position) => [builtWheels[position]?.bsd, builtWheels[position]?.tire_width]
  if (!others.some((vehicle) => ['front', 'rear'].some((position) => sizedApart(wheel(vehicle, position), wheel(first, position))))) return []
  const mm = (value) => presenter.measurement(presenter.rounded(value), 'mm')
  return compared.flatMap((vehicle) => {
    const positions = ['front', 'rear'].filter((position) => isNumber(outerRadius(vehicle.builtWheels[position])))
    if (positions.length === 0) return []
    const title = html`<em>${vehicle.title}</em>'s`
    const described = (position) => {
      const [bsd, tire] = wheel(vehicle, position)
      return [presenter.vocabulary.wheel_sizes[bsd]?.name ?? `${bsd} mm BSD`, mm(tire), mm(2 * outerRadius(vehicle.builtWheels[position]))]
    }
    if (positions.length === 2 && equal(wheel(vehicle, 'front'), wheel(vehicle, 'rear'))) {
      const [size, tire, diameter] = described('front')
      return [html`<li>${title} ${size} wheels with ${tire} tires are approximately ${diameter} diameter</li>`]
    }
    return [html`<li>${join(positions.map((position, index) => {
      const [size, tire, diameter] = described(position)
      return html`${index ? 'its' : title} ${position} ${size} wheel with a ${tire} tire is approximately ${diameter} diameter`
    }), ', ')}</li>`]
  })
}

const noteList = (heading, items) => html`<div class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400"><p>Note: ${heading}:</p><ul
  class="tw:mt-1 tw:list-disc tw:space-y-1 tw:pl-5">${items}</ul></div>`

const drawable = (geometry) => geometry?.side || geometry?.wheels

// One frame has nothing to overlay
const overlaid = (frames) => frames.filter(drawable).length > 1

// Each vehicle's frame in its `sizes` as frameGeometry works it out, with its type's `side` view where that's drawn
// whole, and the figures it's `unlisted` without: frameGeometry's for a view on its frame, else those the view takes at
// their typical
export const overlayFrames = (vehicles, sizes) => vehicles.map(({ data }, index) => {
  const frame = frameGeometry(data, sizes[index])
  const side = sideView({ type: data.type, data, size: sizes[index] })
  const unlisted = side.framed ? frame.missing : side.typical
  return { ...frame, side: unlisted.length === 0 ? side : null, unlisted }
})

// The top and bottom borders that key a comparison table column to its frame, which the overlay draws in the same order
export const seriesBorders = (frames, index) => overlaid(frames) && drawable(frames[index])
  ? { top: `tw:border-t-4 ${SERIES[index].top}`, bottom: `tw:border-b-4 ${SERIES[index].bottom}` }
  : { top: '', bottom: '' }

// The compared models' frames in their `sizes`, standing on the same ground with their bottom brackets lined up,
// each over the ones the comparison table columns left of it. A frame it can't draw is its wheels alone where they're
// listed, the rear axle on the first drawn frame's. Lone wheels aren't drawn, only said what they're missing. The
// `selected` vehicle's over the rest, the others faded, the first drawn's unless it's another or 'none'
export const geometryOverlay = ({ presenter, vehicles, sizes, frames, selected, beside = false }) => {
  const named = vehicles.map(({ data }) => presenter.named(presenter.kit.schemas.vehicle, data))
  const labelled = named.map((vehicle, index) => {
    const title = [vehicle.manufacturer, vehicle.model].filter(present).join(' ')
    const size = sizes[index]?.name
    const builtWheels = Object.fromEntries(['front', 'rear'].map((position) => [position, builtWheel(vehicles[index].data, sizes[index], position)]))
    return { geometry: frames[index], side: frames[index].side, series: SERIES[index], title, size, builtWheels, label: present(size) ? `${title}, ${size}` : title, value: vehicles[index].value }
  })
  const aligned = labelled.find(({ geometry }) => geometry.missing.length === 0)
  const rearX = aligned?.geometry.rearAxle[0] ?? REAR_AXLE
  const drawn = labelled.filter(({ geometry }) => drawable(geometry)).map((each) => {
    if (each.side) return each
    const { rearRadius, frontRadius, wheelbase } = each.geometry.wheels
    return { ...each, geometry: { rearAxle: [rearX, rearRadius], frontAxle: [rearX + wheelbase, frontRadius], rearRadius, frontRadius, bottomBracketHeight: 0 } }
  })
  const undrawn = labelled.filter(({ side }) => !side)
  if (drawn.length === 0) return nothing

  const overlay = drawn.length > 1 || drawn.some(({ side }) => side)
  const missingNote = undrawn.length
    ? noteList('missing geometry information', undrawn.map(({ title, geometry: { unlisted, wheels } }) => {
      const none = `${figures(presenter, unlisted)} or the measures to calculate them`
      return html`<li><em>${title}</em> doesn't list its ${none}, so ${!wheels || !overlay
        ? "it can't be drawn"
        : `only its wheels are drawn${aligned ? `, the rear axle on ${aligned.title}'s` : ''}`}.</li>`
    }))
    : nothing

  // out to the screen's edges on a phone, as the cards below it are
  return html`<section aria-label="Geometry overlay" data-controller=${overlay ? 'bikebook--geometry-overlay' : nothing} class="tw:mx-auto tw:mt-6
    tw:w-full tw:max-w-4xl tw:space-y-3 tw:rounded-sm tw:border tw:border-gray-200 tw:bg-white tw:p-4 tw:dark:border-gray-700 tw:dark:bg-gray-800
    tw:max-[500px]:twpagebleed tw:max-[500px]:rounded-none tw:max-[500px]:border-x-0 ${beside
      ? 'tw:min-[1500px]:mx-0 tw:min-[1500px]:basis-2/5 tw:min-[1500px]:shrink-0'
      : ''}">${sectionHeading('Geometry overlay')}${
    overlay ? drawing(presenter, drawn, labelled, selected) : nothing}${missingNote}</section>`
}

// The points a frame reaches, its wheels' standing on the ground
const reach = ({ side, geometry: { rearAxle, frontAxle, rearRadius, frontRadius } }) => side
  ? side.points
  : [[rearAxle[0] - rearRadius, 0], [frontAxle[0] + frontRadius, 2 * Math.max(rearRadius, frontRadius)]]

const drawing = (presenter, drawn, labelled, selected) => {
  const chosen = selected === 'none' ? -1 : Math.max(drawn.findIndex(({ value }) => value === selected), 0)
  const bounds = extent([...drawn.flatMap(reach), [BOUNDS.left, 0], [BOUNDS.right, BOUNDS.top]])
  const [left, right, top] = [bounds.left - PADDING, bounds.right + PADDING, bounds.top + PADDING]
  const notes = diameterNotes(presenter, labelled)
  const noted = drawn.filter(({ geometry }) => geometry.calculated?.length || geometry.assumed?.length || geometry.typicalWheel)
  const clause = (keys, how) => keys?.length ? `${figures(presenter, keys)} ${keys.length > 1 ? 'are' : 'is'} ${how}` : null
  const tires = ({ bsd, tire, rimListed }) => rimListed
    ? html`tires aren't listed, so it's drawn with ${tireWidth(presenter, tire)} tires`
    : html`wheels aren't listed, so it's drawn with ${wheelSize(presenter, bsd)} wheels and ${tireWidth(presenter, tire)} tires`

  return html`<svg
    role="img" aria-label=${`Frames on the same ground, their bottom brackets lined up: ${drawn.map(({ label }) => label).join('; ')}`}
    viewBox=${[left, -top, right - left, top + PADDING].map(Math.round).join(' ')} class="tw:h-auto tw:w-full">${drawn.map((each, index) =>
    frame(each, index, chosen))}<use data-bikebook--geometry-overlay-target="top" href=${chosen < 0 ? nothing : `#geometry-frame-${chosen}`}></use></svg><ul
    class="tw:flex tw:flex-wrap tw:gap-2">${drawn.map(({ series, title, size, value }, index) =>
      html`<li><button type="button" class=${buttonClasses({ size: 'sm' })} aria-pressed=${String(index === chosen)} data-vehicle=${value}
        data-bikebook--geometry-overlay-target="button" data-action="bikebook--geometry-overlay#toggle"><svg aria-hidden="true" class="tw:shrink-0" width="24" height="8"><line stroke=${series.color}
        x1="2" y1="4" x2="22" y2="4" stroke-width="4" stroke-linecap="round"></line></svg><span>${title}${
        present(size) ? html` <span class="tw:opacity-65">${size}</span>` : nothing}</span></button></li>`)}</ul>${notes.length
      ? noteList("you're comparing different diameter wheels and tires", notes)
      : nothing}${noted.length
      ? html`<ul class="tw:list-disc tw:space-y-1 tw:pl-5 tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">${noted.map(({ title, geometry }) =>
        html`<li><em>${title}</em>'s ${join([clause(geometry.calculated, 'calculated from its other measures'),
          clause(geometry.assumed, `estimated based on a typical ${geometry.typicalKind}`),
          geometry.typicalWheel && tires(geometry.typicalWheel)].filter(Boolean), '. Its ')}.</li>`)}</ul>`
      : nothing}`
}
