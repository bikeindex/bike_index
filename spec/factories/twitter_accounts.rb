FactoryBot.define do
  factory :twitter_account do
    sequence(:screen_name) { "TestTwitterAccount" }
    consumer_key { "CONSUMER_KEY" }
    consumer_secret { "CONSUMER_SECRET" }
    user_token { "ACCESS_TOKEN" }
    user_secret { "ACCESS_SECRET" }
    twitter_account_info { { name: "name", profile_image_url_https: "https://example.com/image.jpg" } }

    address { "278 Broadway, New York, NY 10007, USA" }
    latitude { 40.7143528 }
    longitude { -74.0059731 }

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
      no_geocode { true }
      country { "Canada" }
      city { "Vancouver" }
      state { "BC" }
      latitude { 49.253992 }
      longitude { -123.241084 }
    end
  end
end
