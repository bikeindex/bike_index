# Seed Redis with dummy values retrieved by Counts module
if Rails.env.development?
  entries = {
    total_bikes: 1_704_247,
    stolen_bikes: 171_487,
    organizations: 1_829,
    recoveries: 17_387,
    recoveries_value: 33_127_631,
    week_creation_chart: {
      (Date.current - 5.days).to_s => 668,
      (Date.current - 4.days).to_s => 627,
      (Date.current - 3.days).to_s => 717,
      (Date.current - 2.days).to_s => 645,
      (Date.current - 1.day).to_s => 798,
      Date.current.to_s => 734
    }.to_json
  }

  printf "Assigning Counts values... "
  entries.each_pair { |key, value| Counts.assign_for(key, value) }
  printf "done.\n\n"
  entries.keys.each { |key| puts "Counts.#{key}: #{Counts.public_send(key)}" }
end
