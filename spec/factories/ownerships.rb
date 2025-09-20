# Recently added the :with_ownership trait to bikes
# Most places where this factory is used should instead use that instead
FactoryBot.define do
  factory :ownership do
    creator { FactoryBot.create(:user_confirmed) }
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    bike { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    current { true }
    created_at { bike&.created_at } # This makes testing certain time related things easier
    trait :claimed do
      claimed { true }
      user { creator } # Reduce the number of things added to the database
      owner_email { user.email }
      claimed_at { 1.hour.ago }
    end
    factory :ownership_claimed, traits: [:claimed]
  end
end
