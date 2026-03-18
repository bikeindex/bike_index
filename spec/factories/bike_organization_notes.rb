FactoryBot.define do
  factory :bike_organization_note do
    transient do
      bike { FactoryBot.create(:bike_organized) }
    end
    bike_organization { bike.bike_organizations.first || FactoryBot.create(:bike_organization, bike:) }
    user { FactoryBot.create(:user_confirmed) }
    body { "Test note" }
  end
end
