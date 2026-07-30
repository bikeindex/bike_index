FactoryBot.define do
  factory :sso_identity do
    user { FactoryBot.create(:user_confirmed) }
    organization { FactoryBot.create(:organization) }
    provider { "saml" }
    sequence(:uid) { |n| "idp-name-id-#{n}" }
    email { user.email }
  end
end
