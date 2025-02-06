FactoryBot.define do
  factory :parking_notification do
    bike { FactoryBot.create(:bike) }
    user { FactoryBot.create(:user) }
    kind { "parked_incorrectly_notification" }

    latitude { 40.7143528 }
    longitude { -74.0059731 }

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
