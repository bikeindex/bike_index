FactoryBot.define do
  factory :bike_organization_note do
    bike_organization { FactoryBot.create(:bike_organization) }
    user { FactoryBot.create(:user_confirmed) }
    body { "Test note" }
  end
end
