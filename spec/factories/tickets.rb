FactoryBot.define do
  factory :ticket do
    location { FactoryBot.create(:location, :with_virtual_line_on) }
    sequence(:number) { |n| n }
  end
end
