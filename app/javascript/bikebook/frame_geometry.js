import { array, isNumber } from 'bikebook/templates/values'

// figures that size the front triangle, without any of which a frame would be all estimate
const SIZING = ['reach', 'stack', 'top_tube_effective', 'front_center', 'head_tube']
// the catalog's medians, for figures a size neither lists nor has the figures to work out
const DEFAULTS = { bb_drop: 65, head_angle: 70, chainstay: 430, fork_rake: 45, seat_angle: 74, reach: 405, head_tube: 130 }
const BSD = 622
const TIRE_WIDTH = 35
// mm a fork's crown sits above its tire, besides its travel
const CROWN_CLEARANCE = 40

const radians = (degrees) => degrees * Math.PI / 180
const cot = (angle) => 1 / Math.tan(angle)
// a right triangle's other side, 0 where the figures it's from don't make one
const leg = (hypotenuse, side) => Math.sqrt(Math.max(hypotenuse ** 2 - side ** 2, 0))

export const builtWheel = (data, size, position) => array(data.wheels).find((each) => each.configured !== false &&
  array(each.position).includes(position) && (!each.sizes || array(each.sizes).includes(size?.name)))

// A wheel's outside radius where it lists its bead seat and tire, estimating the tire as tall as it's wide
export const outerRadius = (wheel) => isNumber(wheel?.bsd) && isNumber(wheel?.tire_width) ? wheel.bsd / 2 + wheel.tire_width : null

// A wheel's outside radius at `position` in `size`, estimated as a 700c × 35 where it lists no bead seat or tire
const wheelRadius = (data, size, position) => {
  const wheel = builtWheel(data, size, position)
  const [bsd, tire] = [wheel?.bsd, wheel?.tire_width ?? wheel?.max_tire_width]
  return { radius: (isNumber(bsd) ? bsd : BSD) / 2 + (isNumber(tire) ? tire : TIRE_WIDTH), estimated: !isNumber(bsd) || !isNumber(tire) }
}

// The fork's offset as the size lists it, else as its fork does, else the one its trail makes with the front wheel
const forkRake = (fork, geometry, frontRadius, headAngle) => geometry.fork_rake ?? fork?.dimensions?.offset ??
  (isNumber(geometry.trail) ? frontRadius * Math.cos(headAngle) - geometry.trail * Math.sin(headAngle) : null)

// A size's frame in mm, the bottom bracket at the origin and y up, drawn from any of its figures that size the front
// triangle. `missing` names those where it lists none, and `wheels` its wheels' outer radii and wheelbase where it lists
// them all. `estimated` names each figure it doesn't list, which is worked out from those it does or else a default
export const frameGeometry = (data, size) => {
  const geometry = size?.geometry ?? {}
  const listed = (key) => isNumber(geometry[key])
  const rear = wheelRadius(data, size, 'rear')
  const front = wheelRadius(data, size, 'front')
  const [rearRadius, frontRadius] = ['rear', 'front'].map((position) => outerRadius(builtWheel(data, size, position)))
  const wheels = [rearRadius, frontRadius, geometry.wheelbase].every(isNumber) ? { rearRadius, frontRadius, wheelbase: geometry.wheelbase } : null
  if (!SIZING.some(listed)) return { missing: SIZING, wheels }

  const { wheelbase, top_tube_effective: topTube } = geometry
  const fork = array(data.components).find((each) => each.type === 'fork')
  const drop = geometry.bb_drop ?? (listed('bb_height') ? rear.radius - geometry.bb_height : DEFAULTS.bb_drop)
  const headAngle = radians(geometry.head_angle ?? DEFAULTS.head_angle)
  const frontY = drop + front.radius - rear.radius
  const listedRake = forkRake(fork, geometry, front.radius, headAngle)
  const rake = listedRake ?? DEFAULTS.fork_rake
  const travel = geometry.travel_front ?? data.suspension?.front_travel ?? fork?.dimensions?.travel ?? 0
  // up the steering axis from the front axle's foot on it to the fork's crown
  const forkLength = leg(geometry.fork_length_a2c ?? front.radius + CROWN_CLEARANCE + travel, rake)
  // from the top tube where the effective seat angle is listed, else up the fork and head tube from the front axle
  const stack = geometry.stack ??
    (listed('seat_angle') && listed('reach') && topTube > geometry.reach ? (topTube - geometry.reach) * Math.tan(radians(geometry.seat_angle)) : null) ??
    frontY - rake * Math.cos(headAngle) + (forkLength + (geometry.head_tube ?? DEFAULTS.head_tube)) * Math.sin(headAngle)
  const chainstayX = listed('chainstay') ? -leg(geometry.chainstay, drop) : null
  const listedFrontX = isNumber(chainstayX) && listed('wheelbase')
    ? chainstayX + wheelbase
    : listed('front_center') ? leg(geometry.front_center, frontY) : null
  // from the top tube, else back from the front axle along the fork and steering axis
  const reach = geometry.reach ?? (listed('top_tube_effective') ? topTube - stack * cot(radians(geometry.seat_angle ?? DEFAULTS.seat_angle)) : null) ??
    (isNumber(listedFrontX) ? listedFrontX - (stack - frontY) * cot(headAngle) - rake / Math.sin(headAngle) : DEFAULTS.reach)
  // `distance` down the steering axis from the head tube's top, then `forward` square to it
  const steering = (distance, forward = 0) => [reach + distance * Math.cos(headAngle) + forward * Math.sin(headAngle),
    stack - distance * Math.sin(headAngle) + forward * Math.cos(headAngle)]
  // down the steering axis to the axle's height, then forward by the rake
  const frontX = listedFrontX ?? steering((stack + rake * Math.cos(headAngle) - frontY) / Math.sin(headAngle), rake)[0]
  const rearX = chainstayX ?? (listed('wheelbase') ? frontX - wheelbase : -leg(DEFAULTS.chainstay, drop))
  // the front axle's foot on the steering axis, less the fork's length up the axis from it
  const foot = (frontX - reach) * Math.cos(headAngle) - (frontY - stack) * Math.sin(headAngle)
  const headTube = geometry.head_tube ?? Math.max(foot - forkLength, 0)
  const headBottom = steering(headTube)

  const actualSeatAngle = geometry.extra_measurements?.seat_tube_angle_actual_degrees
  // the effective seat angle, else the one the effective top tube makes reaching back from the head tube
  const seatAngle = geometry.seat_angle ?? (topTube > reach ? Math.atan2(stack, topTube - reach) * 180 / Math.PI : null) ?? actualSeatAngle
  const seat = radians(seatAngle ?? DEFAULTS.seat_angle)
  const listedSeatTube = geometry.seat_tube_ct ?? geometry.seat_tube_ctc
  const seatTube = listedSeatTube ?? stack / Math.sin(seat)
  const seatTop = [-seatTube * Math.cos(seat), seatTube * Math.sin(seat)]
  // a seat tube slacker than the effective angle runs ahead of the bottom bracket, so it ends on the down tube
  const slope = cot(radians(actualSeatAngle))
  const seatBottomY = actualSeatAngle < seatAngle && headBottom[1] > 0 ? (seatTop[0] + seatTop[1] * slope) / (headBottom[0] / headBottom[1] + slope) : 0

  return {
    missing: [],
    wheels,
    estimated: Object.entries({
      reach: !listed('reach'),
      stack: !listed('stack'),
      head_angle: !listed('head_angle'),
      head_tube: !listed('head_tube'),
      chainstay: !listed('chainstay'),
      bb_drop: !listed('bb_drop') && !listed('bb_height'),
      seat_angle: !listed('seat_angle'),
      seat_tube_ct: !isNumber(listedSeatTube),
      fork_rake: !isNumber(listedRake),
      wheel_size: rear.estimated || front.estimated
    }).filter(([, value]) => value).map(([key]) => key),
    rearAxle: [rearX, drop],
    frontAxle: [frontX, frontY],
    rearRadius: rear.radius,
    bottomBracketHeight: rear.radius - drop,
    frontRadius: front.radius,
    headTop: [reach, stack],
    headBottom,
    forkCrown: steering(headTube, rake),
    seatTop,
    seatBottom: [seatBottomY * headBottom[0] / headBottom[1], seatBottomY]
  }
}
