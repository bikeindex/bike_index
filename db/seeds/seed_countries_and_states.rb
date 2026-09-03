# Country and ISO
StatesAndCountries.countries.each do |c|
  Country.create!(name: c[:name], iso: c[:iso])
end

# Pin the anchor country ids to the ids the Country model references
# (Country::UNITED_STATES_ID / CANADA_ID). Auto-increment order shifts as the
# country list grows, so swap each anchor onto its canonical id. Safe here
# because no country_id foreign keys exist yet (states/bikes seed afterward).
{"US" => Country::UNITED_STATES_ID, "CA" => Country::CANADA_ID}.each do |iso, target_id|
  next if target_id.nil?

  country = Country.find_by(iso:)
  next if country.nil? || country.id == target_id

  original_id = country.id
  occupant = Country.find_by(id: target_id)
  occupant&.update_column(:id, Country.maximum(:id) + 1)
  country.update_column(:id, target_id)
  occupant&.update_column(:id, original_id)
end

# US States and territories
us_id = Country.find_by_iso("US").id
StatesAndCountries.states.each do |s|
  State.create!(country_id: us_id, name: s[:name], abbreviation: s[:abbr])
end
