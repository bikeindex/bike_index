FactoryBot.define do
  factory :hot_sheet do
    organization { FactoryBot.create(:organization) }
  end
end
