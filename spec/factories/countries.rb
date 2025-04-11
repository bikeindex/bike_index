FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "Country #{n}" }
    sequence(:iso) { |n| "country-#{n}" }

    trait :find_or_create do
      initialize_with do
        Country.find_by(iso:) || Country.new(attributes)
      end
    end

    factory :country_us, traits: [:find_or_create] do
      name { "United States" }
      iso { "US" }
    end

    factory :country_canada, traits: [:find_or_create] do
      name { "Canada" }
      iso { "CA" }
    end

    factory :country_australia, traits: [:find_or_create] do
      name { "Australia" }
      iso { "AU" }
    end

    factory :country_uk, traits: [:find_or_create] do
      name { "United Kingdom" }
      iso { "UK" }
    end

    factory :country_nl, traits: [:find_or_create] do
      name { "Netherlands" }
      iso { "NL" }
    end
  end
end
