FactoryBot.define do
  factory :content_tag do
    sequence(:name) { |n| "Cool tag #{n}" }
    priority { 1 }
  end
end
