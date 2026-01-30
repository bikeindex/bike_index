FactoryBot.define do
  factory :location do
    sequence(:name) { |n| "Location #{n}" }
    organization { FactoryBot.create(:organization) }
    address_record { FactoryBot.create(:address_record, :chicago) }

    after(:create) do |location|
      # Save to simulate after_commit callback
      location.organization.save
    end

    trait :regional_organization do
      organization { FactoryBot.create(:organization_with_regional_bike_counts) }
    end

    factory :location_chicago do
      address_record { FactoryBot.create(:address_record, :chicago) }
    end

    factory :location_nyc do
      address_record { FactoryBot.create(:address_record, :new_york) }
    end

    factory :location_los_angeles do
      address_record { FactoryBot.create(:address_record, :los_angeles) }
    end

    factory :location_edmonton do
      address_record { FactoryBot.create(:address_record, :edmonton) }
    end
  end
end
