# frozen_string_literal: true

FactoryBot.define do
  factory :strava_request do
    transient do
      strava_integration { FactoryBot.create(:strava_integration) }
    end
    user_id { strava_integration.user_id }
    strava_integration_id { strava_integration.id }
    request_type { :fetch_athlete }
    parameters { {} }

    trait :fetch_athlete_stats do
      request_type { :fetch_athlete_stats }
    end

    trait :list_activities do
      request_type { :list_activities }
      parameters { {page: 1} }
    end

    trait :fetch_activity do
      request_type { :fetch_activity }
      parameters { {strava_id: "12345"} }
    end

    trait :fetch_gear do
      request_type { :fetch_gear }
      parameters { {strava_gear_id: "b12345"} }
    end

    trait :proxy do
      request_type { :proxy }
      parameters { {url: "/athlete"} }
    end

    trait :processed do
      requested_at { Time.current }
      response_status { :success }
    end
  end
end
