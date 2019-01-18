FactoryBot.define do
  factory :location do
    name
    organization { FactoryBot.create(:organization) }
    country { FactoryBot.create(:country) }
    state { FactoryBot.create(:state) }
    zipcode { "60647" }
    city { "Chicago" }
    street { "foo address" }
    latitude { 41.9282162 }
    longitude { -87.6327552 }
  end
end
