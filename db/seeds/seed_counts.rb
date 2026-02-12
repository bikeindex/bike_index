# Seed Redis with dummy values retrieved by Counts module
if Rails.env.development?
  entries = {
    stolen_bikes: 66_406,
    total_bikes: 241_945,
    organizations: 724,
    recoveries: 5_734,
    recoveries_value: 8_188_294,
    week_creation_chart: {
      "2019-06-21": 261,
      "2019-06-22": 323,
      "2019-06-23": 313,
      "2019-06-24": 228,
      "2019-06-25": 226,
      "2019-06-26": 259,
      "2019-06-27": 127
    }.to_json
  }

  printf "Assigning Counts values... "
  entries.each_pair { |key, value| Counts.assign_for(key, value) }
  printf "done.\n\n"
  entries.keys.each { |key| puts "Counts.#{key}: #{Counts.public_send(key)}" }
end
