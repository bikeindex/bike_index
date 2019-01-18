FactoryGirl.define do
  factory :ownership do
    creator { FactoryGirl.create(:user_confirmed) }
    bike { FactoryGirl.create(:bike, owner_email: owner_email) }
    current true
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    factory :organization_ownership do
      bike { FactoryGirl.create(:creation_organization_bike) }
    end
  end
end
