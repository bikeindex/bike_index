FactoryBot.define do
  factory :graduated_notification do
    transient do
      # Mainly so we don't have to repeat it multiple times ;)
      bike_created_at { Time.current - 1.day - (organization&.graduated_notification_interval || 2.days)  }
    end

    organization do
      FactoryBot.create(:organization_with_paid_features,
                        enabled_feature_slugs: ["graduated_notifications"],
                        graduated_notification_interval: 2.days.to_i)
    end
    bike do
      FactoryBot.create(:bike_organized,
                        organization: organization,
                        created_at: bike_created_at)
    end

    trait :with_user do
      user { FactoryBot.create(:user) }
      bike do
        FactoryBot.create(:bike_organized,
                          :with_ownership_claimed,
                          organization: organization,
                          created_at: bike_created_at,
                          user: user)
      end
    end

    factory :graduated_notification_with_secondary, traits: [:with_user] do
      after(:create) do |graduated_notification, evaluator|
        FactoryBot.create(:graduated_notification,
                          primary_notification: graduated_notification,
                          organization: evaluator.organization,
                          bike: evaluator.bike,
                          user: evaluator.user)
      end
    end
  end
end
