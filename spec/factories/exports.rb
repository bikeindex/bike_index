FactoryGirl.define do
  factory :export do
    kind { "stolen" } # organizations is default kind, but requires organization so I'm not using it
    factory :export_organization do
      kind { "organization" }
      organization { FactoryGirl.create(:organization) }
    end
  end
end
