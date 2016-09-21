FactoryGirl.define do
  factory :bike do
    # Warning: the bikes controller forces every bike to have an ownership
    # But this factory allows creating bikes without ownerships.
    serial_number
    association :cycle_type
    association :manufacturer, factory: :manufacturer
    association :creator, factory: :user
    association :rear_wheel_size, factory: :wheel_size
    # association :handlebar_type
    association :propulsion_type
    association :primary_frame_color, factory: :color
    rear_tire_narrow true
    sequence(:owner_email) { |n| "bike_owner#{n}@example.com" }
    factory :organization_bike do
      association :creation_organization, factory: :organization
    end
    factory :stolen_bike do
      transient do
        latitude { 40.7143528 }
        longitude { -74.0059731 }
      end
      stolen true
      after(:create) do |bike, evaluator|
        create(:stolen_record,
               bike: bike,
               latitude: evaluator.latitude,
               longitude: evaluator.longitude)
        bike.save # updates current_stolen_record
        bike.reload
      end
      factory :recovered_bike do
        recovered true
      end
    end
  end
end
