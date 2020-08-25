FactoryBot.define do
  factory :twitter_account do
    sequence(:screen_name) { |n| "TestTwitterAccount#{n}" }
    consumer_key { "CONSUMER_KEY" }
    consumer_secret { "CONSUMER_SECRET" }
    user_token { "ACCESS_TOKEN" }
    user_secret { "ACCESS_SECRET" }
    twitter_account_info { {} }
    skip_geocoding { true }

    factory :twitter_account_1 do
      screen_name { ENV.fetch("STOLEN_ALERT_TWITTER_1_USERNAME") }
      consumer_key { ENV.fetch("STOLEN_ALERT_TWITTER_1_CONSUMER_KEY") }
      consumer_secret { ENV.fetch("STOLEN_ALERT_TWITTER_1_CONSUMER_SECRET") }
      user_token { ENV.fetch("STOLEN_ALERT_TWITTER_1_ACCESS_TOKEN") }
      user_secret { ENV.fetch("STOLEN_ALERT_TWITTER_1_ACCESS_SECRET") }
      twitter_account_info { {name: "name", profile_image_url_https: "https://example.com/image.jpg"} }
    end

    factory :twitter_account_2 do
      screen_name { ENV.fetch("STOLEN_ALERT_TWITTER_2_USERNAME") }
      consumer_key { ENV.fetch("STOLEN_ALERT_TWITTER_2_CONSUMER_KEY") }
      consumer_secret { ENV.fetch("STOLEN_ALERT_TWITTER_2_CONSUMER_SECRET") }
      user_token { ENV.fetch("STOLEN_ALERT_TWITTER_2_ACCESS_TOKEN") }
      user_secret { ENV.fetch("STOLEN_ALERT_TWITTER_2_ACCESS_SECRET") }
      twitter_account_info { {name: "name", profile_image_url_https: "https://example.com/image.jpg"} }
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
  end
end
