FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "Country #{n}" }
    sequence(:iso) { |n| "country-#{n}" }

    factory :country_us do
      name { "United States" }
      iso { "US" }
    end

    factory :country_uk do
      name { "United Kingdom" }
      iso { "UK" }
    end

    factory :country_nl do
      name { "Netherlands" }
      iso { "NL" }
    end
  end
end
