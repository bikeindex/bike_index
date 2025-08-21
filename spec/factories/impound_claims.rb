# == Schema Information
#
# Table name: impound_claims
#
#  id                 :bigint           not null, primary key
#  message            :text
#  resolved_at        :datetime
#  response_message   :text
#  status             :integer
#  submitted_at       :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  bike_claimed_id    :bigint
#  bike_submitting_id :bigint
#  impound_record_id  :bigint
#  organization_id    :bigint
#  stolen_record_id   :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_impound_claims_on_bike_claimed_id     (bike_claimed_id)
#  index_impound_claims_on_bike_submitting_id  (bike_submitting_id)
#  index_impound_claims_on_impound_record_id   (impound_record_id)
#  index_impound_claims_on_organization_id     (organization_id)
#  index_impound_claims_on_stolen_record_id    (stolen_record_id)
#  index_impound_claims_on_user_id             (user_id)
#
FactoryBot.define do
  factory :impound_claim do
    transient do
      organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
    end
    impound_record { FactoryBot.create(:impound_record_with_organization, organization: organization) }
    user { FactoryBot.create(:user) }
    status { "pending" }

    trait :with_stolen_record do
      transient do
        bike { FactoryBot.create(:bike, :with_ownership_claimed, creator: user, user: user) }
      end
      stolen_record { FactoryBot.create(:stolen_record, bike: bike) }
    end

    factory :impound_claim_with_stolen_record, traits: [:with_stolen_record]

    trait :resolved do
      impound_record { FactoryBot.create(:impound_record_resolved, :with_organization, organization: organization, status: "retrieved_by_owner") }
      status { "retrieved" }
    end

    factory :impound_claim_resolved, traits: [:resolved]
  end
end
