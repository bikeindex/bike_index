# == Schema Information
#
# Table name: impound_records
#
#  id                    :integer          not null, primary key
#  city                  :text
#  display_id_integer    :bigint
#  display_id_prefix     :string
#  impounded_at          :datetime
#  impounded_description :text
#  latitude              :float
#  longitude             :float
#  neighborhood          :text
#  resolved_at           :datetime
#  status                :integer          default("current")
#  street                :text
#  unregistered_bike     :boolean          default(FALSE)
#  zipcode               :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  bike_id               :integer
#  country_id            :bigint
#  display_id            :string
#  location_id           :bigint
#  organization_id       :integer
#  state_id              :bigint
#  user_id               :integer
#
# Indexes
#
#  index_impound_records_on_bike_id          (bike_id)
#  index_impound_records_on_country_id       (country_id)
#  index_impound_records_on_location_id      (location_id)
#  index_impound_records_on_organization_id  (organization_id)
#  index_impound_records_on_state_id         (state_id)
#  index_impound_records_on_user_id          (user_id)
#
FactoryBot.define do
  factory :impound_record do
    bike { FactoryBot.create(:bike, created_at: created_at) }
    user { FactoryBot.create(:user) }

    trait :with_organization do
      organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
      user { FactoryBot.create(:organization_user, organization: organization) }
    end

    factory :impound_record_with_organization, traits: [:with_organization]

    # Bump the bike to make impound_record the current_impound_record, if it should be
    after(:create) do |impound_record, _evaluator|
      impound_record.bike&.update(updated_at: Time.current)
    end

    factory :impound_record_resolved do
      status { "retrieved_by_owner" }
      after(:create) do |impound_record, evaluator|
        FactoryBot.create(:impound_record_update,
          impound_record: impound_record,
          kind: evaluator.status)

        impound_record.bike&.update(updated_at: Time.current)
      end
    end
  end
end
