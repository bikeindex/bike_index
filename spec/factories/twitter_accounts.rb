FactoryBot.define do
  factory :twitter_account do
    sequence(:screen_name) { |n| "TestTwitterAccount#{n}" }
    consumer_key { "CONSUMER_KEY" }
    consumer_secret { "CONSUMER_SECRET" }
    user_token { "ACCESS_TOKEN" }
    user_secret { "ACCESS_SECRET" }
    twitter_account_info { {} }
    city { "New York" }
    address { "278 Broadway, New York, NY 10007, USA" }
    latitude { 40.7143528 }
    longitude { -74.0059731 }

    after(:build) do |twitter_account, _evaluator|
      new_york = State.find_by(abbreviation: "NY") || FactoryBot.build(:state_new_york)
      twitter_account.state = new_york
      twitter_account.country = new_york.country
    end

    factory :twitter_account_1 do
      screen_name { ENV.fetch("STOLEN_ALERT_TWITTER_1_USERNAME") }
      consumer_key { ENV.fetch("STOLEN_ALERT_TWITTER_1_CONSUMER_KEY") }
      consumer_secret { ENV.fetch("STOLEN_ALERT_TWITTER_1_CONSUMER_SECRET") }
      user_token { ENV.fetch("STOLEN_ALERT_TWITTER_1_ACCESS_TOKEN") }
      user_secret { ENV.fetch("STOLEN_ALERT_TWITTER_1_ACCESS_SECRET") }
      twitter_account_info { { name: "name", profile_image_url_https: "https://example.com/image.jpg" } }
    end

    factory :twitter_account_2 do
      screen_name { ENV.fetch("STOLEN_ALERT_TWITTER_2_USERNAME") }
      consumer_key { ENV.fetch("STOLEN_ALERT_TWITTER_2_CONSUMER_KEY") }
      consumer_secret { ENV.fetch("STOLEN_ALERT_TWITTER_2_CONSUMER_SECRET") }
      user_token { ENV.fetch("STOLEN_ALERT_TWITTER_2_ACCESS_TOKEN") }
      user_secret { ENV.fetch("STOLEN_ALERT_TWITTER_2_ACCESS_SECRET") }
      twitter_account_info { { name: "name", profile_image_url_https: "https://example.com/image.jpg" } }
    end

    trait :active do
      active { true }
    end

    trait :national do
      national { true }
    end

    trait :default do
      default { true }
    end

    trait :canadian do
      skip_geocoding { true }
      city { "Vancouver" }
      latitude { 49.253992 }
      longitude { -123.241084 }

      after(:build) do |twitter_account, _evaluator|
        twitter_account.country =
          Country.find_by(iso: "CA") || FactoryBot.build(:country_canada)
      end
    end
  end
end
