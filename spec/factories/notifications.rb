FactoryBot.define do
  factory :notification do
    user { FactoryBot.create(:user) }
    kind { Notification.kinds.first }
  end
end
