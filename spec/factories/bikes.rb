# Warning: BikeCreator forces every bike to have an ownership
# ... But this factory allows creating bikes without ownerships
FactoryBot.define do
  factory :bike do
    # transient do # will be transient once we drop the deprecated creation attributes
    #  creator { FactoryBot.create(:user) }
    # end
    # creation_state { FactoryBot.create(:creation_state, creator: creator) }
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

    trait :stolen do
      transient do
        # default to NYC coordinates
        latitude { 40.7143528 }
        longitude { -74.0059731 }
      end
      stolen { true }
    end

    factory :stolen_bike, traits: [:stolen] do
      after(:create) do |bike, evaluator|
        create(:stolen_record, bike: bike, latitude: evaluator.latitude, longitude: evaluator.longitude)
        bike.reload
      end

      factory :abandoned_bike do
        abandoned { true }
      end

      factory :recovered_bike do
        stolen { false }
      end
    end

    # These factories are separate from the stolen bike factory because we only want to call after create once
    factory :stolen_bike_in_amsterdam, traits: [:stolen] do
      after(:create) do |bike|
        create(:stolen_record, :in_amsterdam, bike: bike)
        bike.reload
      end
    end
    factory :stolen_bike_in_los_angeles, traits: [:stolen] do
      after(:create) do |bike|
        create(:stolen_record, :in_los_angeles, bike: bike)
        bike.reload
      end
    end
    factory :stolen_bike_in_nyc, traits: [:stolen] do
      after(:create) do |bike|
        create(:stolen_record, :in_nyc, bike: bike)
        bike.reload
      end
    end
    factory :stolen_bike_in_chicago, traits: [:stolen] do
      after(:create) do |bike|
        create(:stolen_record, :in_chicago, bike: bike)
        bike.reload
      end
    end

    factory :organized_bikes do # don't use this factory exactly, it's used to wrap all the organized bikes
      transient do
        organization { FactoryBot.create(:organization) }
        can_edit_claimed { true }
      end
      creation_organization { organization }

      factory :bike_organized do
        after(:create) do |bike, evaluator|
          create(:bike_organization, organization: bike.creation_organization,
                                     bike: bike,
                                     can_edit_claimed: evaluator.can_edit_claimed)
          bike.reload
        end

        factory :bike_lightspeed_pos do
          after(:create) do |bike, _evaluator|
            create(:creation_state, creator: bike.creator,
                                    bike: bike,
                                    is_pos: true,
                                    pos_kind: "lightspeed_pos",
                                    organization: bike.creation_organization)
          end
        end

        factory :bike_ascend_pos do
          transient do
            bulk_import { FactoryBot.create(:bulk_import_ascend, organization: organization) }
          end
          after(:create) do |bike, evaluator|
            create(:creation_state, creator: bike.creator,
                                    bike: bike,
                                    is_pos: true,
                                    pos_kind: "ascend_pos",
                                    bulk_import: evaluator.bulk_import,
                                    organization: bike.creation_organization)
          end
        end
      end

      # Generally, you should use the organization_bike factory, not this one
      factory :creation_organization_bike do
        after(:create) do |bike, evaluator|
          create(:creation_state, creator: bike.creator,
                                  organization: bike.creation_organization,
                                  bike: bike,
                                  can_edit_claimed: evaluator.can_edit_claimed)
          bike.save
          bike.reload
        end
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
