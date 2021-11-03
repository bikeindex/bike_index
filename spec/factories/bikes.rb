# Warning: BikeCreator forces every bike to have an ownership
# ... But this factory allows creating bikes without ownerships
# ** recently added the :with_ownership trait which should be used **
FactoryBot.define do
  factory :bike do
    creator { FactoryBot.create(:user) }
    serial_number
    manufacturer { FactoryBot.create(:manufacturer) }
    sequence(:owner_email) { |n| "bike_owner#{n}@example.com" }
    primary_frame_color { Color.black }
    cycle_type { CycleType.slugs.first }
    propulsion_type { "foot-pedal" }
    skip_geocoding { true }

    trait :with_image do
      after(:create) do |bike|
        FactoryBot.create(:public_image, filename: "bike-#{bike.id}.jpg", imageable: bike)
        bike.reload
        bike.save
      end
    end

    trait :with_creation_state do
      transient do
        can_edit_claimed { true }
        creation_state_is_pos { false }
        creation_state_pos_kind { "" }
        creation_state_bulk_import { nil }
        creation_state_registration_info { nil }
      end
      after(:create) do |bike, evaluator|
        create(:creation_state, creator: bike.creator,
                                bike: bike,
                                created_at: bike.created_at,
                                organization: bike.creation_organization,
                                can_edit_claimed: evaluator.can_edit_claimed,
                                is_pos: evaluator.creation_state_is_pos,
                                pos_kind: evaluator.creation_state_pos_kind,
                                bulk_import: evaluator.creation_state_bulk_import,
                                registration_info: evaluator.creation_state_registration_info)
        bike.reload # reflexively sets bike.current_creation_state
      end
    end

    trait :with_ownership do
      transient do
        user { nil }
        claimed { false }
      end
      after(:create) do |bike, evaluator|
        create(:ownership,
          bike: bike,
          creator: bike.creator,
          owner_email: bike.owner_email,
          user: evaluator.user,
          claimed: evaluator.claimed)
        bike.reload
      end
    end

    trait :with_ownership_claimed do
      transient do
        user { FactoryBot.create(:user) }
        claimed_at { Time.current - 1.day }
      end
      creator { user }
      owner_email { user.email }
      created_at { claimed_at }
      after(:create) do |bike, evaluator|
        create(:ownership_claimed,
          bike: bike,
          creator: bike.creator,
          owner_email: bike.owner_email,
          user: evaluator.user,
          claimed_at: evaluator.claimed_at)
        bike.reload
      end
    end

    trait :phone_registration do
      sequence(:owner_email) { |n| "888#{n}".rjust(10, "3").to_s }
      is_phone { true }
    end

    trait :impounded do
      after(:create) do |bike, _evaluator|
        FactoryBot.create(:impound_record, bike: bike)
      end
    end

    factory :impounded_bike, traits: [:impounded]

    # THIS FACTORY SHOULD NEVER BE USED, except in other factories - there needs to be a stolen record created in addition to this.
    # use with_stolen_record instead
    trait :stolen_trait do
      transient do
        # default to NYC coordinates
        latitude { 40.7143528 }
        longitude { -74.0059731 }
      end
    end

    trait :with_stolen_record do
      stolen_trait
      after(:create) do |bike, evaluator|
        create(:stolen_record, bike: bike, latitude: evaluator.latitude, longitude: evaluator.longitude)
        bike.reload
      end
    end

    factory :stolen_bike, traits: [:with_stolen_record]

    factory :recovered_bike do
      stolen_trait
      after(:create) do |bike, evaluator|
        create(:stolen_record_recovered, bike: bike, latitude: evaluator.latitude, longitude: evaluator.longitude)
        bike.reload
      end
    end

    # These factories are separate from the stolen bike factory because we only want to call after create once
    factory :stolen_bike_in_amsterdam, traits: [:stolen_trait] do
      after(:create) do |bike|
        create(:stolen_record, :in_amsterdam, bike: bike)
        bike.reload
      end
    end
    factory :stolen_bike_in_los_angeles, traits: [:stolen_trait] do
      after(:create) do |bike|
        create(:stolen_record, :in_los_angeles, bike: bike)
        bike.reload
      end
    end
    factory :stolen_bike_in_nyc, traits: [:stolen_trait] do
      after(:create) do |bike|
        create(:stolen_record, :in_nyc, bike: bike)
        bike.reload
      end
    end
    factory :stolen_bike_in_chicago, traits: [:stolen_trait] do
      after(:create) do |bike|
        create(:stolen_record, :in_chicago, bike: bike)
        bike.reload
      end
    end

    factory :bike_organized, traits: [:with_creation_state] do
      transient do
        # TODO: remove this (we should only reference creation_organization) - requires updating a bunch of specs
        organization { FactoryBot.create(:organization) }
      end

      creation_organization { organization }

      factory :bike_lightspeed_pos, traits: [:with_creation_state] do
        creation_state_is_pos { true }
        creation_state_pos_kind { "lightspeed_pos" }
      end

      factory :bike_ascend_pos , traits: [:with_creation_state] do
        transient do
          bulk_import { FactoryBot.create(:bulk_import_ascend, organization: creation_organization) }
        end
        creation_state_is_pos { true }
        creation_state_pos_kind { "ascend_pos" }
        creation_state_bulk_import { bulk_import }
      end
    end

    trait :blue_trek_930 do
      frame_model { "930" }
      manufacturer { FactoryBot.create(:manufacturer, name: "Trek") }
      primary_frame_color { FactoryBot.create(:color, name: "Blue") }
    end

    trait :green_novara_torero do
      frame_model { "Torero 29\"" }
      manufacturer { FactoryBot.create(:manufacturer, name: "Novara") }
      primary_frame_color { FactoryBot.create(:color, name: "Green") }
    end
  end
end
