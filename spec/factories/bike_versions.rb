FactoryBot.define do
  factory :bike_version do
    bike { FactoryBot.create(:bike, :with_ownership_claimed) }
    sequence(:name) { |n| "Version #{n}" }
    manufacturer { bike.manufacturer }
    primary_frame_color { bike.primary_frame_color }
    owner { bike.owner }
    cycle_type { bike.cycle_type }
    propulsion_type { bike.propulsion_type }

    trait :with_image do
      after(:create) do |bike_version|
        FactoryBot.create(:public_image, filename: "version-#{bike_version.id}.jpg", imageable: bike_version)
        bike_version.reload
        bike_version.save
      end
    end
  end
end
