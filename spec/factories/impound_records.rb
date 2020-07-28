FactoryBot.define do
  factory :impound_record do
    bike { FactoryBot.create(:bike) }
    organization { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: "impound_bikes") }
    user { FactoryBot.create(:organization_member, organization: organization) }
    factory :impound_record_resolved do
      status { "retrieved_by_owner" }
      after(:create) do |impound_record, evaluator|
        FactoryBot.create(:impound_record_update,
          impound_record: impound_record,
          kind: evaluator.status)
      end
    end
  end
end
