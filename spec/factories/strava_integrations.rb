# frozen_string_literal: true

FactoryBot.define do
  factory :strava_integration do
    user { FactoryBot.create(:user_confirmed) }
    access_token { "strava_test_access_token_123" }
    refresh_token { "strava_test_refresh_token_456" }
    token_expires_at { Time.current + 6.hours }
    status { :pending }

    trait :with_athlete do
      athlete_id { "12345678" }
      athlete_activity_count { 150 }
    end

    trait :with_gear do
      with_athlete
      after(:create) do |strava_integration|
        FactoryBot.create(:strava_gear, strava_integration:,
          strava_gear_id: "b1234", strava_gear_name: "My Road Bike", gear_type: "bike",
          strava_data: {"id" => "b1234", "name" => "My Road Bike", "primary" => true, "distance" => 50000.0, "resource_state" => 2})
      end
    end

    trait :syncing do
      with_athlete
      status { :syncing }
      activities_downloaded_count { 50 }
    end

    trait :synced do
      with_athlete
      status { :synced }
      activities_downloaded_count { 150 }
    end

    trait :error do
      with_athlete
      status { :error }
    end
  end
end
