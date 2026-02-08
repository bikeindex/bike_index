FactoryBot.define do
  factory :strava_gear_association do
    strava_integration
    association :item, factory: :bike
    strava_gear_id { "b12345" }
    strava_gear_name { "My Road Bike" }
  end
end
