FactoryBot.define do
  factory :country do
    name
    sequence(:iso) { |n| "D#{n}" }

    factory :country_us do
      name { "United States" }
      iso { "US" }
    end

    factory :country_uk do
      name { "United Kingdom" }
      iso { "UK" }
    end
  end
end
