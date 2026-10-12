import { html, nothing } from 'lit-html'

// Ruby's blank?, == and safe_join, over vehicle data and the templates rendered from it

const joins = new WeakMap()
const separators = new WeakMap()

export const isTemplate = (value) => value?._$litType$ !== undefined || value?._$litDirective$ !== undefined

export const isHash = (value) => value != null && typeof value === 'object' && !Array.isArray(value) && !isTemplate(value)

// counting false as blank, as Ruby does
export const blank = (value) => value == null || value === false || value === nothing ||
  (typeof value === 'string' && value.trim() === '') || (joins.has(value) && joins.get(value).every(blank)) ||
  (Array.isArray(value) && value.length === 0) || (isHash(value) && Object.keys(value).length === 0)
export const present = (value) => !blank(value)
export const presence = (value) => present(value) ? value : null
export const truthy = (value) => value != null && value !== false

// A template equals another from the same literal given equal values
export const equal = (a, b) => {
  if (a == null || b == null) return a == null && b == null
  if (isTemplate(a) || isTemplate(b)) {
    return isTemplate(a) && isTemplate(b) && a.strings === b.strings && a._$litDirective$ === b._$litDirective$ && equal(a.values, b.values)
  }
  if (Array.isArray(a)) return Array.isArray(b) && a.length === b.length && a.every((value, index) => equal(value, b[index]))
  if (isHash(a)) {
    if (!isHash(b)) return false
    const keys = Object.keys(a)
    return keys.length === Object.keys(b).length && keys.every((key) => key in b && equal(a[key], b[key]))
  }
  return a === b
}

// safe_join, as a template that remembers its parts
export const join = (parts, separator = '') => {
  const list = parts.flatMap((part, index) => index ? [separator, part] : [part])
  const result = html`${list}`
  joins.set(result, list)
  separators.set(result, separator)
  return result
}

// A list's parts, where a join separates them as ', ' or a <br> does, and its separator; null for a join that runs its
// parts together into one, as "30 mm" and " tire" do
export const listed = (value) => separators.get(value) ? [joins.get(value).filter((_, index) => index % 2 === 0), separators.get(value)] : null

// What a join puts side by side, through any joins inside it
export const partsOf = (value) => joins.has(value) ? joins.get(value).flatMap(partsOf) : [value]

export const compact = (values) => values.filter((value) => value != null)
// "Reach, Stack and BB Drop"
export const andSentence = (words) => words.length < 2 ? words.join('') : `${words.slice(0, -1).join(', ')} and ${words.at(-1)}`
export const isNumber = (value) => typeof value === 'number'
export const slice = (hash, keys) => Object.fromEntries(keys.filter((key) => key in (hash ?? {})).map((key) => [key, hash[key]]))
export const except = (hash, keys) => Object.fromEntries(Object.entries(hash).filter(([key]) => !keys.includes(key)))
export const array = (value) => value == null ? [] : [value].flat()

// Array#sum, which adds floats with Kahan-Babuska compensation
export const sum = (values) => {
  let total = 0
  let compensation = 0
  for (const value of values) {
    const next = total + value
    compensation += Math.abs(total) >= Math.abs(value) ? (total - next) + value : (value - next) + total
    total = next
  }
  return total + compensation
}
