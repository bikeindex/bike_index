import { array, isNumber } from 'bikebook/templates/values'

const REQUIRED = ['reach', 'stack', 'head_angle', 'chainstay']
const BSD = 622
const TIRE_WIDTH = 35
const FORK_RAKE = 45
const SEAT_ANGLE = 73.5

const radians = (degrees) => degrees * Math.PI / 180

// A wheel's outside radius at `position` in `size`, estimated as a 700c × 35 where it lists no bead seat or tire
const wheelRadius = (data, size, position) => {
  const wheel = array(data.wheels).find((each) => each.configured !== false && array(each.position).includes(position) &&
    (!each.sizes || array(each.sizes).includes(size?.name)))
  const [bsd, tire] = [wheel?.bsd, wheel?.tire_width ?? wheel?.max_tire_width]
  return { radius: (isNumber(bsd) ? bsd : BSD) / 2 + (isNumber(tire) ? tire : TIRE_WIDTH), estimated: !isNumber(bsd) || !isNumber(tire) }
}

// A size's frame in mm, the bottom bracket at the origin and y up. `missing` names the geometry it can't be drawn
// without, and `estimated` is whether a default stands in for any value the size doesn't list
export const frameGeometry = (data, size) => {
  const geometry = size?.geometry ?? {}
  const rear = wheelRadius(data, size, 'rear')
  const front = wheelRadius(data, size, 'front')
  const drop = geometry.bb_drop ?? (isNumber(geometry.bb_height) ? rear.radius - geometry.bb_height : null)
  const missing = [...REQUIRED.filter((key) => !isNumber(geometry[key])), ...(isNumber(drop) ? [] : ['bb_drop'])]
  if (missing.length) return { missing }

  const { reach, stack, chainstay, wheelbase, front_center: frontCenter, head_tube: headTube = 0, top_tube_effective: topTube } = geometry
  const headAngle = radians(geometry.head_angle)
  const rearAxle = [-Math.sqrt(chainstay ** 2 - drop ** 2), drop]
  const frontY = drop + front.radius - rear.radius
  const rake = geometry.fork_rake ?? FORK_RAKE
  // down the steering axis to the axle's height, then forward by the rake
  const along = (stack + rake * Math.cos(headAngle) - frontY) / Math.sin(headAngle)
  const frontX = isNumber(wheelbase)
    ? rearAxle[0] + wheelbase
    : isNumber(frontCenter) ? Math.sqrt(frontCenter ** 2 - frontY ** 2) : reach + along * Math.cos(headAngle) + rake * Math.sin(headAngle)

  // the effective seat angle, else the one the effective top tube makes reaching back from the head tube
  const seatAngle = geometry.seat_angle ?? (isNumber(topTube) && topTube > reach ? Math.atan2(stack, topTube - reach) * 180 / Math.PI : null) ??
    geometry.extra_measurements?.seat_tube_angle_actual_degrees
  const seat = radians(seatAngle ?? SEAT_ANGLE)
  const listedSeatTube = geometry.seat_tube_ct ?? geometry.seat_tube_ctc
  const seatTube = listedSeatTube ?? stack / Math.sin(seat)

  return {
    missing,
    estimated: rear.estimated || front.estimated || !isNumber(geometry.head_tube) || !isNumber(seatAngle) || !isNumber(listedSeatTube) ||
      (!isNumber(wheelbase) && !isNumber(frontCenter) && !isNumber(geometry.fork_rake)),
    rearAxle,
    frontAxle: [frontX, frontY],
    rearRadius: rear.radius,
    bottomBracketHeight: rear.radius - drop,
    frontRadius: front.radius,
    headTop: [reach, stack],
    headBottom: [reach + headTube * Math.cos(headAngle), stack - headTube * Math.sin(headAngle)],
    seatTop: [-seatTube * Math.cos(seat), seatTube * Math.sin(seat)]
  }
}
