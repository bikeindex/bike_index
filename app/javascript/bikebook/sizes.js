import { array } from 'bikebook/templates/values'

const KEY = 'bikebook:sizes'

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
  : sizes.find((size) => size.name === name) ?? sizes.find((size) => canonical(size.name) === canonical(name)) ?? null
const medium = (sizes) => matching(sizes, 'M') ?? sizes[Math.floor((sizes.length - 1) / 2)] ?? null

// { preferred: the first vehicle's size name, picked: each other vehicle's own pick, by id }
export const storedSizes = () => {
  try {
    return JSON.parse(window.localStorage.getItem(KEY)) ?? {}
  } catch {
    return {}
  }
}

export const storeSize = ({ id, name, first }) => {
  const stored = storedSizes()
  const sizes = first ? { ...stored, preferred: name } : { ...stored, picked: { ...stored.picked, [id]: name } }
  window.localStorage.setItem(KEY, JSON.stringify(sizes))
}

// Each vehicle's size: the first in the preferred size, the others in their own pick or else the
// first's, each as near as its sizes have and medium where they have nothing near
export const chosenSizes = (vehicles, { preferred, picked = {} } = {}) => {
  const [first, ...others] = vehicles.map(({ data }) => array(data.sizes))
  const firstSize = first && (matching(first, preferred) ?? medium(first))
  return [firstSize, ...others.map((sizes, index) =>
    matching(sizes, picked[vehicles[index + 1].value]) ?? matching(sizes, firstSize?.name) ?? matching(sizes, preferred) ?? medium(sizes))]
}
