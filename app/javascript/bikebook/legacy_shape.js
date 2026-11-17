import { array, except, isNumber, presence } from 'bikebook/templates/values'

// TODO: once every model the catalog publishes is at its 1.0.0 schema, read that shape alone and delete this module

// A catalog before 0.28.0's name for each key 0.28.0 renamed
const RENAMED = {
  rider_height_min: 'min_rider_height',
  rider_height_max: 'max_rider_height',
  rider_age_min: 'min_rider_age',
  rider_age_max: 'max_rider_age',
  saddle_setback_min: 'min_saddle_setback',
  saddle_setback_max: 'max_saddle_setback',
  tire_width_max: 'max_tire_width',
  rotor_diameter_max: 'max_rotor_diameter'
}
const FRAME_LIMITS = { max_weight_total: 'payload', gross_weight_rating: 'gross' }
const SIZE_LIMITS = {
  max_weight_rider: 'rider',
  weight_rating_luggage_rack_kg: 'rear_rack',
  rear_rack_capacity_kg: 'rear_rack',
  weight_rating_handlebar_bag_basket_kg: 'handlebar_basket',
  weight_rating_front_carrier_kg: 'front_rack',
  weight_rating_cargo_front_carrier_kg: 'front_rack',
  weight_rating_pannier_rack_per_side_kg: 'pannier_per_side'
}
const MIK_HD = 'MIK HD interface'
const MOTOR_KEYS = ['certification', 'battery_size', 'battery_options', 'battery_chemistry', 'battery_info', 'charging_time']
const BATTERY_WORDS = /\d+(\.\d+)?\s?(v|ah)\b|\b(lithium[- ]ion|lithium|li-ion|cells?|battery)\b/gi

// `hash`'s `key`, or the name a catalog before 0.28.0 gives it
export const catalogValue = (hash, key) => hash?.[key] ?? hash?.[RENAMED[key]]

const compactHash = (hash) => Object.fromEntries(Object.entries(hash).filter(([, value]) => value != null))

// A model of any schema the catalog publishes, in 1.0.0's shape: its weight limits listed together, its motors'
// batteries and certifications their own, and a size's renamed figures under both names, so a kit of either finds them
export const currentShape = (data) => {
  const { frame = {}, cargo = {} } = data
  const mikHd = array(cargo.attributes).includes(MIK_HD)
  const limits = [...sizeLimits(data.sizes), ...Object.entries(FRAME_LIMITS).filter(([key]) => isNumber(frame[key])).map(([key, load]) => ({ load, weight: frame[key] })),
    ...(isNumber(cargo.max_weight_cargo) ? [{ load: mikHd ? 'rear_rack' : 'cargo', weight: cargo.max_weight_cargo }] : [])]
  return compactHash({
    ...except(data, ['vehicle_model_group']),
    model_group: data.model_group ?? data.vehicle_model_group,
    frame: data.frame && compactHash({ ...except(frame, Object.keys(FRAME_LIMITS)), mounts: mikHd ? rearMikHd(array(frame.mounts)) : frame.mounts }),
    cargo: data.cargo && presence(except(cargo, ['max_weight_cargo', 'attributes'])),
    weight_limits: data.weight_limits ?? presence(limits),
    sizes: data.sizes && array(data.sizes).map((size) => size.geometry ? { ...size, geometry: currentGeometry(size.geometry) } : size),
    motors: data.motors && array(data.motors).map(currentMotor)
  })
}

// each load a size rates: a weight every size shares is the model's, the rest name their sizes
const sizeLimits = (sizes) => {
  const flat = array(sizes).map(({ name, geometry = {} }) => [name, { ...geometry, ...geometry.extra_measurements }])
  return [...new Set(Object.values(SIZE_LIMITS))].flatMap((load) => {
    const keys = Object.keys(SIZE_LIMITS).filter((key) => SIZE_LIMITS[key] === load)
    const rated = flat.flatMap(([name, geometry]) => keys.filter((key) => isNumber(geometry[key])).slice(0, 1).map((key) => [name, geometry[key]]))
    const byWeight = [...new Set(rated.map(([, weight]) => weight))].map((weight) => [weight, rated.filter(([, each]) => each === weight).map(([name]) => name)])
    const common = rated.length && rated.length === flat.length ? byWeight.reduce((most, each) => each[1].length > most[1].length ? each : most)[0] : null
    return [...byWeight.filter(([weight]) => weight === common), ...byWeight.filter(([weight]) => weight !== common)]
      .map(([weight, names]) => weight === common ? { load, weight } : { load, weight, sizes: names })
  })
}

const currentGeometry = (geometry) => {
  const aliases = Object.entries(RENAMED).flatMap(([key, legacy]) => [[key, catalogValue(geometry, key)], [legacy, catalogValue(geometry, key)]])
  const extras = geometry.extra_measurements && presence(except(geometry.extra_measurements, Object.keys(SIZE_LIMITS)))
  return compactHash({ ...except(geometry, Object.keys(SIZE_LIMITS)), ...Object.fromEntries(aliases), extra_measurements: extras })
}

// Specialized's MIK HD is its rear rack's, so a rack naming no wheel is that one
const rearMikHd = (mounts) => {
  const rack = [(mount) => array(mount.position).includes('rear'), (mount) => array(mount.position).length === 0]
    .map((placed) => mounts.findIndex((mount) => mount.type === 'rack' && placed(mount))).find((index) => index >= 0)
  return rack === undefined
    ? [...mounts, { type: 'rack', position: ['rear'], interface: 'mik_hd' }]
    : mounts.map((mount, index) => index === rack ? { ...mount, position: ['rear'], interface: mount.interface ?? 'mik_hd' } : mount)
}

// "36V, 20Ah, LG 21700 cells", or an option's "750 Wh: +£300"
const currentMotor = (motor) => {
  if (!MOTOR_KEYS.some((key) => key in motor)) return motor

  const info = String(motor.battery_info ?? '')
  const option = Number(info.match(/^(\d+)\s?Wh:/i)?.[1]) || null
  const volts = option ? [] : [...info.matchAll(/(\d+(?:\.\d+)?)\s?V\b/gi)].map(([, each]) => Number(each))
  const cells = option ? null : info.split(/[,;]/).map((part) => part.replace(BATTERY_WORDS, '').trim()).filter((part) => /[a-z0-9]{2}/i.test(part)).join(', ')
  const battery = compactHash({
    ...motor.battery,
    capacity: motor.battery_size,
    capacity_options: presence([...array(motor.battery_options), ...(option ? [option] : [])]),
    voltage: volts.length ? Math.min(...volts) : null,
    chemistry: motor.battery_chemistry,
    cells: presence(cells),
    charging_time: motor.charging_time
  })
  const certifications = motor.certifications ?? String(motor.certification ?? '').split(/,\s*/).filter(Boolean)
  return compactHash({ ...except(motor, MOTOR_KEYS), certifications: presence(certifications), battery: presence(battery) })
}
