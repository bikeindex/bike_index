import { array } from 'bikebook/templates/values'
import { queryUrl } from 'bikebook/replace_url'

const KEY = 'bikebook:sizes'
const PARAM = 'vehicle_sizes'

// Size names that say the same thing, by their letters and digits alone: "Medium", "M", "MD". No "SM",
// which is how "S/M" reads
const ALIASES = {
  extrasmall: 'xs',
  xsmall: 'xs',
  small: 's',
  medium: 'm',
  med: 'm',
  md: 'm',
  large: 'l',
  lg: 'l',
  extralarge: 'xl',
  xlarge: 'xl',
  xxlarge: 'xxl'
}
const canonical = (name) => {
  const key = String(name).toLowerCase().replace(/[^a-z0-9]/g, '')
  return ALIASES[key] ?? key
}

const matching = (sizes, name) => name == null
  ? null
  : sizes.find((size) => size.name === name) ?? sizes.find((size) => canonical(size.name) === canonical(name))
const medium = (sizes) => matching(sizes, 'M') ?? sizes[Math.floor((sizes.length - 1) / 2)]

const gap = (a, b) => typeof a === 'number' && typeof b === 'number' ? Math.abs(a - b) : Infinity
// The size whose effective top tube is nearest `target`'s, reach breaking a tie
const nearest = (sizes, target) => {
  const distance = (size) => ['top_tube_effective', 'reach'].map((key) => gap(size.geometry?.[key], target?.geometry?.[key]))
  const closer = (size, best) => {
    const [[topTube, reach], [bestTopTube, bestReach]] = [distance(size), distance(best)]
    return topTube < bestTopTube || (topTube === bestTopTube && reach < bestReach)
  }
  return sizes.filter((size) => distance(size)[0] < Infinity).reduce((best, size) => best && !closer(size, best) ? best : size, null)
}

// The first vehicle's last picked size, { name, geometry }, which a first vehicle with none picked takes the nearest of
export const preferredSize = () => {
  try {
    return JSON.parse(window.localStorage.getItem(KEY))
  } catch {
    return null
  }
}

export const storePreferredSize = (size) => window.localStorage.setItem(KEY, JSON.stringify(size))

// vehicle_sizes is each vehicle's picked size in vehicle_models' order, blank where it has none
const paramList = (url, param) => url.searchParams.get(param)?.split(',') ?? []
export const pickedSizes = (url) => {
  const sizes = paramList(url, PARAM)
  return Object.fromEntries(paramList(url, 'vehicle_models').map((id, index) => [id, sizes[index]]).filter(([, size]) => size))
}
export const sizesParam = (ids, picked) => {
  const sizes = ids.map((id) => picked[id] ?? '')
  return sizes.slice(0, sizes.findLastIndex(Boolean) + 1).join(',')
}
const withPicked = (url, picked) => {
  const next = new URL(url)
  const value = sizesParam(paramList(next, 'vehicle_models'), picked)
  value ? next.searchParams.set(PARAM, value) : next.searchParams.delete(PARAM)
  return next
}
export const withSize = (url, id, name) => withPicked(url, { ...pickedSizes(url), [id]: name })
// `url` with each size following its vehicle from `previous`, whose vehicles it's reordered, added to or removed from
export const realigned = (url, previous = queryUrl()) => withPicked(url, pickedSizes(previous))

// Each vehicle's size: its pick, else the first's preferred size and the others' the first's, each the nearest
// by top tube, else by name, else medium
export const chosenSizes = (vehicles, { picked = {}, preferred } = {}) => {
  const choose = ({ value, data }, target) => {
    const sizes = array(data.sizes)
    return matching(sizes, picked[value]) ?? nearest(sizes, target) ?? matching(sizes, target?.name) ?? medium(sizes)
  }
  const [first, ...others] = vehicles
  const firstSize = first && choose(first, preferred)
  return [firstSize, ...others.map((vehicle) => choose(vehicle, firstSize ?? preferred))]
}
