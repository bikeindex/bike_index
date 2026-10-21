import { html, nothing, svg } from 'lit-html'
import { arc, drawingViews, listedFigure, minus, plus, polar, scale } from 'bikebook/cycle_drawings'

const LISTED = '#715eb2'
const TYPICAL = '#9ca3af'
// the OG Bike Index blue, the theme's blue-500
const HIGHLIGHT = '#3397dc'
const WEIGHTS = { frame: 3.5, part: 2.5, thin: 1.25, ghost: 1.25 }
// lettering heights between a dimension's lanes
const LANE = 2.6

// labels for the figures the kit's geometry labels don't name
const LABELS = {
  rear_rack_length: 'Rear rack length',
  captain_top_tube: 'Captain top tube',
  captain_seat_tube: 'Captain seat tube',
  stoker_top_tube_effective: 'Stoker top tube',
  stoker_seat_tube: 'Stoker seat tube',
  boom_tube: 'Boom tube',
  seat_height: 'Seat height',
  seat_height_min: 'Seat height, lowest',
  seat_height_max: 'Seat height, highest',
  handlebar_height: 'Handlebar height',
  handlebar_height_min: 'Handlebar height, lowest',
  handlebar_height_max: 'Handlebar height, highest',
  frame_offset: 'Upper frame offset',
  wheel_size: 'Wheel diameter',
  wheel_front: 'Front wheel diameter',
  wheel_rear: 'Rear wheel diameter',
  box_length: 'Cargo box length',
  track_width: 'Track width',
  hitch_height: 'Hitch height',
  tow_arm_length: 'Tow arm length',
  bench_height: 'Bench height',
  platform_height: 'Platform height',
  operating_height: 'Operating height',
  stride_length: 'Stride length',
  stride_height: 'Stride height',
  deck_height: 'Deck height',
  deck_length: 'Deck length',
  deck_width: 'Deck width',
  ground_clearance: 'Ground clearance',
  pedal_height: 'Pedal height',
  seat_length: 'Seat length',
  seat_depth: 'Seat depth',
  seat_width: 'Seat width',
  backrest_height: 'Backrest height',
  'dimensions.length': 'Overall length',
  'dimensions.width': 'Overall width',
  'dimensions.height': 'Overall height',
  'dimensions_folded.length': 'Folded length',
  'dimensions_folded.height': 'Folded height'
}

const point = ([x, y]) => `${Math.round(x * 10) / 10},${Math.round(-y * 10) / 10}`
const pathData = (points, closed) => `M${points.map(point).join('L')}${closed ? 'Z' : ''}`

const extent = (points) => {
  const [xs, ys] = [points.map(([x]) => x), points.map(([, y]) => y)]
  return { left: Math.min(...xs), right: Math.max(...xs), bottom: Math.min(...ys), top: Math.max(...ys) }
}
const shapePoints = (shape) => shape.kind === 'circle'
  ? [plus(shape.center, [-shape.radius, -shape.radius]), plus(shape.center, [shape.radius, shape.radius])]
  : shape.points

// The dimension line's ends, out its lane from what it measures
const dimensionLine = ({ kind, a, b, lane, base }, laneWidth) => {
  if (kind === 'h') {
    const y = (base ?? (lane < 0 ? Math.min(a[1], b[1]) : Math.max(a[1], b[1]))) + lane * laneWidth
    return [[a[0], y], [b[0], y]]
  }
  if (kind === 'v') {
    const x = (base ?? (lane < 0 ? Math.min(a[0], b[0]) : Math.max(a[0], b[0]))) + lane * laneWidth
    return [[x, a[1]], [x, b[1]]]
  }
  const [dx, dy] = minus(b, a)
  const offset = scale([-dy, dx], lane * laneWidth / Math.hypot(dx, dy))
  return [plus(a, offset), plus(b, offset)]
}

const measured = (dim) => {
  if (dim.kind === 'angle') return Math.abs(dim.to - dim.from)
  const [dx, dy] = minus(dim.b, dim.a)
  return dim.kind === 'h' ? Math.abs(dx) : dim.kind === 'v' ? Math.abs(dy) : Math.hypot(dx, dy)
}

// Where a dimension's line, extension lines and letter go
const placed = (dim, font) => {
  if (dim.kind === 'angle') {
    const radius = dim.radius * font
    const middle = (dim.from + dim.to) / 2
    return { line: arc(dim.center, radius, dim.from, dim.to, 12), extensions: [], badge: plus(dim.center, polar(radius + font, middle)), arrowSize: 0 }
  }
  const [start, end] = dimensionLine(dim, LANE * font)
  const span = minus(end, start)
  const length = Math.hypot(...span)
  // a span too short to read under its letter has it beside instead, out the side its lane goes
  const side = dim.side ?? (dim.lane < 0 ? -1 : 1)
  const away = dim.kind === 'h' ? [0, side] : dim.kind === 'v' ? [side, 0] : scale([-span[1], span[0]], side / (length || 1))
  const gap = font * 0.2
  const extension = (from, to) => {
    const length = Math.hypot(...minus(to, from))
    return length > gap * 2 ? [plus(from, scale(minus(to, from), gap / length)), plus(to, scale(minus(to, from), gap / length))] : null
  }
  return {
    line: [start, end],
    extensions: [extension(dim.a, start), extension(dim.b, end), ...(dim.guides ?? [])].filter(Boolean),
    badge: length < font * 4 ? plus(plus(start, scale(span, 0.5)), scale(away, font * 1.05)) : plus(start, scale(span, dim.t ?? 0.5)),
    // shrunk to fit a span too short for both at full size
    arrowSize: Math.min(font * 0.5, length * 0.45)
  }
}

const arrowhead = (tip, from, size) => {
  const [dx, dy] = minus(from, tip)
  const length = Math.hypot(dx, dy)
  const along = scale([dx, dy], size / length)
  const across = scale([-dy, dx], size * 0.35 / length)
  return [tip, plus(plus(tip, along), across), minus(plus(tip, along), across)]
}

const renderShape = (shape) => {
  const dashed = shape.weight === 'ghost'
  const common = { width: WEIGHTS[shape.weight], dash: dashed ? '6 5' : nothing, opacity: dashed ? 0.55 : nothing }
  return shape.kind === 'circle'
    ? svg`<circle cx=${shape.center[0]} cy=${-shape.center[1]} r=${shape.radius} fill=${shape.fill ? 'currentColor' : 'none'} stroke="currentColor"
      stroke-width=${common.width} stroke-dasharray=${common.dash} opacity=${common.opacity} vector-effect="non-scaling-stroke"></circle>`
    : svg`<path d=${pathData(shape.points, shape.closed)} fill=${shape.fill ? 'currentColor' : 'none'} fill-opacity="0.07" stroke="currentColor"
      stroke-width=${common.width} stroke-dasharray=${common.dash} opacity=${common.opacity} stroke-linecap="round" stroke-linejoin="round"
      vector-effect="non-scaling-stroke"></path>`
}

// Solid where it measures, dashed out to what it measures from. `highlight` the key of the one dimension to draw over the rest,
// which fade
const renderDimension = ({ placement, letter, listed, key }, font, highlight) => {
  const highlighted = key === highlight
  const color = highlighted ? HIGHLIGHT : listed ? LISTED : TYPICAL
  const { line, extensions, badge, arrowSize } = placement
  const heads = arrowSize ? [arrowhead(line[0], line[1], arrowSize), arrowhead(line.at(-1), line.at(-2), arrowSize)] : []
  return svg`<g data-figure=${key} cursor="pointer" stroke=${color} fill="none" stroke-width=${highlighted ? 2.5 : 1.25}
    opacity=${highlight && !highlighted ? 0.25 : nothing}>${extensions.map((each) =>
    svg`<path d=${pathData(each)} stroke-width="0.75" stroke-dasharray="4 3" vector-effect="non-scaling-stroke"></path>`)}<path
    d=${pathData(line)} vector-effect="non-scaling-stroke"></path>${heads.map((each) =>
    svg`<path d=${pathData(each, true)} fill=${color} stroke="none"></path>`)}<circle cx=${badge[0]} cy=${-badge[1]} r=${font * 0.8} fill=${color} stroke="none"></circle><text x=${badge[0]} y=${-badge[1]}
    fill="white" stroke="none" font-size=${font} font-weight="700" text-anchor="middle" dominant-baseline="central">${letter}</text></g>`
}

// `type`'s drawing, or its `typeDetail`'s, of `data` in `size`, and the legend of its lettered figures: `listed` where the size
// lists one rather than taking its type's typical, `derived` where the wheels give it, and `extra`, lettered last, where the
// `kit`'s geometry schema doesn't have it. Each figure's marks carry data-figure, and the `highlight` one's are drawn on top
export const cycleDrawing = ({ type, data = {}, typeDetail = data.type_detail, size, kit, highlight }) => {
  const { views, listed } = drawingViews({ type, typeDetail, data, size })
  const flattened = views.map((view) => ({ ...view, shapes: [view.shapes].flat(Infinity).filter(Boolean) }))
  // lettering sized to the views side by side
  const extents = flattened.map(({ shapes }) => extent(shapes.flatMap(shapePoints)))
  const span = Math.max(extents.reduce((width, { left, right }) => width + right - left, 0) * 1.15, ...extents.map(({ top, bottom }) => top - bottom))
  const font = span / 36

  const dims = flattened.flatMap((view) => view.dims)
  const dimFor = (key) => dims.find((each) => each.key === key)
  const extra = (key) => Boolean(kit) && !dimFor(key).derived && !(key.split('.')[0] in kit.schemas.geometry)
  const drawn = [...new Set(dims.map(({ key }) => key))]
  const keys = [...drawn.filter((key) => !extra(key)), ...drawn.filter(extra)]
  const letter = (key) => String.fromCharCode(65 + keys.indexOf(key))
  const legend = keys.map((key) => {
    const dim = dimFor(key)
    const isListed = dim.listed ?? listed(key)
    const value = dim.value ?? (isListed ? listedFigure(size, key) : null) ?? measured(dim)
    const angular = dim.kind === 'angle'
    return {
      letter: letter(key),
      key,
      label: kit?.geometry.labels[key] ?? LABELS[key] ?? key,
      value: angular ? Math.round(value * 10) / 10 : Math.round(value),
      unit: angular ? '°' : 'mm',
      listed: isListed,
      derived: Boolean(dim.derived),
      extra: extra(key)
    }
  })
  const laidOut = flattened.map((view) => {
    const placedDims = view.dims.map((dim) => ({ ...legend[keys.indexOf(dim.key)], placement: placed(dim, font) }))
    const points = [...view.shapes.flatMap(shapePoints), ...placedDims.flatMap(({ placement }) =>
      [...placement.line, ...[[-1, -1], [1, 1]].map((corner) => plus(placement.badge, scale(corner, font)))])]
    return { ...view, dims: placedDims, bounds: extent(points) }
  })

  // side by side on the same ground, a view from above centred on the first's height
  const [first] = laidOut
  const middle = (first.bounds.top + first.bounds.bottom) / 2
  const positioned = laidOut.reduce((done, view) => {
    const previous = done.at(-1)
    const dx = previous ? previous.bounds.right + previous.dx + font * 4 - view.bounds.left : 0
    return [...done, { ...view, dx, dy: view.plan ? middle - (view.bounds.top + view.bounds.bottom) / 2 : 0 }]
  }, [])
  const last = positioned.at(-1)
  const [left, right] = [first.bounds.left - font, last.bounds.right + last.dx + font]
  const top = Math.max(...positioned.map(({ bounds, dy }) => bounds.top + dy)) + font
  const bottom = Math.min(...positioned.map(({ bounds, dy }) => bounds.bottom + dy)) - (positioned.length > 1 ? font * 2.5 : font)

  const figure = svg`<svg role="img" aria-label=${`${[type, typeDetail].filter(Boolean).join(' ')} drawing, ${legend.map(({ letter, label }) => `${letter}: ${label}`).join(', ')}`}
    viewBox=${[left, -top, right - left, top - bottom].map(Math.round).join(' ')} class="tw:h-auto tw:max-h-96 tw:w-full"
    font-family="ui-sans-serif, system-ui, sans-serif">${positioned.map((view) => svg`<g transform=${`translate(${view.dx} ${-view.dy})`}>${view.plan
      ? nothing
      : svg`<path d=${pathData([[view.bounds.left, 0], [view.bounds.right, 0]])} stroke="currentColor" opacity="0.25" stroke-width="1"
        vector-effect="non-scaling-stroke"></path>`}${view.shapes.map(renderShape)}${[...view.dims.filter(({ key }) => key !== highlight), ...view.dims.filter(({ key }) => key === highlight)]
        .map((dim) => renderDimension(dim, font, highlight))}${positioned.length > 1
      ? svg`<text x=${(view.bounds.left + view.bounds.right) / 2} y=${-(bottom - view.dy + font)} fill="currentColor" opacity="0.6" font-size=${font}
        text-anchor="middle">${view.name}</text>`
      : nothing}</g>`)}</svg>`
  return { figure, legend }
}

// A figure's letter, to set beside its label as the drawing has it
export const figureLetter = ({ letter, listed }) => html`<span aria-hidden="true" class="tw:mr-1.5 tw:inline-flex tw:size-4 tw:items-center
  tw:justify-center tw:rounded-full tw:align-text-bottom tw:text-[10px] tw:leading-none tw:font-bold tw:text-white ${listed
    ? 'tw:bg-[#715eb2]'
    : 'tw:bg-gray-400'}">${letter}</span>`
