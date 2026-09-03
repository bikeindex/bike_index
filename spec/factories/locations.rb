FactoryBot.define do
  factory :location do
    sequence(:name) { |n| "Location #{n}" }
    organization { FactoryBot.create(:organization) }

    # Set latitude and longitude from address_record if it's present
    latitude { address_record&.latitude }
    longitude { address_record&.longitude }

    after(:create) do |location|
      # Save to simulate after_commit callback
      location.organization.save
    end

    trait :with_address_record do
      transient do
        address_in { :chicago }
      end

      address_record do
        FactoryBot.build(:address_record, address_in, kind: :organization, organization: instance.organization)
      end
    end

    trait :regional_organization do
      organization { FactoryBot.create(:organization_with_regional_bike_counts) }
    end
  end
end
