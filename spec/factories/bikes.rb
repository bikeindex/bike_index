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

    factory :stolen_bike do
      transient do
        latitude { 40.7143528 }
        longitude { -74.0059731 }
      end
      stolen { true }
      after(:create) do |bike, evaluator|
        create(:stolen_record,
               bike: bike,
               latitude: evaluator.latitude,
               longitude: evaluator.longitude)
        bike.save # updates current_stolen_record
        bike.reload
      end
      factory :recovered_bike do
        recovered { true }
      end
    end

    factory :organized_bikes do # don't use this factory exactly, it's used to wrap all the organized bikes
      transient do
        organization { FactoryBot.create(:organization) }
      end
      creation_organization { organization }

      factory :bike_organized do
        after(:create) do |bike, evaluator|
          create(:bike_organization, organization: bike.creation_organization, bike: bike)
          bike.reload
        end

        factory :bike_lightspeed_pos do
          after(:create) do |bike, _evaluator|
            create(:creation_state, creator: bike.creator, bike: bike, is_pos: true, pos_kind: "lightspeed_pos", organization: bike.creation_organization)
          end
        end

        factory :bike_ascend_pos do
          transient do
            bulk_import { FactoryBot.create(:bulk_import_ascend, organization: organization) }
          end
          after(:create) do |bike, evaluator|
            create(:creation_state, creator: bike.creator, bike: bike, is_pos: true, pos_kind: "ascend_pos", bulk_import: evaluator.bulk_import, organization: bike.creation_organization)
          end
        end
      end

      # Generally, you should use the organization_bike factory, not this one
      factory :creation_organization_bike do
        after(:create) do |bike, evaluator|
          create(:creation_state, creator: bike.creator, organization: bike.creation_organization, bike: bike)
          # create(:creation_state, creator: bike.creator, organization: evaluator.organization, bike: bike)
          bike.save
          bike.reload
        end
      end
    end
  end
end
