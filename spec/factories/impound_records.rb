FactoryBot.define do
  factory :impound_record do
    bike { FactoryBot.create(:bike) }
    organization { FactoryBot.create(:organization_with_paid_features, paid_feature_slugs: "impound_bikes") }
    user { FactoryBot.create(:organization_member, organization: organization) }
  end
end
