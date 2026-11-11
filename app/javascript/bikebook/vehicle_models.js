const PARAM = 'vehicle_models'
// a name's commas are inside its braces
const ENTRY = /(?:[^,{]|\{[^}]*\})+/g

// vehicle_models: each vehicle's id, then in braces what's picked for it, which no id or catalog name has a brace of:
// m/trek/2026/marlin_5{size:M/L}{color:Gloss Black}{json}{group}
export const vehicleEntries = (value) => (String(value ?? '').match(ENTRY) ?? []).map((entry) => ({
  ...Object.fromEntries([...entry.matchAll(/\{([^}]*)\}/g)].map(([, inside]) => {
    const at = inside.indexOf(':')
    return at < 0 ? [inside, true] : [inside.slice(0, at), inside.slice(at + 1)]
  })),
  id: entry.split('{')[0].trim()
})).filter(({ id }) => id)

export const vehicleModels = (entries) => entries.map(({ id, size, color, json, group }) =>
  [id, size && `{size:${size}}`, color && `{color:${color}}`, json && '{json}', group && '{group}'].filter(Boolean).join('')).join(',')

export const vehiclesOf = (url) => vehicleEntries(url.searchParams.get(PARAM))
export const vehicleIds = (url) => vehiclesOf(url).map(({ id }) => id)

export const withVehicles = (url, entries) => {
  const next = new URL(url)
  entries.length ? next.searchParams.set(PARAM, vehicleModels(entries)) : next.searchParams.delete(PARAM)
  return next
}

// Each of `ids` as itself, and a model picked again as its id and which time: m/trek/2026/marlin_5#2
export const vehicleKeys = (ids) => ids.map((id, index) => {
  const time = ids.slice(0, index).filter((each) => each === id).length + 1
  return time > 1 ? `${id}#${time}` : id
})

// [key, entry] of each vehicle
const keyed = (url) => {
  const entries = vehiclesOf(url)
  const keys = vehicleKeys(entries.map(({ id }) => id))
  return entries.map((entry, index) => [keys[index], entry])
}
const pickedOf = (url, name) => Object.fromEntries(keyed(url).filter(([, entry]) => entry[name]).map(([key, entry]) => [key, entry[name]]))
export const pickedSizes = (url) => pickedOf(url, 'size')
export const pickedColorways = (url) => pickedOf(url, 'color')
export const openJson = (url) => pickedOf(url, 'json')
export const groupId = (url) => vehiclesOf(url).find(({ group }) => group)?.id

const withPick = (url, key, name, value) => withVehicles(url, keyed(url).map(([each, entry]) => each === key ? { ...entry, [name]: value } : entry))
export const withSize = (url, key, name) => withPick(url, key, 'size', name)
export const withColorway = (url, key, name) => withPick(url, key, 'color', name)
export const withJson = (url, key, open) => withPick(url, key, 'json', open)
export const withoutVehicle = (url, key) => withVehicles(url, keyed(url).filter(([each]) => each !== key).map(([, entry]) => entry))
// the model group of the vehicle `id` shown, the only one, or none for a blank one
export const withGroup = (url, id) => withVehicles(url, vehiclesOf(url).map((entry) => ({ ...entry, group: entry.id === id })))

// `url`'s vehicles, which the vehicle combobox picks bare, each with what `previous` picked for it
export const realigned = (url, previous = new URL(window.location.href)) => {
  const picked = Object.fromEntries(keyed(previous))
  return withVehicles(url, keyed(url).map(([key, entry]) => ({ ...picked[key], ...entry })))
}

// `current`'s vehicles as `link` has them, each with only what `link` changes of it from `rendered`, the URL `link` was
// written at, as a vehicle's JSON opens without rendering
export const changedVehicles = (link, rendered, current) => {
  const [was, now] = [rendered, current].map((each) => Object.fromEntries(keyed(each)))
  return withVehicles(current, keyed(link).map(([key, entry]) => [...new Set([...Object.keys(entry), ...Object.keys(was[key] ?? {})])]
    .reduce((each, name) => entry[name] === was[key]?.[name] ? each : { ...each, [name]: entry[name] }, now[key] ?? entry)))
}
