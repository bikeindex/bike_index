FactoryBot.define do
  factory :ownership do
    bike { FactoryBot.create(:bike, owner_email: owner_email) }
    creator { FactoryBot.create(:user_confirmed) }
    current { true }
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    factory :ownership_claimed do
      claimed { true }
      user { FactoryBot.create(:user, email: owner_email) }
    end
    factory :organization_ownership do
      bike { FactoryBot.create(:creation_organization_bike) }
    end
  end
end
