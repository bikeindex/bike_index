FactoryBot.define do
  factory :membership do
    role { "member" }
    organization { FactoryBot.create(:organization) }
    sender { FactoryBot.create(:user_confirmed) }
    sequence(:invited_email) { |n| user&.email || "someone-#{n}@test.com" }

    factory :membership_claimed do
      user { FactoryBot.create(:user_confirmed) }
      claimed_at { Time.now }

      factory :membership_ambassador do
        # before(:create) do
        #   Membership.skip_callback(:create, :after, :ensure_ambassador_tasks_assigned!)
        # end
        # after(:create) do
        #   Membership.set_callback(:create, :after, :ensure_ambassador_tasks_assigned!)
        # end
        organization { FactoryBot.create(:organization_ambassador) }
      end
    end
  end
end
