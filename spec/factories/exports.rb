FactoryGirl.define do
  factory :export do
    kind { "stolen" } # organizations is default kind, but requires organization so I'm not using it
    factory :export_organization do
      kind { "organization" }
      organization { FactoryGirl.create(:organization) }
      factory :export_avery do
        headers { %w[owner_name_or_email registration_address] }
        options { { avery_export: true } }
      end
    end
  end
end
