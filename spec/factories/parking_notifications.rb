FactoryBot.define do
  factory :parking_notification do
    bike { FactoryBot.create(:bike) }
    user { FactoryBot.create(:user) }
    kind { "parked_incorrectly_notification" }

    latitude { 40.7143528 }
    longitude { -74.0059731 }

    # Location traits using address_record-style columns (region_record_id/postal_code)
    # instead of the shared traits in 0_factory_traits.rb which use state_id/zipcode
    trait :in_los_angeles do
      latitude { 34.05223 }
      longitude { -118.24368 }
      street { "100 W 1st St" }
      city { "Los Angeles" }
      region_record_id { FactoryBot.create(:state_california).id }
      postal_code { "90021" }
      country_id { Country.united_states.id }
    end

    trait :in_chicago do
      latitude { 41.8624488 }
      longitude { -87.6591502 }
      city { "Chicago" }
      region_record_id { FactoryBot.create(:state_illinois).id }
      country_id { Country.united_states.id }
      street { "1300 W 14th Pl" }
      postal_code { "60608" }
    end

    trait :in_edmonton do
      latitude { 53.5069377 }
      longitude { -113.5508765 }
      street { "9330 Groat Rd NW" }
      postal_code { "AB T6G 2B3" }
      city { "Edmonton" }
      region_record_id { nil }
      country_id { Country.canada.id }
    end

    trait :retrieved do
      retrieved_kind { "organization_recovery" }
      retrieved_by_id { user.id }
      resolved_at { Time.current }

      after(:create) do |parking_notification, evaluator|
        parking_notification.mark_retrieved!(retrieved_by_id: evaluator.retrieved_by_id,
          retrieved_kind: evaluator.retrieved_kind,
          resolved_at: evaluator.resolved_at)
      end
    end

    factory :parking_notification_organized do
      organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
      user { FactoryBot.create(:organization_user, organization: organization) }

      factory :parking_notification_unregistered do
        bike do
          FactoryBot.create(:bike_organized,
            creator: user,
            owner_email: user.email,
            can_edit_claimed: true,
            creation_organization: organization,
            status: "unregistered_parking_notification")
        end
        after(:create) do |parking_notification, _evaluator|
          # I'm not in love with this, but...  we need to mark this hidden
          parking_notification.bike.update(marked_user_hidden: true)
        end
      end
    end
  end
end
