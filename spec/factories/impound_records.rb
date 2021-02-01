FactoryBot.define do
  factory :impound_record do
    bike { FactoryBot.create(:bike) }
    user { FactoryBot.create(:user) }

    trait :with_organization do
      organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
      user { FactoryBot.create(:organization_member, organization: organization) }
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
