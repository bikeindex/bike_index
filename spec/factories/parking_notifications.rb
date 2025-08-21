# == Schema Information
#
# Table name: parking_notifications
#
#  id                    :integer          not null, primary key
#  accuracy              :float
#  city                  :string
#  delivery_status       :string
#  hide_address          :boolean          default(FALSE)
#  image                 :text
#  image_processing      :boolean          default(FALSE), not null
#  internal_notes        :text
#  kind                  :integer          default("appears_abandoned_notification")
#  latitude              :float
#  location_from_address :boolean          default(FALSE)
#  longitude             :float
#  message               :text
#  neighborhood          :string
#  repeat_number         :integer
#  resolved_at           :datetime
#  retrieval_link_token  :text
#  retrieved_kind        :integer
#  status                :integer          default("current")
#  street                :string
#  unregistered_bike     :boolean          default(FALSE)
#  zipcode               :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  bike_id               :integer
#  country_id            :bigint
#  impound_record_id     :integer
#  initial_record_id     :integer
#  organization_id       :integer
#  retrieved_by_id       :bigint
#  state_id              :bigint
#  user_id               :integer
#
# Indexes
#
#  index_parking_notifications_on_bike_id            (bike_id)
#  index_parking_notifications_on_country_id         (country_id)
#  index_parking_notifications_on_impound_record_id  (impound_record_id)
#  index_parking_notifications_on_initial_record_id  (initial_record_id)
#  index_parking_notifications_on_organization_id    (organization_id)
#  index_parking_notifications_on_retrieved_by_id    (retrieved_by_id)
#  index_parking_notifications_on_state_id           (state_id)
#  index_parking_notifications_on_user_id            (user_id)
#
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
