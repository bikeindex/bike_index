FactoryBot.define do
  factory :notification do
    user { FactoryBot.create(:user) }
    kind { :confirmation_email }
  end
end
