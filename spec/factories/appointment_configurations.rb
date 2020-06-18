FactoryBot.define do
  factory :appointment_configuration do
    organization { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["virtual_line"]) }
    location { organization.locations.first }
    virtual_line_on { true }
    reasons { AppointmentConfiguration.default_reasons }
  end
end
