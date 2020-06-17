FactoryBot.define do
  factory :hot_sheet_configuration do
    organization { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    send_seconds_past_midnight { 21_600 }
    timezone_str { "America/Los_Angeles" }
    search_radius_miles { 50 }
  end
end
