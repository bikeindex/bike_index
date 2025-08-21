FactoryBot.define do
  factory :bike_organization do
    bike { FactoryBot.create(:bike) }
    organization { FactoryBot.create(:organization) }
  end
end
