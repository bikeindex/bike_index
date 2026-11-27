import { array, present } from 'bikebook/templates/values'

// A vehicle's years that list colorways, newest first
export const colorwayYears = (data) => array(data.years).filter((year) => present(year.colorways))

// What vehicle_models' {color:} names a colorway by, one of an earlier `year` with that year in front
export const colorwayValue = (colorway, index, year) => {
  const name = colorway.name ?? String(index)
  return year ? `${year} ${name}` : name
}

// Each of its colorways with its value, newest first
const entries = (data) => colorwayYears(data).flatMap(({ year, colorways }, yearIndex) =>
  colorways.map((colorway, index) => ({ colorway, value: colorwayValue(colorway, index, yearIndex > 0 && year) })))

// Of its colorways, the `picked` one, else the one its stock photo shows, else its newest year's first
export const chosenColorway = (data, picked) => {
  const all = entries(data)
  return all.find(({ value }) => value === picked) ??
    all.find(({ colorway }) => present(colorway.stock_photo) && colorway.stock_photo === data.stock_photo) ?? all[0]
}

// `data` showing its chosen colorway's photo, where it has one
export const withColorwayPhoto = (data, picked) => {
  const photo = chosenColorway(data, picked)?.colorway.stock_photo
  return present(photo) ? { ...data, stock_photo: photo } : data
}

// Newest first, every year it was sold rather than only those the catalog has a record of: through its final year, or
// for a current model its newest record
export const soldYears = ({ first_year: first, final_year: final, years }) => {
  const last = final ?? Math.max(first, ...array(years).map(({ year }) => year))
  return first ? Array.from({ length: last - first + 1 }, (_, index) => last - index) : []
}

// Whether the catalog has `year` of it: its record of that year, or with no years recorded, a year it was sold
export const knownYear = (data, year) => {
  const records = array(data.years)
  return records.length ? records.some((each) => each.year === year) : soldYears(data).includes(year)
}

// Its photo for `year`, nothing for a year the catalog doesn't know: of that year's colorways, the one its stock photo
// shows, else the first with one, else its stock photo. With no year, or no years recorded, its stock photo
export const yearPhoto = (data, year) => {
  if (!year) return data.stock_photo
  if (!knownYear(data, year)) return null
  const record = array(data.years).find((each) => each.year === year)
  const photos = array(record?.colorways).map(({ stock_photo: photo }) => photo).filter(present)
  return photos.length && !photos.includes(data.stock_photo) ? photos[0] : data.stock_photo
}
