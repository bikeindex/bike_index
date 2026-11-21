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
