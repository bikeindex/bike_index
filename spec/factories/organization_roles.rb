FactoryBot.define do
  factory :organization_role do
    role { "member" }
    organization { FactoryBot.create(:organization) }
    sender { FactoryBot.create(:user_confirmed) }
    sequence(:invited_email) { |n| user&.email || "someone-#{n}@test.com" }

    factory :organization_role_claimed do
      user { FactoryBot.create(:user_confirmed) }
      email_invitation_sent_at { Time.current }
      claimed_at { Time.current }

      factory :organization_role_ambassador do
        organization { FactoryBot.create(:organization_ambassador) }
      end
    end
  end
end
