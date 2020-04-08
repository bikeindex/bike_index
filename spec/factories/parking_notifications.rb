FactoryBot.define do
  factory :parking_notification do
    bike { FactoryBot.create(:bike) }
    user { FactoryBot.create(:user) }

    latitude { 40.7143528 }
    longitude { -74.0059731 }

    trait :in_los_angeles do
      latitude { 34.05223 }
      longitude { -118.24368 }
      city { "Los Angeles" }
      state { State.find_or_create_by(FactoryBot.attributes_for(:state_california)) }
      country { Country.united_states }
    end

    factory :parking_notification_organized do
      user { FactoryBot.create(:organization_member, organization: organization) }
      organization { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: "impound_bikes") }

      factory :unregistered_parking_notification do
        transient do
          ownership { FactoryBot.create(:ownership, creator: user, bike: bike) }
        end
        bike { FactoryBot.create(:bike_organized, creator: user, organization: organization, status: "unregistered_parking_notification") }
        after(:create) do |parking_notification, evaluator|
          evaluator.ownership.save
          parking_notification.bike.update_attributes(marked_user_hidden: true)
        end
      end
    end
  end
end
