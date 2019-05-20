FactoryBot.define do
  factory :membership do
    role { "member" }
    organization { FactoryBot.create(:organization) }
    factory :existing_membership do
      user { FactoryBot.create(:user) }
    end

    factory :membership_ambassador do
      before(:create) do
        Membership.skip_callback(:create, :before, :assign_ambassador_tasks!)
      end
      role { "member" }
      organization { FactoryBot.create(:organization_ambassador) }
      user { FactoryBot.create(:user_confirmed) }
    end
  end
end
