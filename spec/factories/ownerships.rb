FactoryGirl.define do
  factory :ownership do
    bike { FactoryGirl.create(:bike, owner_email: owner_email) }
    creator { bike.creator }
    current true
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    factory :organization_ownership do
      bike { FactoryGirl.create(:creation_organization_bike) }
    end
  end
end
