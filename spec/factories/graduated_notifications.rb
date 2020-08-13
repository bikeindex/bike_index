FactoryBot.define do
  factory :graduated_notification do
    transient do
      graduated_notification_interval { organization&.graduated_notification_interval.presence || 1.year.to_i }
      bike_created_at { Time.current - 1.day - graduated_notification_interval }
    end

    created_at { bike.created_at + graduated_notification_interval } # use the actual bike created_at, in case bike was passed in

    organization do
      FactoryBot.create(:organization_with_organization_features,
        enabled_feature_slugs: ["graduated_notifications"],
        graduated_notification_interval: 1.year)
    end

    bike do
      FactoryBot.create(:bike_organized,
        :with_ownership, # Or else we can't send email
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

    factory :graduated_notification_active do
      transient do
        bike_created_at { Time.current - 1.day - graduated_notification_interval }
      end
      after(:create) do |graduated_notification, _evaluator|
        graduated_notification.process_notification
      end
    end

    trait :marked_remaining do
      marked_remaining_at { created_at + GraduatedNotification::PENDING_PERIOD + 1.hour }
      after(:create) do |graduated_notification, evaluator|
        graduated_notification.marked_remaining_at = nil # need to blank this so mark_remaining functions
        graduated_notification.process_notification
        graduated_notification.mark_remaining!(resolved_at: evaluator.marked_remaining_at)
        graduated_notification.reload
      end
    end
  end
end
