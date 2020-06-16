FactoryBot.define do
  factory :hot_sheet do
    organization { FactoryBot.create(:organization) }
    sheet_date { Time.current.to_date }
  end
end
