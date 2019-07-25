FactoryBot.define do
  factory :ownership do
    creator { FactoryBot.create(:user_confirmed) }
    bike { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    current { true }
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    factory :ownership_claimed do
      claimed { true }
      user { FactoryBot.create(:user, email: owner_email) }
    end
    factory :ownership_organization_bike do
      transient do
        organization { FactoryBot.create(:organization) }
        can_edit_claimed { true }
      end
      bike { FactoryBot.create(:creation_organization_bike, organization: organization, can_edit_claimed: can_edit_claimed) }
    end
    factory :ownership_stolen do
      bike { FactoryBot.create(:stolen_bike, owner_email: owner_email, creator: creator) }
    end
  end
end
