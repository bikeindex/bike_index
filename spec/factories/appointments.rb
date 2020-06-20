FactoryBot.define do
  factory :appointment do
    organization { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["virtual_line"]) }
    location { organization.locations.first }
    sequence(:email) { |n| "bike_owner#{n}@example.com" }
    reason { AppointmentConfiguration.default_reasons.first }
  end
end
