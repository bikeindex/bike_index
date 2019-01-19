FactoryBot.define do
  factory :organization_invitation do
    inviter { FactoryBot.create(:user) }
    organization { FactoryBot.create(:organization) }
    invitee_email { "mike@test.com" }
  end
end
