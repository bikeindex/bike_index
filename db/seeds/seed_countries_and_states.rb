# Country and ISO
StatesAndCountries.countries.each do |c|
  country = Country.create(name: c[:name], iso: c[:iso])
  country.save
end

# US States and territories
us_id = Country.find_by_iso("US").id
StatesAndCountries.states.each do |s|
  state = State.create(country_id: us_id, name: s[:name], abbreviation: s[:abbr])
  state.save
end
