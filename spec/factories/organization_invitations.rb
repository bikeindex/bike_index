FactoryGirl.define do
  factory :organization_invitation do
    inviter { FactoryGirl.create(:user) }
    organization { FactoryGirl.create(:organization) }
    invitee_email { "mike@test.com" }
  end
end
