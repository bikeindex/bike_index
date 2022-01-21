FactoryBot.define do
  factory :organization_manufacturer do
    organization { FactoryBot.create(:organization) }
    manufacturer { FactoryBot.create(:manufacturer) }
  end
end
