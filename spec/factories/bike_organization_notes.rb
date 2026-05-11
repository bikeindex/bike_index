FactoryBot.define do
  factory :bike_organization_note do
    bike { FactoryBot.create(:bike_organized) }
    organization { bike.organizations.first || FactoryBot.create(:organization) }
    user { FactoryBot.create(:user_confirmed) }
    body { "Test note" }
  end
end
