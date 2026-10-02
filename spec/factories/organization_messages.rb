FactoryBot.define do
  factory :organization_message do
    organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications]) }
    sender { FactoryBot.create(:organization_user, organization:) }
    bike { FactoryBot.create(:bike_organized, creation_organization: organization) }
    message { "Your lock is on the rack" }
  end
end
