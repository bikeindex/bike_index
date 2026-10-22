import { builtWheel, frameGeometry, leg, radians, STANDOVER_X } from 'bikebook/frame_geometry'
import { array, isNumber } from 'bikebook/templates/values'

// Each vehicle type's drawing, in mm with y up from the ground and the rider facing +x, as views of shapes and the
// dimensions lettered on them, keyed type/type_detail for a detail drawn its own way. A figure the size doesn't list is
// drawn at its type's typical one, in `defaults`

export const polar = (length, degrees) => [length * Math.cos(radians(degrees)), length * Math.sin(radians(degrees))]
export const plus = (point, ...vectors) => vectors.reduce(([x, y], [dx, dy]) => [x + dx, y + dy], point)
export const minus = ([x1, y1], [x2, y2]) => [x1 - x2, y1 - y2]
export const scale = ([x, y], factor) => [x * factor, y * factor]
const unit = (vector) => scale(vector, 1 / Math.hypot(...vector))
const lerp = (a, b, t) => plus(a, scale(minus(b, a), t))
const dot = ([x1, y1], [x2, y2]) => x1 * x2 + y1 * y2
export const arc = (center, radius, from, to, steps = 24) => Array.from({ length: steps + 1 }, (_, index) => plus(center, polar(radius, from + (to - from) * index / steps)))
// where a line from `point` along `direction` reaches height `y`
const atHeight = (point, direction, y) => plus(point, scale(direction, (y - point[1]) / direction[1]))
// up and back at `degrees` from the ground, as a head tube or seat tube rises
const rising = (degrees) => polar(1, 180 - degrees)

const path = (weight) => (...points) => ({ kind: 'path', points, weight })
const tube = path('frame')
const part = path('part')
const thin = path('thin')
const ghost = path('ghost')
const panel = (...points) => ({ kind: 'path', points, weight: 'part', closed: true, fill: true })
const box = ([x0, y0], [x1, y1], make = panel) => ({ ...make([x0, y0], [x1, y0], [x1, y1], [x0, y1]), closed: true })
const ring = (center, radius, weight = 'thin', fill = false) => ({ kind: 'circle', center, radius, weight, fill })
// its tire's outside, and its rim's bead seat inside the tire
const wheel = (center, { r, tire }) => [ring(center, r, 'part'), tire ? { ...ring(center, r - tire), rim: true } : []]
// a wheel seen end on, across `lateral`
const tread = (lateral, { r, tire }) => box([lateral - (tire || 30) / 2, 0], [lateral + (tire || 30) / 2, 2 * r])
// seen from above, at `x` forward and `lateral`
const footprint = (x, lateral, { r, tire }) => box([x - r, lateral - (tire || 30) / 2], [x + r, lateral + (tire || 30) / 2])
// its nose forward `along`, its back raised square to it
const saddle = (top, length = 150, along = [1, 0]) =>
  part(plus(top, scale(along, -length * 0.37), scale([-along[1], along[0]], 10)), plus(top, scale(along, length * 0.63)))
const handlebar = (center) => ring(center, 14, 'part', true)
const dropBar = (clamp) => part(clamp, plus(clamp, [70, -10]), plus(clamp, [100, -45]), plus(clamp, [80, -115]), plus(clamp, [30, -125]))
// a BMX riser bar, 9" up to its grips along the `steering` axis, as its fork is
const bmxBar = (clamp, steering) => [part(clamp, plus(clamp, scale(steering, 229))), handlebar(plus(clamp, scale(steering, 229)))]

// A lettered dimension. h and v measure across x and y, a `lane` of lettering out from the furthest of `a` and `b`, else
// from `base`; d along a to b, a lane to its left. `value` where it isn't what's drawn, `listed` where it isn't its key's,
// `calculated` where the size doesn't list it but it's worked out from figures the size does, `fixed` where it can't
// be set as a figure can, `unlettered` where it's plain without a letter, and `side`, 1 or -1, where a span too short to
// letter over isn't lettered out the side its lane goes. `guides`, more dashed connectors, to show what it measures from where nothing drawn does
const [h, v, d] = ['h', 'v', 'd'].map((kind) => (key, a, b, lane = 0, options = {}) => ({ kind, key, a, b, lane, ...options }))
// `degrees` up from the ground behind `center`, `radius` in lettering heights
const angle = (key, center, degrees, radius = 2.6) => ({ kind: 'angle', key, center, from: 180 - degrees, to: 180, radius })
const across = (key, center, { r, listed }) => h(key, plus(center, [-r, 0]), plus(center, [r, 0]), 0, { base: center[1], value: 2 * r, listed, derived: true, fixed: true })
const fromGround = (key, point, lane = 0, options = {}) => v(key, [point[0], 0], point, lane, { base: point[0], ...options })
const overall = (key, from, to, lane = -2.6, options = {}) => h(key, [from, 0], [to, 0], lane, { base: 0, ...options })
// where it lists its overall length but no wheelbase, its wheelbase worked out from the length, less its wheels' radii
const lengthwise = ({ listed }) => !listed('wheelbase') && listed('dimensions.length')
const wheelbaseOf = (context, rearWheel, frontWheel) => lengthwise(context)
  ? context.fig('dimensions.length') - rearWheel.r - frontWheel.r
  : context.fig('wheelbase')
// each tire's width, from the ground up to its rim, lettered after its drawing's other figures on the side away from the
// other wheel
const tires = (rearAxle, rearWheel, frontAxle, frontWheel) => [['tire_width_rear', rearAxle, rearWheel, -1], ['tire_width_front', frontAxle, frontWheel, 1]]
  .filter(([, , { tire }]) => tire)
  .map(([key, [x, y], { r, tire, tireListed }, side]) => v(key, [x, y - r], [x, y - r + tire], 0, { base: x, side, value: tire, listed: tireListed, derived: true, unlettered: true }))

const ROAD = /^(road|track|atb_)/
const BMX = /^bmx/

// the figure a tire at `position` takes its width from
const tireKey = (position) => position.startsWith('rear') ? 'tire_width_rear' : position.startsWith('front') ? 'tire_width_front' : null
const tireFigure = (size, position) => tireKey(position) && listedFigure(size, tireKey(position))

// a BMX's typical fork and head tube, which its front triangle stands on where it lists none of it, and the figures
// frameGeometry works out from the rear triangle and wheels alone, which they can't feed
const TYPICAL_FORK = ['fork_length_a2c', 'head_tube']
const UNFORKED = ['bb_drop', 'chainstay', 'wheel_size']

// frameGeometry's frame standing on the ground, assuming `defaults` for whatever it can't draw without, and `fallback`'s
// wheels where it lists none
const bikeFrame = ({ data, size, defaults, assume }, fallback) => {
  const fallbackWheels = [{ bsd: fallback.bsd, tire_width: fallback.tire, position: ['front', 'rear'] }]
  // each wheel at each of its positions, a tire width figure in place of its own
  const tired = (wheels) => wheels.flatMap((wheel) => array(wheel.position).map((position) => ({ ...wheel, position: [position], tire_width: tireFigure(size, position) ?? wheel.tire_width })))
  const settle = (fellBack, geometry, attempts) => {
    const built = { ...data, wheels: tired(fellBack ? assume('wheels', fallbackWheels) : data.wheels) }
    const frame = frameGeometry(built, { ...size, geometry })
    if (frame.missing.length === 0 || attempts === 0) return { frame, built, geometry, fellBack }
    return settle(fellBack || frame.missing.includes('wheel_size'),
      { ...geometry, ...Object.fromEntries(frame.missing.filter((key) => key in defaults).map((key) => [key, assume(key, defaults[key])])) }, attempts - 1)
  }
  const { frame, built, geometry, fellBack } = settle(array(data.wheels).length === 0, size?.geometry ?? {}, 4)
  const defaulted = fellBack || Object.keys(geometry).some((key) => !(key in (size?.geometry ?? {})))
  const lift = ([x, y]) => [x, y + frame.bottomBracketHeight]
  const tireOf = (position, r) => {
    const { bsd, tire_width: tireWidth } = builtWheel(built, size, position) ?? {}
    return { r, tire: isNumber(bsd) ? r - bsd / 2 : tireWidth ?? fallback.tire, tireListed: isNumber(tireFigure(size, position)) || (isNumber(tireWidth) && !fellBack) }
  }
  return {
    bb: lift([0, 0]),
    ...Object.fromEntries(['rearAxle', 'frontAxle', 'headTop', 'headBottom', 'seatTop', 'seatBottom'].map((key) => [key, lift(frame[key])])),
    rearWheel: tireOf('rear', frame.rearRadius),
    frontWheel: tireOf('front', frame.frontRadius),
    // whether it works `key` out from the figures the size lists: one it records calculating, or any it measures once
    // nothing it's drawn from is typical. Taking a default could feed any of them, so rules them all out, as a BMX's typical
    // fork does all but those it's drawn without
    calculates: (key) => !defaulted && (!frame.assumed.some((each) => TYPICAL_FORK.includes(each)) || UNFORKED.includes(key)) &&
      (frame.calculated.includes(key) || (frame.assumed.length === 0 && !frame.typicalWheel))
  }
}

// up the steering axis and the seat tube
const axes = ({ bb, headTop, headBottom, seatTop }) => ({ steering: unit(minus(headTop, headBottom)), seat: unit(minus(seatTop, bb)) })

const quadratic = (start, control, end, steps = 16) => Array.from({ length: steps + 1 }, (_, index) => {
  const t = index / steps
  return plus(scale(start, (1 - t) ** 2), scale(control, 2 * (1 - t) * t), scale(end, t ** 2))
})

// A step-through's tube, from part way down the head tube through its lowest point to the seat tube, never closer to the
// down tube than a tube's width
const stepTube = (frame, standover) => {
  const { bb, headTop, headBottom } = frame
  const { seat } = axes(frame)
  const floor = (x) => x < bb[0] || x > headBottom[0] ? -Infinity : lerp(bb, headBottom, (x - bb[0]) / (headBottom[0] - bb[0]))[1] + 50
  const start = lerp(headTop, headBottom, 0.3)
  const end = atHeight(bb, seat, Math.max(standover - 30, bb[1] + 90))
  const lowX = lerp(end, start, 0.45)[0]
  const low = [lowX, Math.max(standover, floor(lowX))]
  return quadratic(start, minus(scale(low, 2), scale(plus(start, end), 0.5)), end).map(([x, y]) => [x, Math.max(y, floor(x))])
}

// The bench a moto-style bike's rider sits on, its front over the seat tube and the rest out back, the top tube running
// back under it to the seat stays
const bench = (frame, { fig }) => {
  const front = [frame.seatTop[0] + 140, fig('seat_height')]
  const back = minus(front, [fig('seat_length'), 0])
  return { front, back, under: plus(front, [-40, -70]), tail: plus(back, [60, -70]) }
}

// Its stem, up the steering axis from the head tube and out its length to the bar's clamp, a BMX's short where it lists
// none. Drawn a tube's weight, heavier than its bar, so it's plain where it stops
const cockpit = (frame, { fig, listed, data }) => {
  const bmx = BMX.test(data.primary_activity)
  // over a spacer's height up the steerer, a BMX's stem straight on its headset
  const stem = plus(frame.headTop, scale(axes(frame).steering, bmx ? 10 : 30))
  return { bmx, stem, clamp: plus(stem, polar(bmx && !listed('stem_length') ? 50 : fig('stem_length'), 6)) }
}

// Its tubes, and what its rider sits on and steers by, a `detail` swapping the top tube and saddle for its own
const bikeShapes = (frame, context, detail) => {
  const { fig, data } = context
  const { bb, rearAxle, frontAxle, headTop, headBottom, seatTop, seatBottom } = frame
  const { steering, seat } = axes(frame)
  const { bmx, stem, clamp } = cockpit(frame, context)
  // a BMX's saddle down on and along its top tube
  const top = plus(seatTop, scale(seat, bmx ? 30 : 170))
  const saddled = [tube(seatTop, seatBottom), part(seatTop, top), saddle(top, 150, bmx ? unit(minus(headTop, seatTop)) : [1, 0])]
  const { front, back, under, tail } = bench(frame, { fig })
  const riser = atHeight(headTop, steering, fig('handlebar_height'))
  const body = {
    step_through: () => [tube(frontAxle, headBottom, headTop), tube(seatTop, rearAxle, bb, headBottom), tube(...stepTube(frame, fig('standover'))),
      ...saddled, tube(headTop, stem, clamp), handlebar(clamp)],
    bench_seat: () => [tube(frontAxle, headBottom, headTop, under, tail, rearAxle, bb, headBottom), tube(bb, under),
      panel(front, back, plus(back, [0, -70]), plus(front, [-30, -70])), part(headTop, riser), handlebar(riser)]
  }[detail]?.() ?? [tube(frontAxle, headBottom, headTop, seatTop, rearAxle, bb, headBottom), ...saddled, tube(headTop, stem, clamp),
    bmx ? bmxBar(clamp, steering) : ROAD.test(data.primary_activity) ? dropBar(clamp) : handlebar(clamp)]
  return [wheel(rearAxle, frame.rearWheel), wheel(frontAxle, frame.frontWheel), body]
}

// the figures bikeDims measures off the frame, which it works out where the size doesn't list them
const FRAME_FIGURES = ['stack', 'reach', 'top_tube_effective', 'head_tube', 'head_angle', 'seat_tube_ct', 'seat_angle', 'chainstay', 'wheelbase', 'bb_drop', 'bb_height', 'fork_rake', 'trail']

const bikeDims = (frame, context, detail) => {
  const { fig, listed } = context
  const { bb, rearAxle, frontAxle, headTop, headBottom, seatTop } = frame
  const { steering, seat } = axes(frame)
  const headAngle = Math.atan2(steering[1], -steering[0]) * 180 / Math.PI
  const seatAngle = Math.atan2(seat[1], -seat[0]) * 180 / Math.PI
  const seatAtStack = atHeight(bb, seat, headTop[1])
  const seated = bench(frame, { fig })
  const topTube = detail === 'bench_seat' ? seated.under : seatTop
  // just forward of the bottom bracket, between the BB height's line and the seat tube's out in front: on the top tube, or a
  // step-through's step tube
  const standoverX = bb[0] + STANDOVER_X
  const standoverAt = detail === 'step_through'
    ? stepTube(frame, fig('standover')).reduce((closest, each) => Math.abs(each[0] - standoverX) < Math.abs(closest[0] - standoverX) ? each : closest)
    : lerp(topTube, headTop, (standoverX - topTube[0]) / (headTop[0] - topTube[0]))
  const ground = atHeight(headTop, steering, 0)
  const foot = plus(headTop, scale(steering, dot(minus(frontAxle, headTop), steering)))
  const { stem, clamp } = cockpit(frame, context)
  return [
    v('stack', bb, headTop, 0.8),
    h('reach', bb, headTop, 1.1),
    h('top_tube_effective', seatAtStack, headTop, 2.3),
    d('head_tube', headTop, headBottom, 1),
    ...(detail === 'bench_seat' ? [] : [d('stem_length', stem, clamp, 0.4)]),
    angle('head_angle', ground, headAngle, 3.4),
    ...(detail === 'bench_seat' ? [] : [d('seat_tube_ct', bb, seatTop, -1.8), angle('seat_angle', bb, seatAngle, 3.4)]),
    d('chainstay', bb, rearAxle, 1),
    overall('wheelbase', rearAxle[0], frontAxle[0], -1.6),
    ...tires(rearAxle, frame.rearWheel, frontAxle, frame.frontWheel),
    // negative where the bottom bracket rises above the axles, as a BMX's does
    v('bb_drop', rearAxle, bb, -1, { base: rearAxle[0], value: rearAxle[1] - bb[1] }),
    fromGround('bb_height', bb),
    // from the bottom bracket where it's listed lower than that, as a BMX's is
    fig('standover') < bb[1]
      ? v('standover', [standoverAt[0], bb[1]], standoverAt, 0, { base: standoverAt[0] })
      : fromGround('standover', standoverAt, 0, { t: detail === 'step_through' ? 0.7 : 0.5 }),
    d('fork_rake', foot, frontAxle, -0.6, { guides: [[headBottom, foot]] }),
    h('trail', ground, [frontAxle[0], 0], -0.7, { base: 0 }),
    ...(detail === 'bench_seat'
      ? [fromGround('seat_height', seated.front, 0, { base: seated.front[0] - 40 }), h('seat_length', seated.back, seated.front, 0.8),
          fromGround('handlebar_height', atHeight(headTop, steering, fig('handlebar_height')), 1.2, { base: frontAxle[0] + frame.frontWheel.r })]
      : [])
  ].map((dim) => FRAME_FIGURES.includes(dim.key) && !listed(dim.key) && frame.calculates(dim.key) ? { ...dim, calculated: true } : dim)
}

// A bike, `detail` a type_detail drawn its own way: a step-through's low tube or a moto-style bench
const bike = (detail, fallback = { bsd: 622, tire: 30 }) => (context) => {
  const frame = bikeFrame(context, fallback)
  return [{ name: 'Side', shapes: bikeShapes(frame, context, detail), dims: bikeDims(frame, context, detail) }]
}

const BIKE = { stack: 570, reach: 390, head_tube: 150, head_angle: 72, seat_angle: 73.5, chainstay: 420, bb_drop: 70, fork_rake: 45, stem_length: 100 }

// A longtail's frame, its rack back from the seat stay over the rear wheel and past it
const longtail = (context) => {
  const frame = bikeFrame(context, { bsd: 559, tire: 60 })
  const { rearAxle, seatTop, rearWheel } = frame
  const rackY = rearAxle[1] + rearWheel.r + 60
  const rackFront = atHeight(rearAxle, minus(seatTop, rearAxle), rackY + 12.5)[0]
  // past the rear tire, as a longtail's runs
  const rackBack = rearAxle[0] - rearWheel.r - 100
  return [{
    name: 'Side',
    shapes: [bikeShapes(frame, context), box([rackBack, rackY], [rackFront, rackY + 25]), thin([rackBack + 40, rackY], rearAxle)],
    dims: [...bikeDims(frame, context),
      overall('dimensions.length', Math.min(rackBack, rearAxle[0] - rearWheel.r), frame.frontAxle[0] + frame.frontWheel.r)]
  }]
}

const tandem = ({ fig, listed, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear'], { bsd: 622, tire: 35 }), wheelAt(['front'], { bsd: 622, tire: 35 })]
  const captain = [0, rearWheel.r - fig('bb_drop')]
  const stoker = minus(captain, [fig('boom_tube'), 0])
  const rearAxle = [stoker[0] - leg(fig('chainstay'), fig('bb_drop')), rearWheel.r]
  const frontAxle = [rearAxle[0] + fig('wheelbase'), frontWheel.r]
  const steeringUp = rising(fig('head_angle'))
  const headTop = (listed('stack') && listed('reach')) || !listed('wheelbase')
    ? plus(captain, [fig('reach'), fig('stack')])
    : plus(frontAxle, scale(steeringUp, frontWheel.r + 380 + fig('head_tube')), polar(fig('fork_rake'), -fig('head_angle')))
  const headBottom = plus(headTop, scale(steeringUp, -fig('head_tube')))
  const captainTop = plus(captain, polar(fig('captain_seat_tube'), 180 - fig('seat_angle')))
  const stokerTop = plus(stoker, polar(fig('stoker_seat_tube'), 180 - fig('stoker_seat_angle_degrees')))
  const stokerBar = plus(captainTop, [-60, 150])
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel),
      tube(frontAxle, headBottom, headTop, captainTop, captain, headBottom), tube(captain, stoker, stokerTop, captainTop), tube(stoker, rearAxle, stokerTop),
      part(captainTop, plus(captainTop, polar(170, 180 - fig('seat_angle')))), saddle(plus(captainTop, polar(170, 180 - fig('seat_angle')))),
      part(stokerTop, plus(stokerTop, polar(170, 180 - fig('stoker_seat_angle_degrees')))), saddle(plus(stokerTop, polar(170, 180 - fig('stoker_seat_angle_degrees')))),
      part(plus(captainTop, polar(120, 180 - fig('seat_angle'))), stokerBar), handlebar(stokerBar),
      part(headTop, plus(headTop, scale(steeringUp, 30)), plus(headTop, scale(steeringUp, 30), [100, 10])), dropBar(plus(headTop, scale(steeringUp, 30), [100, 10]))],
    dims: [
      v('stack', captain, headTop, 0.8),
      h('reach', captain, headTop, 1.1),
      h('captain_top_tube', captainTop, headTop, 2.3),
      h('stoker_top_tube_effective', stokerTop, captainTop, 1.1),
      d('captain_seat_tube', captain, captainTop, 1),
      d('stoker_seat_tube', stoker, stokerTop, 1),
      h('boom_tube', stoker, captain, -1.1),
      d('chainstay', stoker, rearAxle, 1),
      angle('head_angle', headBottom, fig('head_angle')),
      overall('wheelbase', rearAxle[0], frontAxle[0], -2.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel)
    ]
  }]
}

// A front-loader: a long low beam out to its own steering head over the small front wheel, the box on it
const longJohn = (context) => {
  const { fig, listed, wheel: wheelAt, data, size } = context
  const [rearWheel, frontWheel] = [wheelAt(['rear'], { bsd: 559, tire: 55 }), wheelAt(['front'], { bsd: 406, tire: 55 })]
  const bb = [0, fig('bb_height')]
  const rearAxle = [-leg(fig('chainstay'), bb[1] - rearWheel.r), rearWheel.r]
  const frontAxle = [rearAxle[0] + wheelbaseOf(context, rearWheel, frontWheel), frontWheel.r]
  const up = rising(fig('head_angle'))
  // the steering axis down to the ground its trail ahead of the front wheel's contact, else through the front axle
  const ground = [frontAxle[0] + (listed('trail') ? fig('trail') : frontWheel.r * up[0] / -up[1]), 0]
  const foot = plus(ground, scale(up, dot(minus(frontAxle, ground), up)))
  const headBottom = plus(foot, scale(up, frontWheel.r + 90))
  const headTop = plus(headBottom, scale(up, fig('head_tube')))
  const seatTop = plus(bb, polar(480, 180 - fig('seat_angle')))
  const riderHead = [seatTop[0] + fig('top_tube_effective'), seatTop[1] + 60]
  const beamY = bb[1] - 20
  const boxFront = frontAxle[0] - frontWheel.r - 40
  // the vehicle's cargo area rather than a size's, so a figure only where it's set as one
  const cargoLength = listedFigure(size, 'cargo.length') ?? data.cargo?.length
  // where the rider's steerer meets the beam, at the back of the cargo area
  const riderFoot = [isNumber(cargoLength) ? boxFront - cargoLength : riderHead[0] + 70, beamY]
  const top = plus(seatTop, polar(200, 180 - fig('seat_angle')))
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel),
      tube(rearAxle, bb, riderFoot, [boxFront, beamY], headBottom, headTop), tube(frontAxle, headBottom), tube(seatTop, bb), tube(seatTop, rearAxle),
      tube(riderHead, riderFoot),
      part(seatTop, top), saddle(top), part(riderHead, plus(riderHead, [-20, 160])), handlebar(plus(riderHead, [-20, 160]))],
    dims: [
      h('top_tube_effective', seatTop, riderHead, 1.4),
      d('chainstay', bb, rearAxle, 1),
      angle('seat_angle', bb, fig('seat_angle'), 3.4),
      d('head_tube', headTop, headBottom, 1),
      angle('head_angle', headBottom, fig('head_angle')),
      h('trail', ground, [frontAxle[0], 0], -0.7, { base: 0 }),
      fromGround('bb_height', bb),
      fromGround('standover', lerp(riderFoot, bb, 0.4)),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4, { calculated: lengthwise(context) }),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel),
      overall('dimensions.length', rearAxle[0] - rearWheel.r, frontAxle[0] + frontWheel.r),
      h('cargo.length', riderFoot, [boxFront, beamY], 0.8, { listed: isNumber(cargoLength) })
    ]
  }]
}

const balanceBike = ({ fig, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear'], { bsd: 203, tire: 50 }), wheelAt(['front'], { bsd: 203, tire: 50 })]
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const up = rising(fig('head_angle'))
  const headBottom = plus(frontAxle, scale(up, frontWheel.r + 50))
  const headTop = plus(headBottom, scale(up, fig('head_tube')))
  const cluster = [fig('wheelbase') * 0.3, fig('standover')]
  const seat = rising(75)
  const [high, low] = ['seat_height_max', 'seat_height_min'].map((key) => atHeight(cluster, seat, fig(key) - 15))
  const [barHigh, barLow] = ['handlebar_height_max', 'handlebar_height_min'].map((key) => atHeight(headTop, up, fig(key)))
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), tube(frontAxle, headBottom, headTop), tube(lerp(headBottom, headTop, 0.4), plus(cluster, [40, -25]), cluster, rearAxle),
      part(cluster, high), saddle(plus(high, [0, 15]), 110), ghost(...saddle(plus(low, [0, 15]), 110).points), part(headTop, barHigh), handlebar(barHigh), ring(barLow, 14, 'ghost')],
    dims: [
      fromGround('seat_height_max', plus(high, [0, 15]), -1.2, { base: rearAxle[0] - rearWheel.r }),
      fromGround('seat_height_min', plus(low, [0, 15]), -2.4, { base: rearAxle[0] - rearWheel.r }),
      fromGround('handlebar_height_max', barHigh, 1.2, { base: frontAxle[0] + frontWheel.r }),
      fromGround('handlebar_height_min', barLow, 2.4, { base: frontAxle[0] + frontWheel.r }),
      fromGround('standover', plus(cluster, [60, -20])),
      angle('head_angle', headBottom, fig('head_angle'), 2),
      across('wheel_size', rearAxle, rearWheel),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel)
    ]
  }]
}

// Two frames, the upper's main triangle bolted up the lower's steering axis
const tallBike = (context) => {
  const lower = bikeFrame(context, { bsd: 622, tire: 32 })
  const { steering, seat } = axes(lower)
  const raise = scale(steering, context.fig('frame_offset') / steering[1])
  const [bb, headTop, headBottom, seatTop] = ['bb', 'headTop', 'headBottom', 'seatTop'].map((key) => plus(lower[key], raise))
  const top = plus(seatTop, scale(seat, 170))
  const clamp = plus(headTop, scale(steering, 30), [90, 10])
  return [{
    name: 'Side',
    shapes: [wheel(lower.rearAxle, lower.rearWheel), wheel(lower.frontAxle, lower.frontWheel),
      tube(lower.frontAxle, lower.headBottom, lower.headTop, lower.seatTop, lower.rearAxle, lower.bb, lower.headBottom), tube(lower.seatTop, lower.bb),
      tube(lower.headTop, headBottom, headTop, seatTop, bb, headBottom), tube(lower.seatTop, bb), thin(bb, lower.bb),
      part(seatTop, top), saddle(top), part(headTop, clamp), handlebar(clamp)],
    dims: [
      fromGround('seat_height', plus(top, [0, 10]), -1.4, { base: lower.rearAxle[0] - lower.rearWheel.r }),
      fromGround('standover', lerp(seatTop, headTop, 0.55)),
      fromGround('bb_height', bb, 1.4, { base: lower.frontAxle[0] + lower.frontWheel.r }),
      v('frame_offset', lower.bb, bb, -1.2),
      overall('wheelbase', lower.rearAxle[0], lower.frontAxle[0], -1.4),
      ...tires(lower.rearAxle, lower.rearWheel, lower.frontAxle, lower.frontWheel)
    ]
  }]
}

const pennyFarthing = ({ fig, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear'], { bsd: 406, tire: 22 }), wheelAt(['front'], { bsd: 1270, tire: 22 })]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const rearAxle = [0, rearWheel.r]
  const backbone = arc(frontAxle, frontWheel.r + 70, 82, 150, 12)
  const seat = plus(frontAxle, polar(frontWheel.r + 70, 104))
  const top = [seat[0], fig('seat_height')]
  const head = plus(frontAxle, polar(frontWheel.r + 70, 82))
  const bar = plus(head, [80, 90])
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), tube(frontAxle, head), tube(...backbone, plus(rearAxle, [30, rearWheel.r + 30]), rearAxle),
      part(seat, top), saddle(plus(top, [0, 10]), 120), part(head, bar), handlebar(bar)],
    dims: [
      across('wheel_front', frontAxle, frontWheel),
      across('wheel_rear', rearAxle, rearWheel),
      fromGround('seat_height', plus(top, [0, 10]), -1.4, { base: rearAxle[0] - rearWheel.r }),
      d('crank_length', frontAxle, plus(frontAxle, polar(fig('crank_length'), -60)), -0.8),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel)
    ]
  }]
}

const unicycle = ({ fig, wheel: wheelAt }) => {
  const hub = wheelAt(['center', 'front'], { bsd: 507, tire: 60 })
  const axle = [0, hub.r]
  const crown = [0, 2 * hub.r + 50]
  const top = [0, fig('seat_height')]
  const pedal = plus(axle, [0, -fig('crank_length')])
  return [{
    name: 'Side',
    shapes: [wheel(axle, hub), tube(axle, plus(axle, [-25, hub.r + 50]), crown, plus(axle, [25, hub.r + 50]), axle), part(crown, top),
      part(plus(top, [-150, 25]), plus(top, [-130, 0]), plus(top, [120, 0]), plus(top, [150, 30]))],
    dims: [
      across('wheel_size', axle, hub),
      fromGround('seat_height', top, -1.4, { base: -hub.r }),
      v('crank_length', pedal, axle, 1.2, { base: 45 })
    ]
  }]
}

// An upright tricycle, its rear wheels or its front ones `paired`, and the basket or box over them
const tricycle = ({ paired }) => ({ fig, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear', 'rear_left'], { bsd: 507, tire: 50 }), wheelAt(['front', 'front_left'], { bsd: 507, tire: 50 })]
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const frontBox = paired === 'front'
  const up = rising(fig('head_angle'))
  const headBottom = frontBox ? plus(frontAxle, [-frontWheel.r - 160, frontWheel.r + 520]) : plus(frontAxle, scale(up, frontWheel.r + 90))
  const headTop = plus(headBottom, scale(up, 160))
  const bb = [fig('wheelbase') * (frontBox ? 0.2 : 0.42), 300]
  const seatUp = rising(70)
  const top = atHeight(bb, seatUp, fig('seat_height_max'))
  const low = atHeight(bb, seatUp, fig('seat_height_min'))
  const bar = atHeight(headTop, up, fig('handlebar_height'))
  const step = [bb[0] + 140, fig('standover')]
  const load = frontBox
    ? box([frontAxle[0] - fig('box_length') / 2, frontAxle[1] + 60], [frontAxle[0] + fig('box_length') / 2, frontAxle[1] + 60 + fig('box_height')])
    : box([rearAxle[0] - fig('box_length') / 2, 2 * rearWheel.r + 40], [rearAxle[0] + fig('box_length') / 2, 2 * rearWheel.r + 40 + fig('box_height')])
  const side = {
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), load,
      frontBox ? tube(frontAxle, plus(frontAxle, [-frontWheel.r - 60, 40]), step, bb) : tube(frontAxle, headBottom, headTop),
      frontBox ? part(plus(headBottom, [0, -60]), bar) : tube(lerp(headBottom, headTop, 0.3), step, bb),
      tube(bb, rearAxle, plus(bb, scale(seatUp, 300)), bb), part(plus(bb, scale(seatUp, 300)), top), saddle(top), ghost(...saddle(low).points),
      frontBox ? [] : part(headTop, bar), handlebar(bar)],
    dims: [
      fromGround('seat_height_max', top, -1.2, { base: rearAxle[0] - rearWheel.r - (frontBox ? 0 : fig('box_length') / 2 - rearWheel.r) }),
      fromGround('seat_height_min', low, -2.4, { base: rearAxle[0] - rearWheel.r - (frontBox ? 0 : fig('box_length') / 2 - rearWheel.r) }),
      fromGround('handlebar_height', bar, 1.2, { base: frontAxle[0] + (frontBox ? fig('box_length') / 2 : frontWheel.r) }),
      fromGround('standover', step),
      h('box_length', ...(frontBox ? [[frontAxle[0] - fig('box_length') / 2, 0], [frontAxle[0] + fig('box_length') / 2, 0]] : [[rearAxle[0] - fig('box_length') / 2, 0], [rearAxle[0] + fig('box_length') / 2, 0]]), 0.8,
        { base: (frontBox ? frontAxle[1] + 60 : 2 * rearWheel.r + 40) + fig('box_height') }),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel)
    ]
  }
  const track = fig('track_width')
  const pairX = frontBox ? frontAxle[0] : rearAxle[0]
  const pair = frontBox ? frontWheel : rearWheel
  const single = frontBox ? [rearAxle[0], rearWheel] : [frontAxle[0], frontWheel]
  const above = {
    name: 'Top',
    plan: true,
    shapes: [footprint(pairX, track / 2, pair), footprint(pairX, -track / 2, pair), footprint(single[0], 0, single[1]), tube([pairX, -track / 2], [pairX, track / 2]),
      tube([pairX, 0], [single[0], 0]), box([pairX - fig('box_length') / 2, -fig('box_width') / 2], [pairX + fig('box_length') / 2, fig('box_width') / 2], ghost)],
    dims: [v('track_width', [pairX, -track / 2], [pairX, track / 2], 1.2, { base: pairX + Math.max(pair.r, fig('box_length') / 2) }),
      v('dimensions.width', [pairX, -track / 2 - pair.tire / 2], [pairX, track / 2 + pair.tire / 2], 2.4, { base: pairX + Math.max(pair.r, fig('box_length') / 2) })]
  }
  return [side, above]
}

// Laid back on a low seat with the cranks out front, its pair of wheels `paired` or none
const recumbent = ({ bsd }) => ({ fig, wheel: wheelAt, data }) => {
  const positions = array(data.wheels).flatMap((each) => array(each.position))
  const paired = positions.includes('rear_left') ? 'rear' : positions.length === 0 || positions.includes('front_left') ? 'front' : null
  const [rearWheel, frontWheel] = [wheelAt(['rear', 'rear_left'], { bsd, tire: 40 }), wheelAt(['front', 'front_left'], { bsd, tire: 40 })]
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const bb = [fig('wheelbase') + 330, fig('bb_height')]
  const seatFront = [fig('wheelbase') * 0.5, fig('seat_height') + 30]
  const seatBack = [fig('wheelbase') * 0.3, fig('seat_height')]
  const backTop = plus(seatBack, polar(560, 180 - fig('seat_angle')))
  const pivot = [fig('wheelbase') * 0.3, 230]
  const stick = [fig('wheelbase') * 0.55, fig('seat_height') + 230]
  const side = {
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), tube(rearAxle, pivot, [frontAxle[0], frontAxle[1] + 30], bb), tube(pivot, seatBack),
      part(seatFront, seatBack, backTop), part([frontAxle[0] - 60, frontAxle[1] + 40], stick), handlebar(stick)],
    dims: [
      fromGround('seat_height', seatBack, 0, { base: seatBack[0] - 30 }),
      angle('seat_angle', seatBack, fig('seat_angle'), 3),
      fromGround('bb_height', bb, 1.2, { base: bb[0] + fig('crank_length') }),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel),
      overall('dimensions.length', rearAxle[0] - rearWheel.r, bb[0] + fig('crank_length'))
    ]
  }
  if (!paired) return [side]

  const track = fig('track_width')
  const [pairX, pair, single] = paired === 'front' ? [frontAxle[0], frontWheel, [rearAxle[0], rearWheel]] : [rearAxle[0], rearWheel, [frontAxle[0], frontWheel]]
  return [side, {
    name: 'Top',
    plan: true,
    shapes: [footprint(pairX, track / 2, pair), footprint(pairX, -track / 2, pair), footprint(single[0], 0, single[1]), tube([pairX, -track / 2], [pairX, track / 2]),
      tube([rearAxle[0], 0], [bb[0], 0]), box([seatBack[0] - 120, -190], [seatFront[0], 190], ghost)],
    dims: [v('track_width', [pairX, -track / 2], [pairX, track / 2], 1.2, { base: bb[0] }),
      v('dimensions.width', [pairX, -track / 2 - pair.tire / 2], [pairX, track / 2 + pair.tire / 2], 2.4, { base: bb[0] })]
  }]
}

// A half bike towed from the seatpost of the bike ahead, drawn in outline
const trailBehind = ({ fig, wheel: wheelAt }) => {
  const rearWheel = wheelAt(['rear', 'center', 'front'], { bsd: 406, tire: 50 })
  const axle = [0, rearWheel.r]
  const bb = [260, 290]
  const seatUp = rising(72)
  const cluster = atHeight(bb, seatUp, 600)
  const top = atHeight(bb, seatUp, fig('seat_height'))
  const head = [520, fig('standover') + 60]
  const hitch = [head[0] + fig('tow_arm_length'), fig('hitch_height')]
  const towAxle = [hitch[0] - 380, 340]
  const towSeat = rising(73)
  return [{
    name: 'Side',
    shapes: [wheel(axle, rearWheel), ring(towAxle, 340, 'ghost'), ghost(towAxle, atHeight(hitch, towSeat, 300), plus(hitch, scale(towSeat, 150))),
      tube(axle, bb, cluster, axle), tube(cluster, head, bb), tube(head, hitch), part(cluster, top), saddle(top), part(head, plus(head, [30, 160])), handlebar(plus(head, [30, 160]))],
    dims: [
      fromGround('seat_height', top, -1.2, { base: -rearWheel.r }),
      fromGround('standover', lerp(cluster, head, 0.5)),
      fromGround('hitch_height', hitch, 1.2, { base: atHeight(hitch, towSeat, 300)[0] }),
      d('tow_arm_length', head, hitch, 1),
      across('wheel_size', axle, rearWheel),
      overall('dimensions.length', axle[0] - rearWheel.r, hitch[0], -1.4)
    ]
  }]
}

// A rider's front end hauling a bench under a canopy
const pediCab = ({ fig, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear', 'rear_left'], { bsd: 559, tire: 50 }), wheelAt(['front'], { bsd: 559, tire: 50 })]
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const up = rising(70)
  const headBottom = plus(frontAxle, scale(up, frontWheel.r + 100))
  const headTop = plus(headBottom, scale(up, 180))
  const bb = [frontAxle[0] - 650, 300]
  const seatUp = rising(72)
  const top = atHeight(bb, seatUp, fig('seat_height'))
  const benchHeight = fig('bench_height')
  const roof = fig('dimensions.height')
  const back = rearAxle[0] - 420
  const canopy = arc([rearAxle[0], roof - 470], 470, 150, 30, 12)
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), tube(frontAxle, headBottom, headTop), tube(lerp(headBottom, headTop, 0.3), bb, rearAxle),
      tube(bb, plus(bb, scale(seatUp, 380)), lerp(headBottom, headTop, 0.6)), part(plus(bb, scale(seatUp, 380)), top), saddle(top), part(headTop, plus(headTop, [-60, 120])), handlebar(plus(headTop, [-60, 120])),
      box([back, benchHeight - 80], [rearAxle[0] + 380, benchHeight]), panel([back, benchHeight], [back + 60, benchHeight], [back + 20, benchHeight + 450], [back - 40, benchHeight + 450]),
      tube([rearAxle[0], rearAxle[1]], [rearAxle[0], benchHeight - 80]), part([back - 40, benchHeight], canopy[0]), part([rearAxle[0] + 380, benchHeight], canopy.at(-1)), part(...canopy)],
    dims: [
      fromGround('bench_height', [rearAxle[0] + 200, benchHeight]),
      fromGround('seat_height', top, 0, { base: top[0] }),
      fromGround('dimensions.height', [rearAxle[0], roof], -1.2, { base: canopy[0][0] }),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel),
      overall('dimensions.length', back - 40, frontAxle[0] + frontWheel.r)
    ]
  }]
}

// Striding on platforms that run an elliptical path between a drive at the rear wheel and a rocker under the bars
const ellipticalBike = ({ fig, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear'], { bsd: 349, tire: 35 }), wheelAt(['front'], { bsd: 406, tire: 40 })]
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const up = rising(72)
  const headBottom = plus(frontAxle, scale(up, frontWheel.r + 80))
  const bar = atHeight(headBottom, up, fig('operating_height'))
  const drive = [80, rearWheel.r + 40]
  const rocker = [frontAxle[0] - 330, 520]
  // at the bottom of its stride
  const platform = [fig('wheelbase') * 0.35, fig('platform_height')]
  const [strideX, strideY] = [fig('stride_length') / 2, fig('stride_height') / 2]
  const stride = plus(platform, [0, strideY])
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), tube(frontAxle, headBottom, bar), tube(rearAxle, [fig('wheelbase') * 0.45, 380], lerp(headBottom, bar, 0.1)),
      ghost(...Array.from({ length: 33 }, (_, index) => plus(stride, [strideX * Math.cos(index * Math.PI / 16), strideY * Math.sin(index * Math.PI / 16)]))),
      part(drive, platform, rocker), part(rocker, plus(rocker, [60, 300])), box(plus(platform, [-140, 0]), plus(platform, [140, 25])), handlebar(bar)],
    dims: [
      fromGround('platform_height', platform, 0, { base: platform[0] + 160 }),
      h('stride_length', minus(stride, [strideX, 0]), plus(stride, [strideX, 0]), 0.6, { base: stride[1] + strideY }),
      v('stride_height', platform, plus(platform, [0, 2 * strideY]), 0, { base: stride[0] + strideX + 40 }),
      fromGround('operating_height', bar, 1.2, { base: frontAxle[0] + frontWheel.r }),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel),
      overall('dimensions.length', rearAxle[0] - rearWheel.r, frontAxle[0] + frontWheel.r)
    ]
  }]
}

// A deck between two small wheels, a stem up from the front one, and folded with the stem down along the deck
const scooter = ({ kick }) => (context) => {
  const { fig, either, listed, wheel: wheelAt } = context
  const fallback = kick ? { bsd: 145, tire: 0 } : { bsd: 152, tire: 50 }
  const [rearWheel, frontWheel] = [wheelAt(['rear'], fallback), wheelAt(['front'], fallback)]
  const wheelbase = wheelbaseOf(context, rearWheel, frontWheel)
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [wheelbase, frontWheel.r]
  const up = rising(80)
  const deck = [rearAxle[0] + rearWheel.r * 0.3, frontAxle[0] - frontWheel.r - 50]
  const alongDeck = (t) => deck[0] + (deck[1] - deck[0]) * t
  const deckTop = fig('deck_height')
  const deckBottom = deckTop - 45
  const crown = plus(frontAxle, scale(up, frontWheel.r + 60))
  const bar = atHeight(frontAxle, up, either('handlebar_height', 'dimensions.height'))
  const seated = listed('seat_height')
  const seat = seated && [alongDeck(0.35), fig('seat_height')]
  const body = (stemTo) => [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), box([deck[0], deckBottom], [deck[1], deckTop]),
    part(...arc(rearAxle, rearWheel.r + 15, 40, 160, 8)), tube([deck[1], (deckTop + deckBottom) / 2], crown), tube(frontAxle, crown, stemTo), handlebar(stemTo)]
  const sideView = {
    name: 'Side',
    shapes: [body(bar), seated ? [part([seat[0], deckTop], seat), saddle(seat, fig('seat_length'))] : []],
    dims: [
      fromGround('handlebar_height', bar, 1.2, { base: frontAxle[0] + frontWheel.r }),
      fromGround('dimensions.height', bar, 2.4, { base: frontAxle[0] + frontWheel.r }),
      fromGround('deck_height', [alongDeck(0.7), deckTop], 0, { side: -1 }),
      ...(kick ? [] : [fromGround('ground_clearance', [alongDeck(0.85), deckBottom])]),
      ...(seated ? [fromGround('seat_height', seat, -1.2, { base: rearAxle[0] - rearWheel.r })] : []),
      h('deck_length', [deck[0], deckTop], [deck[1], deckTop], 0.8),
      across('wheel_size', frontAxle, frontWheel),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4, { calculated: lengthwise(context) }),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel),
      overall('dimensions.length', rearAxle[0] - rearWheel.r, frontAxle[0] + frontWheel.r)
    ]
  }
  const width = fig('handlebar_width')
  const frontView = {
    name: 'Front',
    shapes: [tread(0, frontWheel), box([-fig('deck_width') / 2, deckBottom], [fig('deck_width') / 2, deckTop], ghost), tube([0, frontWheel.r], [0, bar[1]]),
      part([-width / 2, bar[1]], [width / 2, bar[1]]), part([-width / 2, bar[1] - 5], [-width / 2 + 110, bar[1] - 5]), part([width / 2 - 110, bar[1] - 5], [width / 2, bar[1] - 5])],
    dims: [h('handlebar_width', [-width / 2, bar[1]], [width / 2, bar[1]], 0.8), h('deck_width', [-fig('deck_width') / 2, 0], [fig('deck_width') / 2, 0], -1.2, { base: 0 })]
  }
  if (kick && !listed('dimensions_folded.height')) return [sideView, frontView]

  const folded = [rearAxle[0] + rearWheel.r * 0.4, fig('dimensions_folded.height') - 15]
  return [sideView, frontView, {
    name: 'Folded',
    shapes: body(folded),
    dims: [fromGround('dimensions_folded.height', plus(folded, [0, 15]), -1.2, { base: rearAxle[0] - rearWheel.r }),
      overall('dimensions_folded.length', rearAxle[0] - rearWheel.r, frontAxle[0] + frontWheel.r, -1.4)]
  }]
}

// A deck on two trucks, from the side and from above
const skateboard = ({ fig, wheel: wheelAt }) => {
  const hub = wheelAt(['rear', 'front'], { bsd: 70, tire: 0 })
  const length = fig('dimensions.length')
  const wheelbase = fig('wheelbase')
  const deck = fig('deck_height')
  const [rearAxle, frontAxle] = [[-wheelbase / 2, hub.r], [wheelbase / 2, hub.r]]
  const tail = (sign) => [[sign * (wheelbase / 2 + 60), deck], [sign * length / 2, deck + 60]]
  const width = fig('dimensions.width')
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, hub), wheel(frontAxle, hub), tube(...tail(-1).reverse(), ...tail(1)), [rearAxle, frontAxle].map((axle) => part(axle, [axle[0], deck - 15]))],
    dims: [fromGround('deck_height', [0, deck]), overall('wheelbase', rearAxle[0], frontAxle[0], -1.4), overall('dimensions.length', -length / 2, length / 2)]
  }, {
    name: 'Top',
    plan: true,
    shapes: [panel(...arc([length / 2 - width / 2, 0], width / 2, -90, 90, 10), ...arc([-length / 2 + width / 2, 0], width / 2, 90, 270, 10)),
      [rearAxle[0], frontAxle[0]].flatMap((x) => [footprint(x, width / 2 - 20, { r: hub.r, tire: 45 }), footprint(x, -width / 2 + 20, { r: hub.r, tire: 45 })])],
    dims: [v('dimensions.width', [0, -width / 2], [0, width / 2], 1.2, { base: length / 2 })]
  }]
}

// By its wheels: one in the middle under a shell, one under a board, or two either side of a platform
const personalMobility = (context) => {
  const { fig, listed, wheel: wheelAt } = context
  const positions = array(context.data.wheels).flatMap((each) => array(each.position))
  if (positions.includes('front') && !positions.includes('center')) {
    const hub = wheelAt(['front'], { bsd: 110, tire: 0 })
    const span = fig('dimensions.length')
    const deck = hub.r + 20
    return [{
      name: 'Front',
      shapes: [[-1, 1].map((sign) => [wheel([sign * (span / 2 - hub.r), hub.r], hub), part(...arc([sign * (span / 2 - hub.r), hub.r], hub.r + 25, 20, 160, 8))]),
        box([-span / 2 + 2 * hub.r + 10, deck - 40], [span / 2 - 2 * hub.r - 10, deck + 30]), part([-span / 2 + 2 * hub.r + 30, deck + 30], [-40, deck + 30]), part([40, deck + 30], [span / 2 - 2 * hub.r - 30, deck + 30])],
      dims: [overall('dimensions.length', -span / 2, span / 2, -1.4), fromGround('deck_height', [span / 4, deck + 30]), across('wheel_size', [span / 2 - hub.r, hub.r], hub)]
    }]
  }
  const hub = wheelAt(['center', 'front'], { bsd: 356, tire: 70 })
  const axle = [0, hub.r]
  const height = fig('dimensions.height')
  const half = Math.max(listed('dimensions.length') ? fig('dimensions.length') / 2 : 0, hub.r + 30)
  if (listed('dimensions.length') && fig('dimensions.length') > height) {
    const deck = hub.r + 30
    return [{
      name: 'Side',
      shapes: [wheel(axle, hub), tube([-half, deck + 40], [-half + 80, deck], [half - 80, deck], [half, deck + 40]), part(...arc(axle, hub.r + 20, 15, 165, 10))],
      dims: [overall('dimensions.length', -half, half), fromGround('deck_height', [half * 0.6, deck]), across('wheel_size', axle, hub)]
    }]
  }
  const shell = [...arc([0, height - 40 - half], half, 0, 180, 12), [-half, hub.r - 60], [half, hub.r - 60]]
  const pedal = fig('pedal_height')
  const width = fig('dimensions.width')
  return [{
    name: 'Side',
    shapes: [wheel(axle, hub), panel(...shell), part([-60, height - 40], [-40, height], [40, height], [60, height - 40]), tube([-110, pedal], [110, pedal])],
    dims: [fromGround('dimensions.height', [0, height], 1.2, { base: half }), fromGround('pedal_height', [110, pedal]), h('dimensions.length', [-half, 0], [half, 0], -1.4, { base: 0 }), across('wheel_size', axle, hub)]
  }, {
    name: 'Front',
    shapes: [tread(0, hub), box([-width / 2, hub.r - 60], [width / 2, height - 40], ghost), tube([-width / 2 - 110, pedal], [-width / 2, pedal]), tube([width / 2, pedal], [width / 2 + 110, pedal])],
    dims: [h('dimensions.width', [-width / 2, height - 40], [width / 2, height - 40], 0.8)]
  }]
}

const eMotorcycle = ({ fig, either, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear'], { bsd: 457, tire: 110 }), wheelAt(['front'], { bsd: 483, tire: 80 })]
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const up = rising(fig('head_angle'))
  const headBottom = plus(frontAxle, scale(up, frontWheel.r + 380))
  const headTop = plus(headBottom, scale(up, 170))
  const bar = atHeight(headTop, up, either('handlebar_height', 'dimensions.height'))
  const pivot = [fig('wheelbase') * 0.4, rearWheel.r + 110]
  const seatTop = fig('seat_height')
  const seatFront = [pivot[0] + 230, seatTop]
  const seatBack = [seatFront[0] - fig('seat_length'), seatTop]
  const belly = fig('ground_clearance')
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), tube(frontAxle, headBottom, headTop), part(plus(frontAxle, [25, 10]), plus(headBottom, [25, 0])),
      tube(rearAxle, pivot), thin(lerp(rearAxle, pivot, 0.55), plus(pivot, [-40, 260])),
      panel([pivot[0] + 30, belly], [headBottom[0] - 150, belly], [headBottom[0] - 20, headBottom[1] - 20], [headTop[0] - 40, headTop[1] - 40], [seatFront[0] + 40, seatTop - 70], [pivot[0] + 30, pivot[1] + 60]),
      panel(seatBack, seatFront, plus(seatFront, [0, -60]), plus(seatBack, [-20, -60])), part(plus(seatBack, [-20, -60]), [rearAxle[0] - rearWheel.r * 0.8, 2 * rearWheel.r + 40]),
      part(headTop, bar), handlebar(bar), ring(plus(pivot, [30, -50]), 18, 'part')],
    dims: [
      fromGround('seat_height', plus(seatBack, [fig('seat_length') * 0.3, 0])),
      h('seat_length', seatBack, seatFront, 0.8),
      fromGround('ground_clearance', [lerp(pivot, headBottom, 0.35)[0], belly]),
      fromGround('handlebar_height', bar, 1.2, { base: frontAxle[0] + frontWheel.r }),
      fromGround('dimensions.height', bar, 2.4, { base: frontAxle[0] + frontWheel.r }),
      angle('head_angle', headBottom, fig('head_angle')),
      across('wheel_front', frontAxle, frontWheel),
      across('wheel_rear', rearAxle, rearWheel),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel),
      overall('dimensions.length', rearAxle[0] - rearWheel.r, frontAxle[0] + frontWheel.r)
    ]
  }]
}

const wheelchair = ({ fig, wheel: wheelAt }) => {
  const rearWheel = wheelAt(['rear_left', 'rear'], { bsd: 540, tire: 25 })
  const caster = wheelAt(['front_left', 'front'], { bsd: 100, tire: 25 })
  const axle = [0, rearWheel.r]
  const seatHeight = fig('seat_height')
  const depth = fig('seat_depth')
  const seatBack = [-80, seatHeight]
  const seatFront = [seatBack[0] + depth, seatHeight]
  const backTop = plus(seatBack, polar(fig('backrest_height'), 98))
  const casterAxle = [seatFront[0] + 30, caster.r]
  const plate = [seatFront[0] + 150, 120]
  const width = fig('dimensions.width')
  const seatWidth = fig('seat_width')
  return [{
    name: 'Side',
    shapes: [wheel(axle, rearWheel), ring(axle, rearWheel.r - 45), wheel(casterAxle, caster), tube(backTop, seatBack, seatFront, plate), tube(axle, seatBack),
      tube(seatFront, plus(casterAxle, [-30, caster.r + 60]), plus(casterAxle, [0, 0])), part(plate, plus(plate, [-110, 0])), part(backTop, plus(backTop, [-90, -10]))],
    dims: [
      fromGround('seat_height', seatFront, 0, { base: seatFront[0] - 20 }),
      h('seat_depth', seatBack, seatFront, 0.8),
      v('backrest_height', seatBack, backTop, -1.2),
      across('wheel_size', axle, rearWheel),
      overall('dimensions.length', axle[0] - rearWheel.r, plate[0] + 20, -1.4),
      fromGround('dimensions.height', backTop, 1.2, { base: plate[0] + 20 })
    ]
  }, {
    name: 'Front',
    shapes: [tread(-width / 2 + rearWheel.tire / 2, rearWheel), tread(width / 2 - rearWheel.tire / 2, rearWheel), tube([-seatWidth / 2, seatHeight], [seatWidth / 2, seatHeight]),
      box([-seatWidth / 2, seatHeight], [seatWidth / 2, seatHeight + fig('backrest_height')], ghost), tube([-width / 2 + rearWheel.tire, rearWheel.r], [width / 2 - rearWheel.tire, rearWheel.r])],
    dims: [h('seat_width', [-seatWidth / 2, seatHeight], [seatWidth / 2, seatHeight], 0.8, { base: seatHeight + fig('backrest_height') }),
      overall('dimensions.width', -width / 2, width / 2, -1.4)]
  }]
}

const stroller = ({ fig, listed, wheel: wheelAt }) => {
  const [rearWheel, frontWheel] = [wheelAt(['rear', 'rear_left'], { bsd: 230, tire: 40 }), wheelAt(['front', 'front_left'], { bsd: 140, tire: 35 })]
  const rearAxle = [0, rearWheel.r]
  const frontAxle = [fig('wheelbase'), frontWheel.r]
  const grip = [-200, fig('handlebar_height')]
  const hinge = lerp(grip, rearAxle, 0.45)
  const back = plus(lerp(grip, rearAxle, 0.2), [90, 0])
  const seat = [fig('wheelbase') * 0.35, 400]
  const canopy = arc(plus(back, [120, -30]), 230, 175, 35, 10)
  const foldedLength = fig('dimensions_folded.length')
  const foldedHeight = fig('dimensions_folded.height')
  return [{
    name: 'Side',
    shapes: [wheel(rearAxle, rearWheel), wheel(frontAxle, frontWheel), tube(grip, rearAxle), tube(hinge, frontAxle),
      part(back, seat, [fig('wheelbase') * 0.65, 440], [fig('wheelbase') * 0.75, 300]), part(...canopy),
      box([fig('wheelbase') * 0.1, 170], [fig('wheelbase') * 0.6, 250], ghost), handlebar(grip)],
    dims: [
      fromGround('handlebar_height', grip, -1.2, { base: grip[0] - 15 }),
      fromGround('dimensions.height', [grip[0], Math.max(fig('dimensions.height'), grip[1])], -2.4, { base: grip[0] - 15 }),
      overall('wheelbase', rearAxle[0], frontAxle[0], -1.4),
      ...tires(rearAxle, rearWheel, frontAxle, frontWheel),
      overall('dimensions.length', grip[0] - 15, frontAxle[0] + frontWheel.r)
    ]
  }, {
    name: 'Folded',
    shapes: [box([0, 0], [foldedLength, foldedHeight], listed('dimensions_folded.length') ? panel : ghost)],
    dims: [h('dimensions_folded.length', [0, 0], [foldedLength, 0], -1.4, { base: 0 }), v('dimensions_folded.height', [foldedLength, 0], [foldedLength, foldedHeight], 1.2)]
  }]
}

const bikeTrailer = ({ fig, wheel: wheelAt }) => {
  const hub = wheelAt(['rear_left', 'rear', 'center'], { bsd: 406, tire: 50 })
  const axle = [0, hub.r]
  const height = fig('dimensions.height')
  const cabin = [[-380, 140], [330, 140], [420, height - 300], [240, height], [-320, height]]
  const hitch = [-380 + fig('dimensions.length'), 340]
  const width = fig('dimensions.width')
  return [{
    name: 'Side',
    shapes: [panel(...cabin), wheel(axle, hub), tube([330, 220], hitch), ring(hitch, 340, 'ghost')],
    dims: [
      fromGround('dimensions.height', [-320, height], -1.2, { base: -380 }),
      d('tow_arm_length', [330, 220], hitch, 1),
      across('wheel_size', axle, hub),
      overall('dimensions.length', -380, hitch[0], -1.4)
    ]
  }, {
    name: 'Rear',
    shapes: [tread(-width / 2 + 30, hub), tread(width / 2 - 30, hub), box([-width / 2 + 90, 140], [width / 2 - 90, height]), tube([-width / 2 + 30, hub.r], [width / 2 - 30, hub.r])],
    dims: [overall('dimensions.width', -width / 2, width / 2, -1.4)]
  }]
}

const SCOOTER = { wheelbase: 820, deck_height: 170, deck_width: 170, handlebar_height: 1150, handlebar_width: 480, 'dimensions_folded.height': 480, seat_height: 800, seat_length: 300 }
const TRICYCLE = { wheelbase: 1200, head_angle: 70, seat_height_min: 750, seat_height_max: 950, handlebar_height: 1080, standover: 320, track_width: 680, box_length: 600, box_height: 300, box_width: 560 }

const CYCLE_DRAWINGS = {
  bike: { draw: bike(), defaults: BIKE, framed: true },
  'bike/step_through': { draw: bike('step_through'), defaults: { ...BIKE, standover: 450, head_angle: 70, seat_angle: 72 }, framed: true },
  'bike/bench_seat': { draw: bike('bench_seat', { bsd: 406, tire: 100 }), defaults: { ...BIKE, stack: 560, reach: 430, head_angle: 66, chainstay: 460, seat_height: 840, seat_length: 620, handlebar_height: 1080 }, framed: true },
  tandem: { draw: tandem, defaults: { ...BIKE, wheelbase: 1750, boom_tube: 740, captain_seat_tube: 540, stoker_seat_tube: 460, stoker_seat_angle_degrees: 73.5, head_tube: 170 } },
  unicycle: { draw: unicycle, defaults: { seat_height: 880, crank_length: 125 } },
  tricycle: { draw: tricycle({ paired: 'rear' }), defaults: TRICYCLE },
  'tricycle/tadpole': { draw: recumbent({ bsd: 507 }), defaults: { wheelbase: 1380, seat_height: 420, seat_angle: 55, bb_height: 480, crank_length: 165, track_width: 820 } },
  stroller: { draw: stroller, defaults: { wheelbase: 620, handlebar_height: 1040, 'dimensions.height': 1080, 'dimensions_folded.length': 700, 'dimensions_folded.height': 340 } },
  recumbent: { draw: recumbent({ bsd: 406 }), defaults: { wheelbase: 1060, seat_height: 300, seat_angle: 42, bb_height: 400, crank_length: 155, track_width: 780 } },
  bike_trailer: { draw: bikeTrailer, defaults: { 'dimensions.length': 1450, 'dimensions.height': 900, 'dimensions.width': 800 } },
  wheelchair: { draw: wheelchair, defaults: { seat_height: 490, seat_depth: 430, backrest_height: 420, seat_width: 420, 'dimensions.width': 640 } },
  cargo_bike: { draw: longJohn, defaults: { bb_height: 290, chainstay: 450, wheelbase: 1800, head_angle: 70, head_tube: 100, seat_angle: 70, top_tube_effective: 600 } },
  tall_bike: { draw: tallBike, defaults: { ...BIKE, frame_offset: 560 }, framed: true },
  penny_farthing: { draw: pennyFarthing, defaults: { wheelbase: 980, seat_height: 1450, crank_length: 130 } },
  cargo_bike_rear: { draw: longtail, defaults: { ...BIKE, chainstay: 640 }, framed: true },
  cargo_tricycle: { draw: tricycle({ paired: 'front' }), defaults: { ...TRICYCLE, wheelbase: 1750, box_length: 900, box_height: 550, box_width: 800, track_width: 780 } },
  cargo_tricycle_rear: { draw: tricycle({ paired: 'rear' }), defaults: { ...TRICYCLE, box_length: 900, box_height: 400, box_width: 700, track_width: 760 } },
  trail_behind: { draw: trailBehind, defaults: { seat_height: 760, standover: 560, hitch_height: 900, tow_arm_length: 900 } },
  pedi_cab: { draw: pediCab, defaults: { wheelbase: 2000, seat_height: 1000, bench_height: 700, 'dimensions.height': 1950 } },
  e_scooter: { draw: scooter({ kick: false }), defaults: SCOOTER },
  epamd: { draw: personalMobility, defaults: { 'dimensions.height': 740, 'dimensions.width': 200, pedal_height: 220 } },
  scooter: { draw: scooter({ kick: true }), defaults: { ...SCOOTER, wheelbase: 620, deck_height: 90, deck_width: 120, handlebar_height: 860, handlebar_width: 400 } },
  skateboard: { draw: skateboard, defaults: { 'dimensions.length': 820, 'dimensions.width': 210, wheelbase: 450, deck_height: 110 } },
  e_motorcycle: { draw: eMotorcycle, defaults: { wheelbase: 1300, head_angle: 64, handlebar_height: 1150, seat_height: 880, seat_length: 650, ground_clearance: 300 } },
  elliptical_bike: { draw: ellipticalBike, defaults: { wheelbase: 1350, operating_height: 1400, platform_height: 200, stride_length: 500, stride_height: 150 } },
  balance_bike: { draw: balanceBike, defaults: { wheelbase: 560, head_angle: 70, head_tube: 90, standover: 300, seat_height_min: 290, seat_height_max: 420, handlebar_height_min: 460, handlebar_height_max: 540 } }
}

// The type_details `type` is drawn its own way for, the only list of them
export const typeDetails = (type) => Object.keys(CYCLE_DRAWINGS).filter((key) => key.startsWith(`${type}/`)).map((key) => key.split('/')[1])

// A size's figure, `key` as dimensions.length for one inside a hash, null where it lists none
export const listedFigure = (size, key) => {
  const geometry = size?.geometry ?? {}
  const [name, field] = key.split('.')
  const value = field ? geometry[name]?.[field] : geometry[name] ?? geometry.extra_measurements?.[name]
  return isNumber(value) ? value : null
}

// `size` with each of `figures`, keyed as listedFigure takes them
export const withFigures = (size, figures) => ({
  ...size,
  geometry: Object.entries(figures).reduce((geometry, [key, value]) => {
    const [name, field] = key.split('.')
    return field ? { ...geometry, [name]: { ...geometry[name], [field]: value } } : { ...geometry, [name]: value }
  }, size?.geometry ?? {})
})

// The views `type`, or its `typeDetail`, draws `data` in `size`, `framed` where they're drawn on bikeFrame's frame, and
// the figures it draws at their `typical`, with 'wheels' where it lists no wheel or tire to draw
export const drawingViews = ({ type, data, typeDetail, size }) => {
  const { draw, defaults, framed = false } = CYCLE_DRAWINGS[`${type}/${typeDetail}`] ?? CYCLE_DRAWINGS[type] ?? CYCLE_DRAWINGS.bike
  const typical = new Set()
  const assume = (key, value) => {
    typical.add(key)
    return value
  }
  const listed = (key) => listedFigure(size, key) !== null
  const fig = (key) => listedFigure(size, key) ?? assume(key, defaults[key])
  // its outside radius at the first of `positions` it lists a wheel at, else `fallback`'s
  const wheelAt = (positions, fallback) => {
    const built = positions.map((position) => builtWheel(data, size, position)).find((each) => isNumber(each?.bsd))
    const figure = tireFigure(size, positions[0])
    const tire = figure ?? built?.tire_width ?? assume('wheels', built?.max_tire_width ?? fallback.tire)
    return { r: (built?.bsd ?? assume('wheels', fallback.bsd)) / 2 + tire, tire, listed: Boolean(built), tireListed: isNumber(figure) || isNumber(built?.tire_width) }
  }
  // the first of `keys` it lists, else the first's typical
  const either = (...keys) => fig(keys.find(listed) ?? keys[0])
  const views = draw({ fig, either, listed, wheel: wheelAt, data, size, defaults, assume })
  return { views: views.map((view) => ({ ...view, shapes: [view.shapes].flat(Infinity).filter(Boolean) })), listed, framed, typical: [...typical] }
}
