import { array, present } from 'bikebook/templates/values'

// A vehicle's years that list colorways, newest first
export const colorwayYears = (data) => array(data.years).filter((year) => present(year.colorways))

// What vehicle_colorways names a colorway by
export const colorwayValue = (colorway, index) => colorway.name ?? String(index)

// Of its newest colorways, the `picked` one, else the one its stock photo shows, else the first
export const chosenColorway = (data, picked) => {
  const latest = array(colorwayYears(data)[0]?.colorways)
  return latest.find((each, index) => colorwayValue(each, index) === picked) ??
    latest.find((each) => present(each.stock_photo) && each.stock_photo === data.stock_photo) ?? latest[0]
}

// `data` showing its chosen colorway's photo, where it has one
export const withColorwayPhoto = (data, picked) => {
  const photo = chosenColorway(data, picked)?.stock_photo
  return present(photo) ? { ...data, stock_photo: photo } : data
}
