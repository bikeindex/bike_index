FactoryBot.define do
  factory :impound_record do
    bike { FactoryBot.create(:bike) }
    organization { FactoryBot.create(:organization, kind: "bike_depot") }
    user { FactoryBot.create(:organization_member, organization: organization) }
  end
end
