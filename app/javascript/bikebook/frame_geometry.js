import { array, isNumber } from 'bikebook/templates/values'
import { TYPICAL_GEOMETRY } from 'bikebook/typical_geometry'

// figures that size the front triangle, without any of which a frame would be all estimate
const SIZING = ['reach', 'stack', 'top_tube_effective', 'front_center', 'head_tube']

const radians = (degrees) => degrees * Math.PI / 180
const cot = (angle) => 1 / Math.tan(angle)
// a right triangle's other side, 0 where the figures it's from don't make one
const leg = (hypotenuse, side) => Math.sqrt(Math.max(hypotenuse ** 2 - side ** 2, 0))

export const builtWheel = (data, size, position) => array(data.wheels).find((each) => each.configured !== false &&
  array(each.position).includes(position) && (!each.sizes || array(each.sizes).includes(size?.name)))

export const OVERALL_LENGTH_ESTIMATE = 'the wheelbase plus each wheel’s radius, estimating its tire based on its width'

// A wheel's outside radius where it lists its bead seat and tire, estimating the tire as tall as it's wide
export const outerRadius = (wheel) => isNumber(wheel?.bsd) && isNumber(wheel?.tire_width) ? wheel.bsd / 2 + wheel.tire_width : null

// A wheel's outside radius at `position` in `size`, from its wheel entry, else its wheel and tire components, the tire's
// width else the widest it takes
const wheelRadius = (data, size, position) => {
  const wheel = builtWheel(data, size, position)
  const part = (type) => array(data.components).find((each) => each.type === type && (!each.position || array(each.position).includes(position)))?.dimensions
  const tire = part('tire')
  return outerRadius({ bsd: wheel?.bsd ?? part('wheel')?.diameter ?? tire?.diameter, tire_width: wheel?.tire_width ?? tire?.width ?? wheel?.max_tire_width })
}

// A size's frame in mm, the bottom bracket at the origin and y up, from the figures it lists and those they work out.
// `missing` names the ones it can't draw without: where it lists none that size the front triangle, those, and otherwise
// the figures neither listed nor worked out. `wheels` is its wheels' outer radii and wheelbase where it lists them all,
// `calculated` names each figure it draws that it doesn't list, `assumed` those of them TYPICAL_GEOMETRY stands in for
// as a typical `typicalKind`'s, and `typicalWheel` the wheel it's drawn with where that's its kind's
export const frameGeometry = (data, size) => {
  const geometry = size?.geometry ?? {}
  const listed = (key) => isNumber(geometry[key])
  const known = (...values) => values.every(isNumber)
  const [rearRadius, frontRadius] = ['rear', 'front'].map((position) => outerRadius(builtWheel(data, size, position)))
  const wheels = known(rearRadius, frontRadius, geometry.wheelbase) ? { rearRadius, frontRadius, wheelbase: geometry.wheelbase } : null
  if (!SIZING.some(listed)) return { missing: SIZING, wheels }

  const { wheelbase, top_tube_effective: topTube } = geometry
  const fork = array(data.components).find((each) => each.type === 'fork')
  const typical = TYPICAL_GEOMETRY[data.primary_activity] ?? {}
  const headAngle = listed('head_angle') ? radians(geometry.head_angle) : null
  const listedRake = geometry.fork_rake ?? fork?.dimensions?.offset
  // where it lists no wheels, the rear's height under the bottom bracket, and the front's from its trail and rake
  const [rearWheel, frontWheel] = ['rear', 'front'].map((position) => wheelRadius(data, size, position))
  const workedRear = rearWheel ?? (listed('bb_height') && listed('bb_drop') ? geometry.bb_height + geometry.bb_drop : null)
  const workedFront = frontWheel ?? (listed('trail') && known(listedRake, headAngle)
    ? (geometry.trail * Math.sin(headAngle) + listedRake) / Math.cos(headAngle)
    : null)
  const typicalWheel = (position) => {
    const wheel = builtWheel(data, size, position)
    return outerRadius({ bsd: wheel?.bsd ?? typical.rim, tire_width: wheel?.tire_width ?? wheel?.max_tire_width ?? typical.tire })
  }
  const rear = workedRear ?? typicalWheel('rear')
  const front = workedFront ?? typicalWheel('front')
  const drop = geometry.bb_drop ?? (listed('bb_height') && known(rear) ? rear - geometry.bb_height : null)
  const frontY = known(drop, front, rear) ? drop + front - rear : null
  const chainstayX = listed('chainstay') && known(drop) ? -leg(geometry.chainstay, drop) : null
  const listedFrontX = known(chainstayX) && listed('wheelbase')
    ? chainstayX + wheelbase
    : listed('front_center') && known(frontY) ? leg(geometry.front_center, frontY) : null
  // the head tube's top as far as its figures place it without the fork: the stack from the top tube where the effective
  // seat angle is listed, and the reach from them
  const forklessStack = geometry.stack ?? (listed('seat_angle') && listed('reach') && topTube > geometry.reach
    ? (topTube - geometry.reach) * Math.tan(radians(geometry.seat_angle))
    : null)
  const topTubeReach = (stack) => listed('top_tube_effective') && listed('seat_angle') && known(stack) ? topTube - stack * cot(radians(geometry.seat_angle)) : null
  const forklessReach = geometry.reach ?? topTubeReach(forklessStack)
  // the fork's offset as the size lists it, else as its fork does, else the one its trail makes with the front wheel,
  // else the one that puts the front axle where its wheelbase or front centre does - which data at odds with itself
  // can make no offset at all
  const axleRake = known(listedFrontX, forklessStack, forklessReach, headAngle, frontY)
    ? (listedFrontX - (forklessStack - frontY) * cot(headAngle) - forklessReach) * Math.sin(headAngle)
    : null
  const workedRake = listedRake ??
    (listed('trail') && known(front, headAngle) ? front * Math.cos(headAngle) - geometry.trail * Math.sin(headAngle) : null) ??
    (axleRake > 0 ? axleRake : null)
  const rake = workedRake ?? typical.fork_rake ?? null
  const listedForkLength = geometry.fork_length_a2c ?? fork?.dimensions?.length
  const axleToCrown = listedForkLength ?? (isNumber(typical.crown) && known(front) ? front + typical.crown : null)
  // up the steering axis from the front axle's foot on it to the fork's crown
  const forkLength = known(axleToCrown, rake) ? leg(axleToCrown, rake) : null
  const assumedHeadTube = listed('head_tube') ? null : typical.head_tube ?? null
  // else up the fork and head tube from the front axle
  const stackFromFork = !isNumber(forklessStack)
  const stack = forklessStack ??
    (known(frontY, rake, headAngle, forkLength, geometry.head_tube ?? assumedHeadTube)
      ? frontY - rake * Math.cos(headAngle) + (forkLength + (geometry.head_tube ?? assumedHeadTube)) * Math.sin(headAngle)
      : null)
  // else back from the front axle along the fork and steering axis
  const reach = forklessReach ?? topTubeReach(stack) ??
    (known(listedFrontX, stack, frontY, headAngle, rake) ? listedFrontX - (stack - frontY) * cot(headAngle) - rake / Math.sin(headAngle) : null)
  const actualSeatAngle = geometry.extra_measurements?.seat_tube_angle_actual_degrees
  // the effective seat angle, else the one the effective top tube makes reaching back from the head tube
  const seatAngle = geometry.seat_angle ?? (known(stack, reach) && topTube > reach ? Math.atan2(stack, topTube - reach) * 180 / Math.PI : null) ?? actualSeatAngle
  const headed = known(reach, stack, headAngle, rake, frontY)
  // `distance` down the steering axis from the head tube's top, then `forward` square to it
  const steering = (distance, forward = 0) => [reach + distance * Math.cos(headAngle) + forward * Math.sin(headAngle),
    stack - distance * Math.sin(headAngle) + forward * Math.cos(headAngle)]
  // down the steering axis to the axle's height, then forward by the rake
  const frontX = listedFrontX ?? (headed ? steering((stack + rake * Math.cos(headAngle) - frontY) / Math.sin(headAngle), rake)[0] : null)
  const rearX = chainstayX ?? (listed('wheelbase') && known(frontX) ? frontX - wheelbase : null)
  // the front axle's foot on the steering axis, less the fork's length up the axis from it
  const headTube = geometry.head_tube ?? (headed && known(forkLength)
    ? Math.max((frontX - reach) * Math.cos(headAngle) - (frontY - stack) * Math.sin(headAngle) - forkLength, 0)
    : null)
  const resolved = {
    wheel_size: known(rear, front),
    bb_drop: known(drop),
    head_angle: known(headAngle),
    fork_rake: known(rake),
    stack: known(stack),
    reach: known(reach),
    head_tube: known(headTube),
    chainstay: known(rearX),
    seat_angle: known(seatAngle)
  }
  const missing = Object.keys(resolved).filter((key) => !resolved[key])
  if (missing.length) return { missing, wheels }

  const headBottom = steering(headTube)
  const seat = radians(seatAngle)
  const listedSeatTube = geometry.seat_tube_ct ?? geometry.seat_tube_ctc
  const seatTube = listedSeatTube ?? stack / Math.sin(seat)
  const seatTop = [-seatTube * Math.cos(seat), seatTube * Math.sin(seat)]
  // a seat tube slacker than the effective angle runs ahead of the bottom bracket, so it ends on the down tube
  const slope = cot(radians(actualSeatAngle))
  const seatBottom = actualSeatAngle < seatAngle && headBottom[1] > 0
    ? headBottom.map((each) => each * (seatTop[0] + seatTop[1] * slope) / (headBottom[0] + headBottom[1] * slope))
    : [0, 0]
  const given = { seat_tube_ct: isNumber(listedSeatTube), fork_rake: isNumber(listedRake), wheel_size: known(rearWheel, frontWheel) }
  // the fork's length goes into the stack it works out, else the head tube
  const assumed = [
    ['fork_rake', !isNumber(workedRake)],
    ['fork_length_a2c', !isNumber(listedForkLength) && (stackFromFork || !listed('head_tube'))],
    ['head_tube', isNumber(assumedHeadTube) && stackFromFork]
  ].filter(([, taken]) => taken).map(([key]) => key)
  const rearRim = builtWheel(data, size, 'rear')?.bsd

  return {
    missing: [],
    wheels,
    calculated: ['reach', 'stack', 'head_tube', 'chainstay', 'bb_drop', 'seat_angle', 'seat_tube_ct', 'fork_rake', 'wheel_size']
      .filter((key) => !(given[key] ?? listed(key)) && !assumed.includes(key) && (key !== 'wheel_size' || known(workedRear, workedFront))),
    assumed,
    typicalKind: typical.kind,
    // the rear's rim and tire, and whether it lists the rim
    typicalWheel: known(workedRear, workedFront) ? null : { bsd: rearRim ?? typical.rim, tire: typical.tire, rimListed: isNumber(rearRim) },
    rearAxle: [rearX, drop],
    frontAxle: [frontX, frontY],
    rearRadius: rear,
    bottomBracketHeight: rear - drop,
    frontRadius: front,
    headTop: [reach, stack],
    headBottom,
    seatTop,
    seatBottom
  }
}
