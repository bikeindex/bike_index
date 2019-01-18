FactoryBot.define do
  factory :export do
    kind { "stolen" } # organizations is default kind, but requires organization so I'm not using it
    factory :export_organization do
      kind { "organization" }
      organization { FactoryBot.create(:organization) }
      factory :export_avery do
        avery_export { true }
      end
    end
  end
end
