# == Schema Information
#
# Table name: twitter_accounts
#
#  id                   :integer          not null, primary key
#  active               :boolean          default(FALSE), not null
#  address_string       :string
#  append_block         :string
#  city                 :string
#  consumer_key         :string           not null
#  consumer_secret      :string           not null
#  default              :boolean          default(FALSE), not null
#  language             :string
#  last_error           :string
#  last_error_at        :datetime
#  latitude             :float
#  longitude            :float
#  national             :boolean          default(FALSE), not null
#  neighborhood         :string
#  screen_name          :string           not null
#  street               :string
#  twitter_account_info :jsonb
#  user_secret          :string           not null
#  user_token           :string           not null
#  zipcode              :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  country_id           :bigint
#  state_id             :bigint
#
# Indexes
#
#  index_twitter_accounts_on_country_id              (country_id)
#  index_twitter_accounts_on_latitude_and_longitude  (latitude,longitude)
#  index_twitter_accounts_on_screen_name             (screen_name)
#  index_twitter_accounts_on_state_id                (state_id)
#
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
