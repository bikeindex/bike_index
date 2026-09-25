# frozen_string_literal: true

FactoryBot.define do
  factory :shopify_integration do
    organization { FactoryBot.create(:organization, :with_auto_user) }
    user { FactoryBot.create(:user_confirmed) }
    sequence(:shop_domain) { |n| "bike-shop-#{n}.myshopify.com" }
    access_token { "shpua_test_access_token_123" }
    status { :pending }

    trait :active do
      status { :active }
      webhooks_registered_at { Time.current }
    end
  end
end
