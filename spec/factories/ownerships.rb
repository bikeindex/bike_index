FactoryGirl.define do
  factory :ownership do
    bike { FactoryGirl.create(:bike, owner_email: owner_email) }
    creator { FactoryGirl.create(:user_confirmed) }
    current true
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    factory :ownership_claimed do
      claimed { true }
      user { FactoryGirl.create(:user, email: owner_email) }
    end
    factory :organization_ownership do
      bike { FactoryGirl.create(:creation_organization_bike) }
    end
  end
end
