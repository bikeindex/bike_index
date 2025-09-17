# Warning: BikeServices::Creator forces every bike to have an ownership
# ... But this factory allows creating bikes without ownerships
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

    trait :with_primary_activity do
      primary_activity { FactoryBot.create(:primary_activity) }
    end

    trait :with_image do
      after(:create) do |bike|
        FactoryBot.create(:public_image, filename: "bike-#{bike.id}.jpg", imageable: bike)
        bike.reload
        bike.save
      end
    end

    trait :with_address_record do
      transient { address_record_kind { :bike } }

      address_record { FactoryBot.build(:address_record, kind: address_record_kind) }

      after(:create) do |bike, _evaluator|
        bike.address_record.update(bike_id: bike.id)
      end
    end

    trait :with_ownership do
      transient do
        user { nil }
        claimed { false }
        claimed_at { nil }
        can_edit_claimed { true }
        creation_pos_kind { "" }
        marked_user_hidden { false }
        # Previous Creation State attributes
        # TODO: part of #2110 - remove prefix
        creation_state_origin { "" }
        creation_state_bulk_import { nil }
        creation_registration_info { nil }
      end
      user_hidden { marked_user_hidden }

      after(:create) do |bike, evaluator|
        # Sometimes multiple things include with_ownership, this can get called multiple times
        # Make sure we only do it once
        if bike.ownerships.count == 0
          if bike.creation_organization_id.present?
            BikeOrganization.create(bike_id: bike.id,
              organization_id: bike.creation_organization_id,
              can_edit_claimed: evaluator.can_edit_claimed,
              created_at: bike.created_at)
          end

          FactoryBot.create(:ownership,
            user_hidden: bike.user_hidden,
            bike: bike,
            creator: bike.creator,
            owner_email: bike.owner_email,
            user: evaluator.user,
            claimed: evaluator.claimed,
            claimed_at: evaluator.claimed_at,
            created_at: bike.created_at,
            organization_id: bike.creation_organization_id,
            can_edit_claimed: evaluator.can_edit_claimed,
            origin: evaluator.creation_state_origin,
            pos_kind: evaluator.creation_pos_kind,
            bulk_import: evaluator.creation_state_bulk_import,
            registration_info: evaluator.creation_registration_info)

          bike.reload
        end
      end
    end

    trait :with_ownership_claimed do
      with_ownership
      transient do
        user { FactoryBot.create(:user) }
        claimed_at { Time.current - 1.day }
        claimed { true }
      end
      creator { user }
      owner_email { user.email }
      created_at { claimed_at }
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
        stolen_no_notify { false }
        # default to NYC coordinates
        latitude { 40.7143528 }
        longitude { -74.0059731 }
        date_stolen { Time.current }
      end
    end

    trait :with_stolen_record do
      stolen_trait
      after(:create) do |bike, evaluator|
        create(:stolen_record,
          bike: bike,
          latitude: evaluator.latitude,
          longitude: evaluator.longitude,
          receive_notifications: !evaluator.stolen_no_notify,
          date_stolen: evaluator.date_stolen)
        bike.reload
      end
    end

    factory :stolen_bike, traits: [:with_stolen_record]

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

    factory :bike_organized, traits: [:with_ownership] do
      creation_organization { FactoryBot.create(:organization) }

      factory :bike_lightspeed_pos do
        creation_state_origin { "api_v1" }
        creation_pos_kind { "lightspeed_pos" }
      end

      factory :bike_ascend_pos do
        transient do
          bulk_import { FactoryBot.create(:bulk_import_ascend, organization: creation_organization) }
        end
        creation_state_origin { "bulk_import_worker" }
        creation_pos_kind { "ascend_pos" }
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
