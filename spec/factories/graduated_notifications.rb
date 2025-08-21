# == Schema Information
#
# Table name: graduated_notifications
#
#  id                          :bigint           not null, primary key
#  delivery_status             :string
#  email                       :string
#  marked_remaining_at         :datetime
#  marked_remaining_link_token :text
#  not_most_recent             :boolean          default(FALSE)
#  processed_at                :datetime
#  status                      :integer          default("pending")
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  bike_id                     :bigint
#  bike_organization_id        :bigint
#  marked_remaining_by_id      :bigint
#  organization_id             :bigint
#  primary_bike_id             :bigint
#  primary_notification_id     :bigint
#  user_id                     :bigint
#
# Indexes
#
#  index_graduated_notifications_on_bike_id                  (bike_id)
#  index_graduated_notifications_on_bike_organization_id     (bike_organization_id)
#  index_graduated_notifications_on_marked_remaining_by_id   (marked_remaining_by_id)
#  index_graduated_notifications_on_organization_id          (organization_id)
#  index_graduated_notifications_on_primary_bike_id          (primary_bike_id)
#  index_graduated_notifications_on_primary_notification_id  (primary_notification_id)
#  index_graduated_notifications_on_user_id                  (user_id)
#
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
        creation_organization: organization,
        created_at: bike_created_at)
    end

    trait :with_user do
      user { FactoryBot.create(:user) }
      bike do
        FactoryBot.create(:bike_organized,
          :with_ownership_claimed,
          creation_organization: organization,
          created_at: bike_created_at,
          user: user)
      end
    end

    factory :graduated_notification_bike_graduated do
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
        graduated_notification.mark_remaining!
        # Manually update
        graduated_notification.update_column :marked_remaining_at, evaluator.marked_remaining_at
        graduated_notification.reload
      end
    end
  end
end
