FactoryBot.define do
  factory :bike_version do
    bike { FactoryBot.create(:bike, :with_ownership_claimed) }
    sequence(:name) { |n| "Version #{n}" }
    manufacturer { bike.manufacturer }
    primary_frame_color { bike.primary_frame_color }
    owner { bike.owner }
    cycle_type { bike.cycle_type }
    propulsion_type { bike.propulsion_type }
  end
end
